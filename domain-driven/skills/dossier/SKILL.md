---
name: dossier
description: >
  Build or extend a dossier — the project's fact file on one subject: everything discoverable that is relevant to the job to be done, distilled into confidence-tagged, source-cited claims under dossiers/. The fact twin of an ADR (an ADR records a decision, an exemplar shows it in bytes, a dossier records what the world actually is). Trigger whenever facts must be researched or distilled for the build at hand — e.g. "research what <regulation> requires of us", "figure out what this API actually does from these captures", "distill what the research KB says about X for this backlog", "build/update the dossier on X", or /dossier. Entry vectors: an explicit subject or question, a source to mine (a HAR capture, a vendor PDF, a research KB), a factual hotspot handed off by /domain-model or /architecture-foundation, or a knowledge gap flagged by /whats-next. Re-invoking on an existing subject runs an accretion pass — new claims merged in, confirmations lifted, contradictions kept both-ways, never silently overwritten. Scoped strictly by a human-confirmed relevance frame drawn from the vision, context map, and backlog: the middle ground between answering inline and the full research workflow. Do NOT trigger for building a standalone knowledge base (that is the research workflow), for a report not tied to this project's backlog (deep-research), or for questions the session can answer without consulting sources.
argument-hint: "[subject, question, or source path — e.g. 'hungarian e-invoicing' or 'captures/session.har']"
model: opus
allowed-tools: Read, Write, Edit, Glob, Agent, Skill, Bash(bash */skills/task-status/tasks.sh *), Bash(mkdir -p dossiers*), Bash(date *)
---

# Dossier — The Project's Fact File on One Subject

You build or extend one **dossier**: a subject-keyed file of verified facts the project needs — what a regulation demands, what an undocumented API actually does, how a market's rules differ — distilled from whatever sources hold them. It completes a triad: an **ADR** records a *decision*, an **exemplar** shows it in *bytes*, a dossier records a *fact* — what is true about the world, independent of what the project chooses to do about it.

Two rules keep it from inflating into a knowledge base:

- **Demand-driven, never speculative.** A dossier exists because the vision or backlog raises a subject, and its **relevance frame** (Step 1) is the filter: a claim gets in because something in the frame would consume it — not because it is true and nearby. Corpus-scale fact gathering belongs to the research workflow; a dossier *distills* from such a KB when one exists, it never replaces one.
- **Facts only — this skill writes no ADRs.** When the sweep trips over a choice the project must make, that is routed out (Step 4), never absorbed. Keeping fact and decision in separate artifacts is what keeps both logs clean.

Write no code and no tasks. One invocation works on one dossier (creating it, or accreting onto it).

## The dossier convention

```
dossiers/
  dossiers.md            # index: one line per dossier (slug, subject, contexts, swept date, open unknowns)
  <slug>.md              # the dossier — subject-keyed, accreting across invocations
```

Dossier frontmatter (the metadata of record; the index line mirrors it):

```markdown
---
slug: hungarian-e-invoicing
contexts: [invoicing]         # bounded-context slugs, [] if project-wide
frame: >
  One tight paragraph: the job to be done — the vision outcomes, aggregates,
  and backlog territory this dossier serves. The relevance yardstick.
sources:
  - ref: research/content/eu-vat/invoicing.md   # repo path, file, or URL
    kind: kb                                    # kb | repo | web
    swept: 2026-07-18                           # watermark (date; add the git sha for kb/repo when available)
---

## Findings
## Contradictions
## Coverage
## Open unknowns
### Factual
### Decisional
```

- **Findings** — the claims, grouped by concern. Every claim ends with a source-and-confidence tag: `[research/content/eu-vat/invoicing.md §Real-time reporting → high]`, `[captures/session.har: POST /invoices → medium]`. Confidence is `high` (primary source verified, directly observed, or lifted from a KB claim already marked high), `medium` (secondary or single-source), or `low` (inferred, unverified, or extrapolated — e.g. generalizing from one observed API response). A claim distilled from a research KB **never carries higher confidence than the KB gives it**.
- **Contradictions** — where sources disagree, both positions with their sources. A dossier never silently resolves a contradiction; it reports the disagreement and lets confidence and provenance speak.
- **Coverage** — what was swept and, just as important, what the frame deliberately excludes. This is what makes "everything relevant" an honest claim instead of an unbounded one.
- **Open unknowns** — the honest edge. **Factual** unknowns (the sweep surfaced the question but no source settled it) are the worklist for the next accretion pass. **Decisional** unknowns (the facts force a choice) are routed out per Step 4 and noted here with where they went.

There is **no status enum** — confidence lives per claim, and a dossier is never "done", only current-as-of-its-watermarks. Consumers: `/task-refine` (via `task-analyzer`) attaches bearing dossiers to a task's `related_documents` so the implementer inherits the facts; `/whats-next` flags dossiers with open factual unknowns or aging watermarks, and subjects the backlog needs that no dossier covers.

## Step 0 — Establish the subject and the entry vector

What is this dossier about, and what brought us here?

- **`$ARGUMENTS` is a subject or question:** that names the dossier (a question is an entry vector, not the unit — the dossier that answers it is keyed by subject and will usually answer more).
- **`$ARGUMENTS` is a source path** (a capture, a PDF, a directory): infer the subject from the source and confirm it in one line.
- **Invoked from a session** (a factual hotspot from `/domain-model` or `/architecture-foundation`, a knowledge gap from `/whats-next`): the handed-off item is the subject — name it back with its origin so the scope is shared.
- **None of these is clear:** ask one question — *facts about what, for which work?* — before reading anything.

Then read `dossiers/dossiers.md` if it exists. If a dossier already covers this subject (or a broader one containing it), this run is an **accretion pass** on that file — say so and work on it; do not open a near-duplicate subject.

## Step 1 — Build the relevance frame (and confirm it)

Before any source is touched, establish *the job to be done* — the yardstick that decides what is relevant out of everything discoverable:

1. Read `vision.md`, `context-map.md`, and the `bounded-contexts/<context>.md` files the subject plausibly touches; check `domain-model.md`'s hotspots for entries this dossier would inform.
2. Read the backlog **through the helper only**: `bash <skills-root>/task-status/tasks.sh list` (or `by-context <slug>` when the subject clearly homes in one context) — frontmatter titles and contexts are enough to see which live tasks this subject serves. Never open task bodies.
3. Draft the **frame**: one tight paragraph naming the vision outcomes, contexts/aggregates, and task territory the dossier serves — plus, explicitly, what nearby territory it does *not* cover.
4. Draft the **source list**: the sources to sweep, each tagged `kb` (a research-workflow KB — detect `research/INDEX.md`, or the user points at a corpus), `repo` (local files: captures, specs, PDFs, vendor docs), or `web`. Web sweeps are **opt-in per run**: they enter the sweep only when this confirmed list includes them.
5. **Confirm frame and source list with the human** before spawning anything. On an accretion pass, the existing frame is the baseline — ask whether it widens (a frame widened is the honest version of "the backlog grew into new territory").

## Step 2 — Sweep the sources (subagent)

Spawn the **dossier-scout** subagent (`subagent_type: dossier-scout`) with: the subject, the confirmed frame, the confirmed source list (each entry with its kind), the project root, and — on an accretion pass — the existing dossier's path. It sweeps every listed source under the frame's filter and returns confidence-tagged, source-cited findings grouped by concern, contradictions, a coverage statement, open unknowns split factual/decisional, and (on accretion) a per-finding tag of `new` / `confirms` / `contradicts` against the existing claims. Its reading — the KB walk, the capture parsing, any web fetching — stays in the subagent; you receive only the distillate.

For a large sweep (several independent source groups), you may fan out one scout per source group in parallel and merge their reports — the frame is the same for all; dedup by claim before presenting.

## Step 3 — Review and merge (the accretion discipline)

Present the distillate to the human **compactly, grouped by concern** — findings with their confidence, contradictions called out, coverage and unknowns last. The human is the frame's enforcer: strike findings that are true-but-not-consumed (and tighten the frame text if the scout over-collected), and challenge low-confidence claims that acceptance criteria would end up leaning on.

On an accretion pass, merge — never overwrite:

- **`new`** claims are added under their concern.
- **`confirms`** — an existing claim re-attested by an independent source gets the new source appended and its confidence lifted (at most to the new evidence's level).
- **`contradicts`** — the most important case: the existing claim does **not** get replaced. Both positions move to (or stay in) `## Contradictions` with their sources, and you say so out loud — a task may already have been built on the old claim, and a silent flip is the one failure mode an accreting fact file must never have.

## Step 4 — Route what isn't a fact

For each **decisional** unknown the sweep surfaced (the facts are clear but force a project choice — e.g. "the regulation permits monthly or per-invoice reporting; which do we implement?"):

- If the human can and wants to settle it now, **offer** `Skill(adr)` — the decision gets its durable home in the decision log, and the dossier's unknown entry is annotated with the ADR number. Never auto-record.
- Otherwise, note it under `### Decisional` with its routing: a hotspot for the next `/domain-model` revision, or an agenda item for `/architecture-foundation`. The dossier states the facts either way; it never encodes the choice.

## Step 5 — Write it

1. `mkdir -p dossiers` and write (or edit, on accretion) `dossiers/<slug>.md` per the convention above — frontmatter with the confirmed frame and per-source watermarks (`swept:` today's date; add the source's git sha for `kb`/`repo` refs when cheaply available), then the four body sections.
2. Add or update the index line in `dossiers/dossiers.md`, creating the file with a `# Dossiers` heading if missing:

   ```
   - `hungarian-e-invoicing` — what NAV real-time invoice reporting requires — contexts: invoicing — swept: 2026-07-18 — open unknowns: 2
   ```

   The index line carries the swept date and the count of open **factual** unknowns — that is all `/whats-next` reads to flag a dossier as due for accretion.

## When you are done

Report in a few sentences: the dossier written or extended (slug, path), the claim count by confidence, contradictions on record, and the open unknowns — factual ones as the next accretion pass's worklist, decisional ones with where each was routed. Point at the consumers: `/task-refine` attaches bearing dossiers to tasks (`task-analyzer` reports them), and `/whats-next` will re-surface open unknowns and aging watermarks. Hand back control.
