---
name: spec-sharpener
description: >-
  Assess and harden a greenfield project's documentation/specification so it is
  unambiguous enough to implement from. Hunts for ambiguities, contradictions,
  gaps, undefined terms, and unstated assumptions, then interviews the user one
  issue at a time (proposing concrete options), applies each agreed fix directly
  to the docs, and logs the resolution as an ADR-style decision record. Built to
  be run repeatedly until the spec is crystal clear.
disable-model-invocation: true
---

# Spec Sharpener

Turn a fuzzy early-stage specification into one that a competent engineer could
implement without having to guess. This is an **interview-and-edit** workflow,
not a report generator. The deliverables are (1) sharper documents and (2) a log
of the decisions that made them sharper.

## When this applies

The project is greenfield: docs/spec exist, but there is no real implementation
yet — at most boilerplate (a scaffolded repo, a `package.json`, an empty folder
structure). The goal is to make the *specification* implementation-ready. The
boilerplate is treated as a signal (what framework, what naming, what shape was
assumed), not as the thing being refined.

Expect to be run **multiple times**. Each run picks up where the last left off,
reads what has already been decided, and keeps going until nothing material
remains.

## Core principles

- **One issue at a time, deeply.** Surface a single finding per turn, resolve it
  fully, then move on. Never dump the whole backlog as a list.
- **Always propose concrete options.** Don't just point at a problem. Offer 2–4
  specific resolutions with their trade-offs so the user has something to react
  to. A good option list does most of the thinking for them.
- **Edit in place, incrementally.** When a finding is resolved, make the
  smallest edit to the real document that encodes the decision. Preserve the
  doc's voice and structure. Don't rewrite whole sections wholesale.
- **Record every decision.** Each resolution becomes an ADR-style record so
  future runs don't re-litigate settled questions and so the reasoning survives.
- **Never invent intent.** Where the spec is silent, ask — don't quietly fill
  the gap with an assumption. The user is the source of truth for what they want.
- **Flag everything, but in priority order.** The bar for flagging is low (down
  to wording and style), but the order is strict: things that *block* a build
  come before things that would *fork* a build, which come before clarity, which
  comes before pure wording.

## Workflow

### Step 0 — Orient

1. Discover the documentation. Look across the repo, not just the README:
   `README*`, `docs/`, `doc/`, `spec*/`, `design*`, `requirements*`,
   `ARCHITECTURE*`, `*.md`, `openapi*/`, schema files, and any config that
   reveals intent (`package.json`, `pyproject.toml`, `Cargo.toml`, etc.).
2. Locate the decisions log if one exists. Check `docs/decisions/`, `docs/adr/`,
   `adr/`, `decisions/`, `DECISIONS.md`, `docs/decisions.md`. If `docs/decisions/INDEX.md`
   exists, read it first for a one-line map of what's been decided, then read the full
   records. **Treat `Accepted` decisions as settled** — do not re-raise them unless the
   user asks or a *new* contradiction with one has appeared.

### Step 1 — Build a model of the intended system

Read everything and form a concrete mental model: who the users are, what the
system does, its main entities and flows, its constraints, what's in and out of
scope. You can't spot a contradiction or a gap without a model to check against.
If something is so unclear that you can't even build the model, that's your first
finding.

### Step 2 — Sweep for findings

Go through the documents systematically against the finding taxonomy in
`references/finding-taxonomy.md`. Read that file now — it is the checklist that
makes the sweep thorough and repeatable (ambiguities, contradictions, gaps,
undefined/inconsistent terms, unstated assumptions, interface/data-model issues,
non-functional gaps, testability, boilerplate-vs-spec mismatches, wording).

Hold the resulting findings as an internal, prioritized backlog. Do **not** print
it as a list.

### Step 3 — Open the interview

Give the user a one-line orientation only — a rough tally, e.g. *"I went through
the spec and found around a dozen things, from a couple of real blockers down to
some wording. Let's take them strongest-first, one at a time."* Then go straight
into the first (highest-priority) issue. No findings report.

### Step 4 — The interview loop (per issue)

For each finding, present it in this shape:

> **Where:** `path/to/doc.md` — quote or pinpoint the exact spot.
> **What:** State the problem plainly (the ambiguity / contradiction / gap).
> **Why it matters:** Make it concrete — e.g. *"a developer could reasonably
> read this as X or as Y, and would build two different things."*
> **Options:** 2–4 concrete resolutions, each with a one-line trade-off. Mark a
> recommended default when you genuinely have one.
> **Your call:** Ask them to pick an option, blend them, or give their own.

Adapt the mode to the kind of finding:
- **Spec is silent (a gap):** you're eliciting their intent — options are
  educated guesses to react to.
- **Internal contradiction:** show both conflicting statements and ask which one
  wins (or whether both are partly right).
- **Pure wording/clarity:** propose a precise rewrite for a yes/no.

Then **keep going until there is genuine shared understanding.** If the user is
unsure, refine the options, ask a narrowing question, or surface a consideration
they may not have weighed. Do not move on while they're still hedging. One
finding may take several turns — that's expected and good.

### Step 5 — Encode the decision

Once the user confirms a resolution:

1. **Edit the document(s).** Make the minimal change that encodes the decision.
   If the decision touches multiple docs, update all of them so they stay
   consistent. Briefly confirm what changed (a line or two) — don't paste the
   whole document back.
2. **Write the decision record.** Append an ADR-style record using
   `assets/decision-record-template.md`. See "Decision records" below for where
   it goes and what it contains.

### Step 6 — Next, or wrap

Move to the next highest-priority finding and repeat Step 4. Continue until the
user wants to pause or the backlog is exhausted for this run. When you pause,
give a one-line status: how many resolved this run, how many remain, and the
nature of what's left.

## Decision records

Keep a dedicated, ADR-style log so decisions are durable and reruns are cheap.

- **Location:** use the project's existing decisions location if you found one in
  Step 0. Otherwise create `docs/decisions/` and write one markdown file per
  decision, named `NNNN-kebab-title.md` with a zero-padded sequential number
  (`0001-…`, `0002-…`). Determine the next number from the highest existing file.
- **Contents:** copy `assets/decision-record-template.md` and fill it in —
  number, title, status (`Accepted`), date, deciders, scope, the documents it
  affected, the context (the original ambiguity, with the quoted spot), the
  decision (the new source of truth), the rationale, the alternatives that were
  rejected and why, and the consequences.
- **Index it.** Append one line to `docs/decisions/INDEX.md` — the abbreviated,
  one-sentence form so an agent can grasp the decision without opening the full
  record: `- [NNNN](NNNN-kebab-title.md) — <what was decided and its outcome> (Accepted)`.
  Create `INDEX.md` if it doesn't exist yet, seeding it with a `# Decision Index`
  header that says one line per decision links to its full record. This shared
  `NNNN-title.md` + `INDEX.md` convention is the same one the milestone-driven
  skills use, so a project sharpened here and then built stays on one decision log.
- One record per resolved finding. Write both the record and its index line right
  after the edit, while the reasoning is fresh, before moving to the next issue.

## Re-running

On every run: redo Step 0 (re-read docs *and* the decision log), rebuild the
model, re-sweep, drop anything already settled, and continue the interview on
what remains — including new issues introduced by recent edits. When a full sweep
turns up no remaining blockers or fork-risks and only trivial-or-nothing is left,
say so plainly: the spec looks implementation-ready, with a note on any residual
minor items the user chose to leave.

## What not to do

- **Don't produce a standalone findings report** as the deliverable. The output
  is the interview plus the edits plus the decision log.
- **Don't dump the backlog.** One issue per turn.
- **Don't edit ahead of agreement.** No change lands until the user confirms it.
- **Don't advance prematurely.** Resolve and record the current issue before the
  next one.
- **Don't fabricate requirements.** Silence in the spec is a question for the
  user, not a license to decide for them.
- **Don't re-open settled decisions** without cause.
