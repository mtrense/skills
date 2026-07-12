---
name: author-snippet-cycle
description: Draft the bodies of every un-drafted scaffolded node in a track by fanning snippet-drafter subagents across nodes in parallel batches, then centrally scaffolding the slugs they need and writing each node. The batch counterpart to author-snippet — the same drafter contract, run many-at-once. Trigger after author-structure has scaffolded a batch of nodes, or when the user says "draft all the nodes", "flesh out the track", "snippet everything", "draft the remaining nodes", or "/author-snippet-cycle". Resumable and idempotent — each pass only picks up nodes still carrying scaffold TODO bodies.
argument-hint: "[max-nodes][@workers]   (e.g. `10`, `10@6`, `@6`; defaults: no cap, 4 workers)"
model: opus
allowed-tools: Read, Write, Edit, Glob, Grep, Agent, Bash(synaptic scaffold:*), Bash(synaptic validate:*), Bash(git status:*)
---

# author-snippet-cycle — parallel node drafting

You drive a track's **un-drafted scaffolded nodes** to drafted bodies by invoking the
`snippet-drafter` subagent once per node, in parallel batches across distinct node files. Each
drafter does the read-heavy corpus/slug sweep and the generative draft inside its own context and
returns a proposal; **you** scaffold the slugs and write the files. Because slug scaffolding is
centralized here — never inside the parallel drafters — two nodes that need the same glossary term
can't race to create it.

The motivation is the same as `author-snippet`, at scale: **context hygiene** (the sweeps and draft
transcripts live in the forks) and **wall-clock speed** (independent nodes draft concurrently). The
orchestrator stays small — it holds the proposals, a slug set, and the write loop.

## Prerequisites
1. A track directory containing `track.toml` (ask if ambiguous). Bind it as `<track-dir>`.
2. At least one scaffolded node still carrying a `TODO:` body/grounding placeholder. If none, stop
   and tell the human everything is already drafted.
3. Clean working tree — the `git status --porcelain` at load time is injected below; if non-empty,
   stop and ask the human to commit or stash first. Do not re-run it for the initial check.

   ```
   !`git status --porcelain`
   ```

## Arguments — `$ARGUMENTS`
Shape `[<total>][@<workers>]`, same grammar as the research cycles:
- *empty* → no cap, 4 workers.
- `N` → cap at N nodes, 4 workers.
- `N@W` → cap at N nodes, W workers.
- `@W` → no cap, W workers.

Anything else (non-integer, zero/negative, extra tokens) → halt and state the expected shape. Bind
`<total>` and `<workers>`.

## Loop
Repeat until a stop condition triggers.

### Step 1 — Enumerate un-drafted nodes
`Grep` the track's id'd node files (not `reference/`) for the scaffold placeholder — a node still
carrying `TODO:` in its `grounding`/`title`/`body` is un-drafted. Produce a list of `node_path`s. If
empty, exit the loop (success → Step 6).

### Step 2 — Build the next batch
A batch is a set of **distinct** `node_path`s (a drafter is read-only, so distinctness is only about
keeping the later write loop clean and progress legible). Take the first `<workers>` un-drafted nodes
(default 4). If `<total>` is set and you're near it, shrink the batch so you don't overshoot.

### Step 3 — Spawn the batch in parallel
Issue one `Agent` call per node **in a single message** so the drafters run concurrently:
`Agent(subagent_type="snippet-drafter", …)` with `node_path`, the `reference/` root (+ units
manifest if present), and `track_root`. Wait for all to return.

### Step 4 — Vet each proposal
For each returned proposal, in order (halt the loop on any hard failure):
1. **Grounding present.** `refs` is non-empty and no ref is one the drafter flagged unresolvable in
   `notes`. A missing-grounding flag → skip that node (leave it un-drafted) and record it for the
   summary; don't fake a ref.
2. **Motivation present.** The `body` states *why it matters* / *what it unlocks*. If not, skip the
   node and note it.
3. **Voice.** Playful, low-stakes, active-application; no gating/ranking language (especially for
   `kind: exercise`). Send weak drafts back or skip.

### Step 5 — Scaffold slugs once, then write
Do this **centrally and sequentially** (this is why the cycle, not a per-node skill, owns the write):
1. **Union the `scaffold`-state slugs** across every vetted proposal in the batch and **dedup by
   slug**. Scaffold each unique slug exactly once:
   ```bash
   synaptic scaffold glossary  <track-dir> <slug>
   synaptic scaffold cheatsheet <track-dir> <slug>
   ```
   (Leaving each new slug's body a `TODO` is fine — it's a separate `author-adjacent` job; note them
   for the summary.)
2. **Write each vetted node**: fill `title`, `grounding`, the `glossary:`/`cheatsheet:` frontmatter
   lists + inline slug links, and the `body`. Leave the scaffold's initial `major` changelog entry
   untouched. Never mint or edit the node `id`.
3. **Pre-flight the tree isn't corrupted** — every path you wrote must be a batch node file or a
   freshly-scaffolded slug file. Anything else → halt and report.

If `<total>` is set and you've reached it, exit after this batch. Otherwise log a one-line note per
node (e.g. `✓ err-retry-basics — drafted, 2 slugs`) and loop to Step 1.

### Step 6 — Validate and summarize
1. Run `synaptic validate <track-dir> --json` (or invoke `author-selfcheck`). Report validity in the
   CLI's own terms; if nodes still fail (e.g. a `doc:@sha256:<PLACEHOLDER>` awaiting a real hash, or
   a slug whose body is still `TODO`), name them and say which downstream step closes each — don't
   hand off an integrity-breaking tree as ready.
2. Print a compact summary: nodes drafted this cycle (count + examples), nodes **skipped** and why
   (missing grounding / weak motivation — these need a human or a re-run), new slugs scaffolded
   (with `TODO` bodies pending `author-adjacent`), nodes still un-drafted (count), and any halt
   reason.
3. Suggest next steps: `author-questions` / `author-questions-cycle` for the freshly-drafted nodes,
   `author-adjacent` for the pending slug bodies, `author-gap-scan` before hand-off.

Remind the human to review the diff and run `/commit`. Never commit or push.

## Important principles
- **Slugs scaffolded once, centrally.** The parallel drafters are read-only and only *propose*
  slugs; the orchestrator dedups and scaffolds. This is the whole reason drafting fans out safely.
- **Context hygiene is half the point.** Don't read `reference/` corpus or draft prose yourself —
  the drafters do that in discarded contexts. You hold proposals, a slug set, and the write loop.
- **Skip, don't fake.** A node the drafter couldn't ground is left un-drafted and surfaced — never
  written with an invented ref. It shows up again next run once its `reference/` material exists.
- **Idempotent.** Re-running re-derives the un-drafted set from `TODO` placeholders, so a completed
  node is never re-drafted and a partial run resumes cleanly.
- **No commits.** Drafters don't write; you write only nodes + slugs; the human reviews and commits.
