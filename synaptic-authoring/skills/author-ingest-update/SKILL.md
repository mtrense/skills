---
name: author-ingest-update
description: Delta-aware re-ingest of repo-local source material into the reference/ layer, driven by a git commit range so it knows exactly what changed. The update counterpart to author-ingest — instead of re-distilling from scratch, it diffs the ingested source over a commit range (or since the last recorded watermark), reconciles only the changed units against the existing reference/ files by grounding ref, and reports which downstream track nodes are grounded on changed/broken refs and therefore need re-drafting. Trigger when the user says "update the ingest", "re-ingest", "the KB changed", "refresh reference material", "the source moved on", or "/author-ingest-update". Reads the repo only, never the web. Delegates the read-heavy work to subagents: material-extractor (re-extract changed source) and grounding-tracer (scan the track for affected nodes).
argument-hint: "[commit-range | PR#]"
model: opus
allowed-tools: Read, Write, Edit, Glob, Grep, Agent, Bash(git rev-parse:*), Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(git ls-files:*), Bash(gh pr view:*), Bash(gh pr diff:*)
---

# author-ingest-update — changed source → refreshed reference/ + delta report

You refresh the author-only **`reference/` layer** when the source material it was distilled from
has moved on — a research KB gained sources or current developments, or a `document`-kind file was
edited. `author-ingest` produces the baseline from scratch; you keep it current **incrementally**,
using a git commit range as the ground truth for *what actually changed* rather than re-distilling
everything and hoping to dedup.

You also close the pipeline's silent-drift gap: because grounding refs (`research:<path>#<anchor>`)
are only existence-checked by the CLI — never checked for *agreement* — a node whose source content
changed under a stable anchor goes stale with nothing to flag it. This skill is that flag: it maps
changed refs back to the track nodes grounded on them (via the `grounding-tracer` scout) and emits a
re-draft worklist.

Keep your own context lean: the two read-heavy operations — re-extracting changed source and scanning
the track for affected nodes — are delegated to subagents (`material-extractor`, `grounding-tracer`),
so you hold only the manifest, the reconciliation buckets, and the worklist.

## Scope — repo-local only, never the web
Same boundary as `author-ingest`: you read files already in the repo. Any web work happened upstream
when the source was produced (e.g. by `/research-investigation` or `/research-ingest-source`). If the
user wants a *fresh* online source folded in, that belongs upstream in the KB first, then here.

## The ingest-state manifest — your provenance and watermark
`author-ingest` records `reference/.ingest-state.yaml`:
```yaml
schema: 1
source_root: research/content        # where the ingested source material lives
grounding_kind: research | document | mixed
ingested_through: <sha>              # last source commit reflected in reference/
ingested_at: <date>
provenance:
  - source: research/content/errors/handling.md   # upstream source file
    reference: reference/handling.md               # the distilled reference file
    refs: ["research:handling.md#error-handling", "research:handling.md#retries"]
```
This is your join between the commit diff (which touches `source_root`) and the `reference/` layer
(whose refs downstream nodes carry). Read it first.

## Arguments — `$ARGUMENTS`
- **Empty** — default: diff `source_root` from `ingested_through` to `HEAD`. The common mode.
- **Commit range** (`abc123..HEAD`, `main..kb-refresh`, `HEAD~8..HEAD`) — use this range instead of
  the watermark. Useful for reviewing one logical KB change.
- **PR number** (`123` / `#123`) — `gh pr view <N> --json baseRefOid,headRefOid` → treat base..head
  as the range.

## Step 1 — Load state and resolve scope
1. Read `reference/.ingest-state.yaml`.
   - **Missing** (the baseline predates this skill): enter *seed mode*. Ask the user for the
     `source_root`, then reconstruct best-effort provenance by matching each `reference/*.md` to a
     same-named / same-heading source file under `source_root`, confirm the mapping with the user,
     and write the manifest with `ingested_through` set to the range's base (or `HEAD` if the user
     wants to treat everything as already-ingested). Then continue.
2. Compute the changed source set: `git diff --name-status <range> -- <source_root>`
   (range = watermark..HEAD, the argument range, or the PR's base..head).
   For every **Modified** file also read its per-file diff (`git diff <range> -- <file>`) so you can
   attribute changes to specific **headings/anchors**, not just whole files — grounding refs are
   anchor-addressed and anchor-level granularity is what makes the downstream mapping precise.

## Step 2 — Halt cases
Stop and ask before doing work if:
- **No git / unknown SHAs** — surface it; ask for an explicit range or how to proceed.
- **Empty diff** — no source file under `source_root` changed in the range. Report and exit cleanly,
  **no writes** (this is the idempotent no-op that proves the watermark works).
- **`source_root` moved or deleted** — the whole ingested tree relocated; that's a structural change
  needing human judgement (update the manifest's `source_root`?). Surface, don't guess.
- **Schema mismatch** — `schema:` in the manifest isn't `1`. Don't patch across schema versions.

## Step 3 — Re-extract only the changed source
Spawn `material-extractor` (via `Agent`) on the **Added + Modified** source files only — never the
whole tree. It returns fresh atomic units with `grounding_ref`, `confidence`, `why_it_matters`, and
`source_ref`, **plus the write-ready `reference/` body per changed file**, exactly as in a first
ingest, and reports the grounding kind. Use those returned bodies for the added/changed edits in
Step 4 — do **not** re-open the source yourself to re-distil (same lean-context rule as
`author-ingest`; that re-read is what blows the budget). Deleted/renamed files need no extraction —
you handle those from the diff in Step 4.

## Step 4 — Reconcile against the existing reference/ layer
Join the freshly-extracted units to the current `reference/` content **by grounding ref** (the
stable key). Classify each into exactly one bucket:

| Bucket | Signal | reference/ action |
|---|---|---|
| **added** | ref not in prior provenance (new heading/anchor or new source file) | append the distilled unit to the right `reference/` file (create the file for a new source) |
| **changed** | ref present, but the source content under that anchor changed | update the unit in place — re-distil to note form, **never copy prose verbatim** |
| **anchor-moved** | a heading was renamed → ref *string* changed | record the `old-ref → new-ref` mapping; update the reference/ heading; the old ref is now **broken** downstream |
| **removed** | source heading or file deleted | tombstone the unit (leave a `<!-- REMOVED: <ref> (source deleted @ <sha>) -->` marker, don't silently drop it) |
| **unchanged** | ref present, content byte-identical | leave alone |

For **`document`-kind** refs (`doc:<path>@sha256:<hex>`): any byte change to the source file changes
its hash, so the existing `doc:` ref is **broken** until re-pinned. Re-emit as
`doc:<path>@sha256:<PLACEHOLDER>` (you never compute hashes — `author-selfcheck` catches mismatch)
and treat every node carrying the old hash as broken.

## Step 5 — Map to downstream track nodes — delegate to `grounding-tracer` (close the silent-drift gap)
Spawn the `grounding-tracer` subagent (via `Agent`) — do **not** grep the track yourself; the raw
sweep stays in the scout's context, and you get back only the worklist. Pass it:
- `track_root` — the track directory (the id'd node files; not `reference/`).
- `changed_refs` — every ref in the **changed / anchor-moved / removed** buckets from Step 4, each
  tagged with its `bucket`, its `new_ref` (for `anchor-moved`), and a `note` (e.g. document-hash
  break, source deleted).

It returns, per affected node, a `status`:
- **STALE** — carries a `changed` ref (still resolves, but the substance beneath it moved). Needs a
  fresh `/author-snippet` pass; grounded questions may need review via `/author-questions`.
- **BROKEN** — carries an `anchor-moved`, `removed`, or `document`-hash ref (no longer resolves).
  Needs a ref fix (re-ground to `new_ref`) or a human decision to retire the node.

plus the node's `dependents` (a prerequisite re-draft often ripples) and any `unaffected_refs`
(changed refs no node carries — safe). Nodes touching only **added** units aren't stale — but the new
units are candidates for **new nodes** via `/author-structure`.

## Step 6 — Confirm the plan before writing
Present a compact plan and get the user's go-ahead (same discipline as `/research-ingest-source` and
`/research-restructure`). Two tables:

**reference/ edits**

| Ref | Bucket | reference/ file | Edit |
|---|---|---|---|
| `research:handling.md#retries` | changed | `reference/handling.md` | re-distil unit |
| `research:handling.md#backoff` | added | `reference/handling.md` | append unit |

**downstream worklist**

| Node | Ref | Status | Next |
|---|---|---|---|
| `err-retry-basics` | `research:handling.md#retries` | STALE | `/author-snippet` |
| `err-backoff` | `research:handling.md#backoff-strategy` | BROKEN (anchor moved) | re-ground → `/author-snippet` |

Call out new-node candidates and any tombstoned/removed source. Let the user drop or narrow items.
Do not write until confirmed.

## Step 7 — Apply and re-watermark
1. Apply the confirmed `reference/` edits (add / update / tombstone). Preserve heading structure so
   `research:` refs keep resolving; leave `document`-kind source files byte-for-byte.
2. Update `reference/.ingest-state.yaml`: bump `ingested_through` to the range's end SHA
   (`git rev-parse <range-end>`), set `ingested_at` to today, and update `provenance` (new files,
   new/removed refs, anchor renames).
3. **Do not edit any id'd node file** — re-drafting nodes is `/author-snippet`'s job, ref fixes are a
   deliberate re-grounding, and new nodes are `/author-structure`'s. You touch only `reference/` and
   the state manifest. This keeps the update auditable and the DAG under human control.

## Step 8 — Hand off
Report:
- The range used and its end SHA (the new watermark).
- `reference/` changes by bucket (added / changed / anchor-moved / removed / tombstoned).
- The **downstream worklist**: STALE nodes → `/author-snippet`; BROKEN nodes → re-ground then
  `/author-snippet`; new-node candidates → `/author-structure`.
- A reminder to run `/author-selfcheck` (`synaptic validate`) after the re-draft to confirm every
  ref resolves again.

Do **not** commit. The user reviews and runs `/commit`.

## Behavioural guarantees
- **Idempotent** — an empty diff writes nothing; re-running the same range is a no-op after the first.
- **Diff drives scope, not opinion** — a unit is re-distilled only because its source anchor has
  commits in the range, never because it "feels stale."
- **No hidden writes** — the plan in Step 6 enumerates every reference/ edit; nodes are never touched.
- **Never fakes provenance** — refs and confidence are lifted from what `material-extractor` found;
  a `document`-kind change honestly breaks its hash ref rather than papering over it.

## Rules
- Repo-local only; never fetch the web (that's upstream, or `/research-ingest-source` in the KB).
- Never copy source prose verbatim — re-distil to DAG-ready note form, same register rule as ingest.
- Never compute hashes; emit `doc:...@sha256:<PLACEHOLDER>`.
- Touch only `reference/` and `reference/.ingest-state.yaml`. Node re-drafting, re-grounding, and new
  nodes are downstream skills the worklist points at — surface them, don't perform them.
- Always confirm the plan (Step 6) before writing.
