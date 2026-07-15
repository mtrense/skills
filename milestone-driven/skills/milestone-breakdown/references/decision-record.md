# Recording an Architecture Decision Record (ADR)

This is the shared mechanics for writing a decision to the project's
**architecture home** (`<architecture-home>/`). The calling skill decides *when*
a decision is worth recording — and resolves `<architecture-home>` (the default
is `architecture/`, overridable per project); this file describes *how* to record
it consistently.

## The architecture home

Everything architectural lives under one directory, `<architecture-home>/`
(default `architecture/`, overridable via an `architecture-path: <directory>` line
in `CLAUDE.md`):

- **Full ADR:** `<architecture-home>/decisions/NNNN-kebab-title.md` — one file per
  decision. This is the **single source of truth** for a decision's reasoning.
- **ADR index:** `<architecture-home>/decisions.md` — one sentence per decision,
  the abbreviated form an agent can read without opening the full records.
- **Topic summaries:** `<architecture-home>/<topic>.md` (e.g. `tech-stack.md`,
  `error-handling.md`) — crisp, current *guidelines* derived from the ADRs. You do
  **not** write these here; the `architecture-summarizer` agent (re)derives them
  after each ADR is recorded. Never edit a summary by hand as part of recording.

## Steps

1. **Find the next number.** Look in `<architecture-home>/decisions/` for the
   highest existing `NNNN-*.md`. If the directory (or `decisions.md`) does not
   exist yet, create `<architecture-home>/decisions/` and seed
   `<architecture-home>/decisions.md` with the header shown below. The next number
   is the highest existing value plus one, zero-padded to four digits (`0001`,
   `0002`, …).
2. **Write the record** to `<architecture-home>/decisions/NNNN-kebab-title.md` from
   the template below, using today's date and filling *every* section with real
   content. The rationale and the alternatives are the reason the record exists —
   a record without them is not worth writing.
3. **Append one line to `<architecture-home>/decisions.md`** — a single sentence
   stating what was decided and its outcome, so an agent grasps it without opening
   the record:

   ```
   - [NNNN](decisions/NNNN-kebab-title.md) — <what was decided and its outcome, one sentence> (Accepted)
   ```

Write the record the moment the decision is confirmed, while the reasoning is
fresh — never batch them at the end.

## `decisions.md` header (only when first creating the file)

```markdown
# Decision Index

One line per architectural decision, in number order. Each links to the full
record under `decisions/` — read a record for its context, rationale, and
alternatives; read this index to know a decision exists and how it landed. The
crisp per-topic guidelines derived from these decisions live in the sibling
`<topic>.md` files in this directory.
```

## ADR template

```markdown
# NNNN — <short imperative title of the decision>

- **Status:** Accepted
- **Date:** <today, YYYY-MM-DD>
- **Deciders:** <who made the call>
- **Scope:** <what part of the system this governs — and, where the decision is
  bound to one, name the specific artifact (frontend / backend / mobile / CLI /
  service), environment (production / testing / dev), or bounded context it
  applies to; write "whole project" only when it genuinely is unscoped>

## Context

<What forced the decision: the problem, the constraints, and the forces in
tension — enough that a reader who wasn't in the room understands why a choice
was needed.>

## Decision

<The option chosen, stated as the new source of truth — concrete and testable,
not "we'll decide later".>

## Rationale

<Why this option won over the others — the reasoning that would otherwise be lost.>

## Alternatives considered

- **<Option B>** — <why it was not chosen.>
- **<Option C>** — <why it was not chosen.>

## Consequences

<What this makes easy, what it makes hard, the costs knowingly accepted, and what
would trigger revisiting it — which would be a new ADR superseding this one.>
```

**Scope binding.** When a decision only governs one artifact, environment, or
bounded context, say so plainly in `Scope:` (e.g. "backend service only",
"testing environment only", "the `billing` bounded context"). This is what lets
the derived topic summary file the guideline under the right heading rather than
presenting it as a project-wide rule.

## After recording — refresh the summaries

Once the record(s) and the index line are written, the derived per-topic
summaries in `<architecture-home>/` must be brought back in sync. The calling
skill does this by spawning the `architecture-summarizer` agent with the
architecture home and the new ADR number(s); it maps each ADR to its topic(s) and
rewrites the affected `<topic>.md` files. Do not hand-edit the summaries here.

## What not to record

Do not spend an ADR on an easily-reversible, low-stakes, or purely-stylistic
choice, nor on something already fully captured as a plain convention elsewhere
(e.g. a lint rule or a CLAUDE.md instruction), nor on a decision already fully
encoded in the project documents written this same session (README, ROADMAP,
spec) where the rationale is a single obvious line — there, the doc itself is
the record. Over-recording buries the decisions that actually matter. When in
doubt, ask: *would a future contributor be surprised or misled without knowing
the reasoning behind this?* If yes, record it; if no, skip it.
