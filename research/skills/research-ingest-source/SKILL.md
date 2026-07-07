---
name: research-ingest-source
description: "Ingest a specific external source (URL or local file) an author already has — vet it for legitimacy the same way investigation does, then weave it into every existing section it substantiates or contradicts across the topic tree. Arguments: source URL or path, optional topic hint."
argument-hint: "<url-or-path> [\"topic-hint\"]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Edit, Agent, WebSearch, WebFetch, Bash(grep *), Bash(curl *)
---

# Research Ingest Source

You are integrating a **specific source the author already has** — a blog post,
a paper, a spec, a release note — into an existing research knowledge base. This
is the source-first counterpart to `/research-investigation`: investigation
starts from a RESEARCH directive and *discovers* sources; you start from one
source and find where it *belongs*.

Two jobs, in order:

1. **Vet** the source for legitimacy using the same levers investigation uses —
   URL verification, primary-vs-secondary, independence, per-claim confidence.
2. **Weave** it into every existing section it corroborates, extends, or
   contradicts — across the whole topic tree, not one file — reusing the
   project's reference, confidence, contradiction, and decision conventions.

**Arguments**: `$ARGUMENTS`
- First argument: the source — an `http(s)` URL, or a path to a local file
  (a downloaded paper, a saved article).
- Second argument (optional, quoted): a topic hint — a topic path or subject
  phrase to focus placement. Omit to search the whole tree.

## Prerequisites

1. Read `research/INDEX.md`. Identify topics at status `draft`, `audited`, or
   `done` — only these have written content to weave into. If none exist,
   abort: "No investigated content yet — run `/research-investigation` before
   ingesting sources."
2. Read `research/CLAUDE.md` for tone, scope, and citation conventions.
3. Read `research/DECISIONS.md` for prior decisions (including any earlier
   source-selection decisions).

## Step 1 — Acquire and characterise the source

- If the argument is a URL: `WebFetch` it. If it is a local path: `Read` it.
- Extract and record:
  - `title`, `authors`, publisher / venue, publication `date`.
  - `source-class`: `academic` | `industry` | `primary`.
  - A **numbered claim list** — the source's discrete substantive claims. For
    each, capture a one-line paraphrase plus one or two verbatim supporting
    sentences you will use as the evidence anchor.
- Mint a provisional citation key in the project's style
  (`author-year` / `slug-year` / `rfc-nnnn`).
- If the source fetches but is thin (marketing, opinion with no verifiable
  claim), say so and confirm with the user before proceeding.
- If the source cannot be retrieved at all (404, hard paywall, unreadable
  file), **halt** — there is nothing to vet. (A source that loads but is
  paywalled past the abstract can still be ingested; everything resting on it
  becomes `verified: false` + `CONFIDENCE: low`.)

## Step 2 — Vet legitimacy

Apply the same assessment investigation applies to a discovered source:

- **URL verification (binary).** `verified: true` only if the page fetched
  cleanly **and** its content matches the claims you intend to attribute.
  Paywall / login wall / 404 / content mismatch → `verified: false` (with a
  `note:` explaining why).
- **Primary vs secondary.** Is this source the *origin* of its load-bearing
  claim, or is it reporting someone else's result? If secondary, chase the
  primary with `WebSearch` + `WebFetch` and prefer to cite the primary — or
  cite both, with the secondary as the accessible pointer.
- **Independence check.** For any load-bearing or novel claim resting on this
  single source, run 1–2 `WebSearch` + `WebFetch` to find corroborating (or
  dissenting) sources. Keep the fetch budget to ~6.
- **Per-claim confidence**, exactly as investigation Step 5:
  - `well-sourced` — multiple independent verified sources agree.
  - `medium` — single strong source, or non-independent sources.
  - `low` — single weak / paywalled / unverifiable source, or inferred across
    pages.
- **Contradictions.** Note where the source disagrees with well-established
  fact (this feeds the contradiction handling in Step 5). Do not resolve them
  here.

> Optional delegation: for a claim that needs broad corroboration, you may
> spawn the `source-investigator` subagent with a query derived from the
> claim — it returns vetted corroborating/dissenting citations without you
> spending your own context on the search loop. Default to inline vetting for
> a single source; reach for the subagent only when one claim needs a real
> search arc.

If the source survives vetting with **no** citable, verifiable claim, stop and
report that — do not force a placement.

## Step 3 — Locate where it belongs (delegate to `corpus-locator`)

Spawn the `corpus-locator` subagent via the `Agent` tool. Pass it:
- The source descriptor (title, authors, date, source-class, provisional key).
- The **claim list** with paraphrases and verbatim anchors.
- The absolute path to `research/content/`.
- The slice of `research/INDEX.md` naming the eligible (`draft`/`audited`/
  `done`) topics and their status.
- The topic hint, if one was given.

It returns, per claim, the sections that `corroborate`, `extend`, or
`contradict` it, plus `uncovered` claims with their nearest section. You never
read the whole tree yourself — the scout does, and returns only locations.

If `corpus-locator` reports every claim as `uncovered` with `(no near
section)`, the source is off-topic for this knowledge base. Report that to the
user and stop — do not manufacture a home for it.

## Step 4 — Confirm the placement plan

Before editing anything, present a compact plan and get the user's go-ahead
(same discipline as `/research-restructure`). For each claim, show:

| Claim | Target section | Relationship | Intended edit |
|-------|----------------|--------------|---------------|
| … | `file.md#heading` | corroborates | add `[key]` citation + CONFIDENCE if not well-sourced |
| … | `file.md#heading` | contradicts | both positions + DEC-NNN + AUDIT contradiction |
| … | (nearest: `file.md#heading`) | uncovered | gap AUDIT (or suggest `/research-add-chapter`) |

Call out explicitly: which topic files will be touched, which will gain a
CONFIDENCE marker, which a contradiction (and therefore a DECISIONS entry), and
which claims have no home. Let the user drop, narrow, or redirect items. Do not
proceed to Step 5 until the plan is confirmed.

## Step 5 — Apply the edits

Group the work **by topic file** so each `<topic>_references.yaml` is touched
once. Mint the source's citation key once and reuse it everywhere; if the same
source is already cited under an existing key, reuse that key and do not create
a duplicate references entry.

For each confirmed placement:

**References (every placement)** — mirror investigation Step 8:
- Add/update the entry in `<topic-name>_references.yaml`:
  ```yaml
  citation-key:
    title: "..."
    authors: ...
    url: https://...        # or isbn: for a book
    published: YYYY-MM-DD
    last-checked: <today>
    verified: true | false
  ```
- Add the in-text `[citation-key]` where the claim is stated, and the
  `### References` list line for that section.

**`corroborates` / `extends`** — weave the claim into the existing section:
- For `corroborates`, attach the citation to the sentence already making the
  point (and tighten the prose only as needed).
- For `extends`, add a sentence or short passage carrying the new substance,
  in the project's tone, citing `[key]`.
- Attach a `<!-- CONFIDENCE: medium | low -->` marker immediately after the
  claim if its confidence (Step 2) is not `well-sourced`. `well-sourced` needs
  no marker.

**`contradicts`** — apply the three-part contradiction policy (as investigation
Step 7):
1. Present **both** positions in the section text — do not silently overwrite
   what was there.
2. Append a `DEC-NNN` entry to `research/DECISIONS.md` (re-read the file
   immediately before appending to pick the next free number), and add its
   summary-table row.
3. Insert an AUDIT comment at the contradiction:
   ```html
   <!-- AUDIT:
     type: contradiction
     severity: major
     detail: "New source <key> disagrees with the section on X — see DEC-NNN"
     ref: "DECISIONS.md#dec-nnn"
   -->
   ```

**`uncovered`** — do **not** fabricate a new section (that guard matches
`/research-refine`). Instead insert a gap AUDIT at the nearest section so the
coverage audit / refine phase can pick it up:
```html
<!-- AUDIT:
  type: gap
  severity: minor
  detail: "Source <key> covers <subject>, not yet in this knowledge base"
  ref: ""
-->
```
If the material clearly deserves its own home, say so in the summary and suggest
`/research-add-chapter` — do not create the chapter yourself.

## Step 6 — Decision log and status

1. **Log the ingestion** as one source-selection decision in
   `research/DECISIONS.md` (separate from any per-contradiction `DEC` from
   Step 5):
   ```
   ### DEC-NNN: Admit source <citation-key>
   **Date**: <today>
   **Topic**: <topics touched>
   **Context**: <what the source is; how it was vetted — verified?, source-class>
   **Decision**: Admitted; woven into <sections>.
   **Rationale**: <what it corroborates / extends / contradicts, and its confidence>
   **Alternatives considered**: <e.g. "cite the secondary blog vs. the primary paper it reports">
   ```
   Add its summary-table row.
2. **Status** (in `research/INDEX.md`), per touched topic:
   - A topic that gained an **AUDIT** comment (contradiction or gap): if it was
     `done`, set it back to `audited` (there are now unresolved audits for
     refine); an `audited` topic stays `audited`.
   - A topic that gained a **CONFIDENCE** marker but no AUDIT: a `done` topic
     drops to `audited` (a `done` section may hold no unverified claim); an
     `audited` topic stays `audited`.
   - A topic that gained only a **well-sourced, verified** citation (no marker,
     no AUDIT): leave its status unchanged.
3. Update the `updated` date in each modified topic file's frontmatter.

## Step 7 — Summarise

Report to the user:
- The source, its `verified` status, source-class, and overall confidence.
- Per touched file: what was added (citations, extended prose, contradictions,
  gaps) and any status change.
- Any claims left `uncovered` and your suggestion for them.
- The `DEC-NNN` IDs written.

## Git

Do NOT commit. The user reviews and runs `/commit` when ready.
Expected commit message format: `research(ingest): <citation-key>`.

## Halt conditions

HALT INSTEAD OF PUSHING THROUGH if:
- The source cannot be retrieved at all (nothing to vet).
- No topic in the project has reached `draft` (nothing to weave into).
- The source survives vetting with no citable, verifiable claim.
- `corpus-locator` returns every claim as `uncovered` with no near section (the
  source is off-topic).
- Anything else that would normally need a human judgement call — surface it in
  Step 4 rather than guessing.

## Rules

- **One source per invocation** — but it MAY touch multiple topic files. This
  deliberately differs from `/research-refine`'s one-file rule; cross-tree
  placement is the point of this skill.
- Do NOT fabricate URLs, authors, dates, or quotes. Every woven claim must
  trace to the actual source or a corroborating source you fetched.
- Do NOT add new `##` sections. Route genuinely new subtopics to a gap AUDIT or
  `/research-add-chapter`.
- Prefer primary sources: if the handed source is secondary, chase and cite the
  primary too.
- Preserve all existing references, CONFIDENCE markers, and AUDIT comments —
  only add, and only edit prose where a placement requires it.
- Always confirm the placement plan (Step 4) before editing.
- Do NOT advance any topic's status forward; this skill can only hold or step a
  status back (`done → audited`) when it introduces an AUDIT or CONFIDENCE
  marker.
