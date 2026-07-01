# Recording an Architecture Decision Record (ADR)

This is the shared mechanics for writing a decision to `docs/decisions/`. The
calling skill decides *when* a decision is worth recording; this file describes
*how* to record it consistently.

## Where it goes

- **Full record:** `docs/decisions/NNNN-kebab-title.md` — one file per decision.
- **Index line:** one sentence in `docs/decisions/INDEX.md` — the abbreviated form
  an agent can read without opening the full record.

## Steps

1. **Find the next number.** Look in `docs/decisions/` for the highest existing
   `NNNN-*.md`. If the directory (or `INDEX.md`) does not exist yet, create it and
   seed `INDEX.md` with the header shown below. The next number is the highest
   existing value plus one, zero-padded to four digits (`0001`, `0002`, …).
2. **Write the record** to `docs/decisions/NNNN-kebab-title.md` from the template
   below, using today's date and filling *every* section with real content. The
   rationale and the alternatives are the reason the record exists — a record
   without them is not worth writing.
3. **Append one line to `docs/decisions/INDEX.md`** — a single sentence stating what
   was decided and its outcome, so an agent grasps it without opening the record:

   ```
   - [NNNN](NNNN-kebab-title.md) — <what was decided and its outcome, one sentence> (Accepted)
   ```

Write the record the moment the decision is confirmed, while the reasoning is
fresh — never batch them at the end.

## `INDEX.md` header (only when first creating the file)

```markdown
# Decision Index

One line per architectural decision, in number order. Each links to the full
record in this directory — read a record for its context, rationale, and
alternatives; read this index to know a decision exists and how it landed.
```

## ADR template

```markdown
# NNNN — <short imperative title of the decision>

- **Status:** Accepted
- **Date:** <today, YYYY-MM-DD>
- **Deciders:** <who made the call>
- **Scope:** <what part of the system / project this governs, and what it affects>

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

## What not to record

Do not spend an ADR on an easily-reversible, low-stakes, or purely-stylistic
choice, nor on something already fully captured as a plain convention elsewhere
(e.g. a lint rule or a CLAUDE.md instruction). Over-recording buries the
decisions that actually matter. When in doubt, ask: *would a future contributor
be surprised or misled without knowing the reasoning behind this?* If yes, record
it; if no, skip it.
