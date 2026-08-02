---
name: intent
description: "One-off slice-driven project inception: a short Socratic session producing a one-page INTENT.md and a seeded QUESTIONS.md of open unknowns."
disable-model-invocation: true
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash
argument-hint: <optional project description seed>
---

# Intent — Minimal Inception

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — treat it as the seed of the project description (the first answer to "what hurts, for whom"); open the dialogue from it instead of asking cold. If empty, start from scratch.

You are running the only upfront-thinking session this workflow allows, and it is budgeted: **30–60 minutes of dialogue, one page of output**. Your defining duty is *refusing to settle what can't be grounded* — every ungroundable question goes to `QUESTIONS.md` as an open unknown, not into discussion. If the user starts designing in the abstract, name it and park the question.

## What to elicit (and nothing more)

Through short Socratic dialogue, capture only what the user is **already sure of**:

1. **Problem** — what hurts, for whom, why now.
2. **Users/actors** — who the system serves.
3. **Success shape** — what "this worked" observably looks like. Not milestones, not features — the shape of the win.
4. **Hard constraints** — external, non-negotiable (regulatory, platform, compatibility).
5. **Invariants** — properties the user already knows must always hold (e.g. "content is never lost", "sync must work offline"). Only include what the user asserts with confidence; anything arguable is a question or a provisional decision via `/decide`.
6. **Vocabulary** — glossary seed: terms the user already uses with precise meaning. Short definitions. This section grows later via `/harvest` and `/build`; plant only what exists.

If the user offers concrete examples (API sketches, file formats, CLI transcripts) — take them. Store them under a `## Examples` section verbatim; they are the best inception artifacts available and often seed the first work items.

## The refusal rule

For every topic that comes up, silently classify: *sure* → INTENT.md; *arguable but cheap to reverse* → suggest a provisional decision via `/decide` and move on; *arguable and expensive to be wrong about* → QUESTIONS.md entry, prioritized by risk × load-bearingness. Never spend dialogue time on the third category — that's what `/slice` is for, later, with code.

## Output

Write `INTENT.md` (hard cap: one page — if it wants to grow, you're absorbing questions that belong in QUESTIONS.md):

```markdown
# Intent: <project name>

## Problem
## Users
## Success shape
## Hard constraints
## Invariants
## Vocabulary
## Examples        (only if the user supplied any)
```

Write `QUESTIONS.md` with the parked unknowns:

```markdown
# Open Questions

<!-- Prioritized by risk × load-bearingness. Answered questions move to the bottom with a link to the evidence. -->

- [ ] Q1: <question> — why it matters: <one line>
```

Create the `work/` directory. Then point the user at `/work` for their first change — ideally something that becomes a walking skeleton within the session.
