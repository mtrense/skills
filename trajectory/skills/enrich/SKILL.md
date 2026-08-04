---
name: enrich
description: >
  Break a trajectory milestone down into well-shaped tasks: a dialog that ticks the boxes of
  the next (or given) milestone and persists tasks/NNNN-slug.md files, each with a plan,
  decision/documentation references, complexity, dependencies, acceptance criteria, and
  proves links for pending-proof decisions. Refuses to break down a milestone with unresolved
  decision or needs-proving items (routes to /decide first). Also the re-shaping entry point when /burn hands
  back an UNDERESTIMATED task. Trigger on "/enrich", "break down the milestone", "turn the
  milestone into tasks", "reshape task NNNN", or when /burn routes an underestimated task
  here. Do NOT trigger for milestone-less small tasks (that's /supplement) or milestone
  definition (that's /aim).
argument-hint: <optional milestone id, or task id to re-shape>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent, AskUserQuestion
---

# Enrich — Milestone to Well-Shaped Tasks

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — a milestone id, or a task id to re-shape (see "Re-shaping" below). If empty, take the lowest-id open milestone that has unbroken-down ground (`bash ../_shared/scripts/backlog.sh by-status milestone open`, then `backlog.sh by-milestone <id>` to see what already exists — relative paths from this skill's directory).

**A persisted task is by definition clear and well shaped.** All shaping happens *before* writing files — propose several tasks where the milestone item looks like one, merge where two items are one change — because tasks are never split after persistence; their ids stay live for their whole life.

## Gate: open decisions block breakdown

Read the milestone file. If any `## Decisions to make` **or** `## Needs proving` item is unchecked (no `decision: NNNN` back-reference), **refuse to break the milestone down** and route the items to `/decide` — a task written against an unmade decision just encodes a guess, and a needs-proving item that never became a `proof: pending` decision can't be wired into any task's `proves` list, so the obligation silently evaporates (`pending-proofs` comes back empty and `/land` finds nothing to clear). This is a hard gate; the user overriding it should be rare and explicit.

## The breakdown dialog

Work through the milestone's outcome with the user, proposing a breakdown into tasks. For each proposed task, assemble:

- **Plan** — concrete implementation steps, including the files to touch if possible (ground this in the actual codebase — targeted Reads/Greps or a quick scout, not guesswork).
- **References** — the relevant decisions (ids into `decisions:`) and other documentation/examples (`documents:`). Read the `documentation/<topic>.md` digests, not the full records.
- **Complexity** — `low | medium | high`, an abstract reasoning-difficulty estimate (never a model name); `/burn` dispatches its model tiers on it.
- **Dependencies** — `depends_on` edges to other tasks (existing or in this batch).
- **Acceptance criteria** — externally observable checks, one list; this is exactly what the `grader` will hold the worker to, so write them testable.
- **Proves** — for any `proof: pending` decision this task will demonstrate, its id in `proves:`. Check `backlog.sh pending-proofs` for obligations this milestone (or an earlier one) is still carrying — a task here may prove an earlier milestone's decision.

**Duplicate/link scan:** for each proposed task, spawn the `task-linker` subagent (proposal + `backlog.sh` path). It proposes links to existing open tasks instead of duplicating them — fold its verdicts into the breakdown (drop covered tasks, add proposed edges) and surface judgment calls to the user.

**Vocabulary check:** check every task's names, terms, and acceptance criteria against `VISION.md`'s `## Vocabulary` section. A task that needs a term the vision doesn't have surfaces that gap explicitly — extend the vocabulary via a `/kickoff` revision, or fix the wording — never quietly coin a synonym.

The user reorders, vetoes, and re-scopes; nothing persists until the breakdown is agreed.

**How to ask** (see [Asking the user](../_shared/workflow-overview.md#asking-the-user)). Present the proposed breakdown as prose — a list of tasks is not a multiple choice, and the user's reordering and re-scoping needs room. Reach for `AskUserQuestion` on the closed calls that fall out of it:

- **Cut lines** — when one milestone item could reasonably be one task or several, offer the candidate splits as options (`preview` showing each split's task titles makes the comparison concrete).
- **Linker judgment calls** — per surfaced overlap: *fold into task NNNN* / *keep separate, add a `depends_on` edge* / *keep separate, unrelated*.
- **Vocabulary gaps** — *extend the vocabulary via a `/kickoff` revision* / *reword the task to an existing term* — never silently pick one.
- **Complexity** when genuinely borderline: `low` / `medium` / `high`, with the description naming what the tier buys (it is `/burn`'s model routing).

Batch related closed calls into one `AskUserQuestion` call rather than one turn each.

## Persist

Per agreed task: `bash ../_shared/scripts/backlog.sh new task <slug> <title>`, then Edit the frontmatter lists (`milestones: ["<this milestone>"]`, `complexity`, `depends_on`, `decisions`, `proves`, `documents`) and fill `## Plan`, `## Acceptance criteria`, `## Notes`.

Then: `bash ../_shared/scripts/backlog.sh check` (hard gate — fix anything it flags). Do **not** commit — this skill runs in the foreground; name the task files written and leave them for the user to review and commit (`/commit`).

## Re-shaping an underestimated task

When `/burn` hands back an UNDERESTIMATED task (or the user names one), reshape without splitting: **narrow the original in place** — its id, dependents, and `proves` links stay live — and mint fresh tasks for the carved-off remainder, wiring their `depends_on` and moving any `proves` link the narrowed original no longer delivers. Use the worker's `learned:` report as the primary input; the same linker/vocabulary/check rigor applies (and the same no-commit rule).

## Rejection ripple

If the dialog rejects a task (the human decides not to do it): `backlog.sh set-status task <id> rejected`, then immediately `backlog.sh dependents <id>` and rewire every edge in this session — to a replacement or by dropping it (a live dependency on a rejected task fails `check`). If the task was on a decision's `proves` side, re-home the proof on another task or route the decision to `/decide`. Both rewirings are closed sets — ask them with `AskUserQuestion` (one question per dangling edge: *repoint to task NNNN* / *drop the edge*; for the proof: *re-home on task NNNN* / *route to `/decide`*), so nothing is silently chosen on the user's behalf.

## Wrap-up

Show the board. If every milestone item is covered, note that `/burn` can start; list what `backlog.sh ready` would pick first.
