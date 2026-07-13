---
name: task-refine
description: >
  Refine a draft task into a ready `todo`: assess it for spec completeness,
  domain-compliance (against its bounded context's ubiquitous language and
  relationships), and implementation size; interview the human until goal and
  success criteria are shared; split it if it is too big to land in one go; wire
  its dependencies; and surface decisions, offering ADRs and recording the ones
  that affect it. Delegates the read-heavy assessment to the task-analyzer
  subagent. Advances the task(s) draft -> todo (or the original -> split).
disable-model-invocation: true
argument-hint: "[<id>]   (default: the lowest-id draft task)"
model: opus
allowed-tools: Read, Write, Edit, Glob, Agent, Skill, Bash(bash */skills/task-status/tasks.sh *), Bash(date *)
---

# Task Refine — Draft → Todo

You turn a `draft` task into a ready-to-implement `todo`. A `todo` is a task whose
goal and success criteria you and the human both understand, that is small enough
to land in one implementation pass, that fits the domain, and whose dependencies
are wired. Getting there is an **interview**, not a rewrite.

## Step 1 — Pick the task

- If an id was given, refine that one.
- Otherwise, run `bash <skills-root>/task-status/tasks.sh by-status draft` and take
  the lowest id. If there are no drafts, say so and stop.

## Step 2 — Assess (subagent)

Spawn the **task-analyzer** subagent (`subagent_type: task-analyzer`) with the task
file path and the project root. It reads the task, the relevant
`context-map/<context>.md` (and `context-map/INDEX.md` for relationships),
`domain-model.md`, and `docs/decisions/INDEX.md`, then returns a structured
assessment:

- **Completeness** — what the spec is missing (unclear outcome, no success
  criteria, hidden ambiguity).
- **Domain-compliance** — does the task fit a bounded context? Does it use that
  context's ubiquitous language correctly? Does it leak across a boundary in a way
  the relationship pattern forbids? Is it phrased as an outcome, or has it slipped
  into premature implementation detail?
- **Size** — does this look like one implementation pass, or several? If several,
  a suggested split.
- **Dependencies** — other tasks (by id) or unbuilt prerequisites this needs.
- **Decisions** — choices the human must make, and which existing ADRs
  (from the index) already bear on this task.

The subagent reads the corpus so you don't — you receive only its report.

## Step 3 — Interview the human (Socratic, one question at a time)

Work through the assessment with the human, **one question at a time**, reflecting
back what you hear. Drive to:

- A **clear outcome** and concrete **acceptance criteria** you could verify.
- **Domain fit.** If the analyzer flagged a domain conflict, surface it plainly:
  a task that violates the domain means *either the task has the wrong shape / is
  too implementation-oriented* (reshape it) *or the map itself is wrong* (note it
  and tell the human to revisit `/domain-model` or `/context-mapping` — do not
  silently "fix" the task around a broken map).
- The right **context** for the task's frontmatter.

## Step 4 — Split if too big

If the task can't land in one implementation pass, propose a split and get the
human's agreement on the pieces. Then, as **two passes**:

**Pass A — create children and tombstone the original.**
1. For each child, mint an id (`tasks.sh next-id`, one at a time) and write a new
   `tasks/NNNN-slug.md` in `status: todo` with its own outcome/criteria and any
   dependency ordering *among the children*.
2. Rewrite the original task to a **tombstone**: set `status: split` and
   `split_into: ["NNNN", ...]` listing the children; leave its body as the record
   of what it was. A tombstone is inert — it schedules nothing.

**Pass B — rewire dependents.** Run
`bash <skills-root>/task-status/tasks.sh dependents <original-id>` to find every
task that had `depends_on: [<original>]`. For each, with the human decide **which
child** (or children) it should now depend on — do not blindly repoint to all
children — and edit its `depends_on` accordingly. Leaving a dependent pointing at
the split tombstone is a bug (`check-dag` will flag it as dangling).

## Step 5 — Decisions & ADRs

For each genuine decision surfaced: if it is significant and expensive to reverse,
**offer** to record it via `Skill(adr)` (never auto-create). For every ADR — newly
recorded or pre-existing — that constrains the task, add its number to the task's
`related_adrs` frontmatter so the implementer inherits it. Add any strategic docs
the implementer needs (e.g. the context file) to `related_documents`.

## Step 6 — Finalize to `todo`

For each resulting task (the single refined task, or each split child), set:
`status: todo`, `context: <slug>`, filled-in `## Outcome` / `## Acceptance
criteria` / `## Why this matters`, and a `## Notes` section capturing what the
refinement settled. Wire `depends_on` to the ids the interview identified.

Then **guard the graph:** run `bash <skills-root>/task-status/tasks.sh check-dag`.
If it reports a cycle or a dangling reference, you introduced it — fix the offending
`depends_on` before finishing. Do not leave the backlog with a failing check-dag.

## When you are done

Report: which task(s) are now `todo`, any tombstoned split, the dependencies wired,
and any ADRs recorded or attached. If drafts remain, mention that `/task-refine`
can take the next one. Do not implement anything — `/task-cycle` does that.
