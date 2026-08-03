---
name: decide
description: >
  Record and gatekeep decisions in the slice-driven workflow: write decision records with a
  grounding tier (grounded with evidence link, or provisional assumption), and arbitrate when
  a settled decision is challenged. Trigger when the user says "/decide", "record this
  decision", "let's lock this in", "I'm doubting decision X", "should we revisit…", or when
  another slice-driven skill (work, harvest, build, intent) makes or challenges a decision.
  Invoked with no argument, it takes on the next provisional decision and works it through
  a Socratic dialogue.
  Do NOT trigger for read-only lookups ("what did we decide about X?") — answer those from
  DECISIONS.md directly.
argument-hint: <optional decision statement, or the decision being doubted>
allowed-tools: Read, Glob, Grep, Edit, Write, Bash
---

# Decide — Evidence-Tiered Decision Records

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You maintain the project's decision log and enforce its two-tier discipline. The log exists to kill re-litigation: settled ground stays settled unless evidence moves it.

The user's argument, if any: `$ARGUMENTS` — either a fresh decision to record (start at Recording, using it as the draft one-sentence form) or a reference to an existing decision being doubted (start at the reopening gate). Tell the two apart by checking `DECISIONS.md`. If empty, run the **standing-assumption pass** below.

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

## The standing-assumption pass (no argument)

Called with no argument, you work the decision log's oldest standing assumption. Run `../_shared/scripts/board.sh` (relative to this skill's directory) and read its **OPEN DECISIONS** section. Take the lowest-numbered `provisional` record; show the list and say which one you're taking so the user can redirect. Ignore the `undecided: … — awaiting probe N` lines: those are already routed to a slice, and re-deciding them in dialogue is exactly the debate the probe exists to replace. If there are no provisional records, say the log holds no standing assumptions and stop — never invent a decision to review, and never widen the pass into an audit of the log.

Then read the record in full and run a **Socratic dialogue** to reach shared understanding of the assumption — not to talk it into being grounded. Open by restating, in your own words, the assumption and what its Grounds say would invalidate it, then ask **one question at a time** and let the answer choose the next:

- What has happened since it was recorded — code shipped, a slice harvested, a benchmark run — that bears on it?
- What is currently leaning on it (which work items, which spec sections)? If nothing is, it may not be worth carrying.
- What would we observe if it were wrong, and would we have noticed by now?
- Is being wrong here still cheap, or has the accumulating dependency made it expensive?

The dialogue closes on exactly one of these, and you name which:

- **Sharpen** — the assumption stands but the record is vague: tighten the Decision sentence and, above all, make the invalidation condition in Grounds concrete. Stays `provisional`.
- **Ground** — only if the dialogue surfaced a *concrete* evidence link (a landed commit, a harvested slice, benchmark output) that the record didn't cite. Flip `grounding: grounded`, fill `evidence:`, write what the observation showed, update the index line. Agreement in conversation is never evidence; if there's no artifact to link, this outcome is unavailable.
- **Supersede** — the assumption is now known wrong: write the replacement record, flip this one to `superseded` with `superseded_by`, update both index lines, leave its content untouched.
- **Probe** — grounding needs running code and being wrong is expensive: spawn a probe item scoped to exactly this decision and route to `/slice`.
- **Retire** — nothing depends on it any more and it binds nothing: say so, and record that in Consequences rather than deleting the record.

Keep it short. One decision per invocation; close by noting how many provisional records remain, so a repeat invocation drains the backlog naturally.

## The reopening gate

When a decision is challenged (by the user's doubt or by a skill hitting a conflict):

- **provisional** → doubt is legitimate by definition. Don't debate. Offer: (a) if being wrong is cheap, revise the record directly and move on; (b) if expensive, spawn a probe item scoped to exactly this decision and route to `/slice` — the answer comes back as evidence.
- **grounded** → show the record's Grounds first; most doubt dies on contact with the evidence that settled it. It reopens only if the challenger brings *new* evidence or a materially changed context — in which case route to a slice or supersede directly. Absent that, the decision stands; say so plainly.

Never run unprompted review passes over the decision log, and never let another skill re-ask a question a grounded decision answers.
