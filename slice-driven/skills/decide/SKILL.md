---
name: decide
description: >
  Record and gatekeep decisions in the slice-driven workflow: write decision records with a
  grounding tier (grounded with evidence link, or provisional assumption), and arbitrate when
  a settled decision is challenged. Trigger when the user says "/decide", "record this
  decision", "let's lock this in", "I'm doubting decision X", "should we revisit…", or when
  another slice-driven skill (work, harvest, build, intent) makes or challenges a decision.
  Do NOT trigger for read-only lookups ("what did we decide about X?") — answer those from
  DECISIONS.md directly.
allowed-tools: Read, Glob, Grep, Edit, Write, Bash
---

# Decide — Evidence-Tiered Decision Records

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You maintain the project's decision log and enforce its two-tier discipline. The log exists to kill re-litigation: settled ground stays settled unless evidence moves it.

## Record format

Decisions live in `decisions/NNNN-slug.md` (zero-padded ascending), indexed one-line-each in `DECISIONS.md` at the repo root:

```markdown
---
id: 12
slug: admin-api-unauthenticated
title: Admin API is unauthenticated
status: accepted        # accepted | superseded
grounding: provisional   # grounded | provisional
evidence: null           # grounded: slice branch / commit / benchmark ref
superseded_by: null
decided: 2026-08-02
---

## Decision
One or two sentences, imperative present tense.

## Context
Why this came up; the alternatives that were live.

## Grounds
grounded: what the evidence showed, with the concrete observation (numbers, transcript, branch).
provisional: the assumption being made and what would invalidate it.

## Consequences
What this binds; which work items / spec sections rely on it.
```

Index line format in `DECISIONS.md`: `NNNN-slug.md — [grounding/status] one-line decision`.

## Recording

When called with a fresh decision: confirm the one-sentence form with the user, classify the tier honestly — **grounded requires a concrete evidence link** (slice branch, commit, benchmark output); "we discussed it thoroughly" is not evidence, that's provisional — write the record, add the index line. When a slice or build supersedes a decision, write the new record, flip the old one to `superseded` with `superseded_by`, and update both index lines. Never edit a superseded record's content — the trail is the point.

## The reopening gate

When a decision is challenged (by the user's doubt or by a skill hitting a conflict):

- **provisional** → doubt is legitimate by definition. Don't debate. Offer: (a) if being wrong is cheap, revise the record directly and move on; (b) if expensive, spawn a probe item scoped to exactly this decision and route to `/slice` — the answer comes back as evidence.
- **grounded** → show the record's Grounds first; most doubt dies on contact with the evidence that settled it. It reopens only if the challenger brings *new* evidence or a materially changed context — in which case route to a slice or supersede directly. Absent that, the decision stands; say so plainly.

Never run unprompted review passes over the decision log, and never let another skill re-ask a question a grounded decision answers.
