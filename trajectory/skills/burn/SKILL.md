---
name: burn
description: >
  Burn a trajectory backlog down: drive available tasks (todo with all dependencies done,
  ascending id) through parallel burn-worker subagents in git worktrees — strict TDD, commit
  via /commit — then grader → sequential merge → serialized doc-sync → closing record.
  Takes a <count>@<workers> argument, dispatches workers on the model tier each task's
  complexity maps to, escalates one tier on grader rejection or post-merge test failure (at
  most once per task per run), bounces merge conflicts to a fresh worker on the updated base,
  and hands UNDERESTIMATED tasks back to /enrich. Resumable and idempotent. Trigger on
  "/burn", "burn down the backlog", "work the tasks", "start implementing", "run the
  workers". Do NOT trigger for shaping work (that's /enrich or /supplement) or milestone
  verification (that's /land).
argument-hint: "[<count>|all][@<workers>]  (default all@1)"
model: sonnet
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent
---

# Burn — The Burn-down

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — `<count>@<workers>` (e.g. `5@2`, `all@4`, `3`, `@2`); default `all@1`. `<count>` caps how many tasks this run lands; `<workers>` is the parallel worker width.

**You are the orchestrator, and you own every backlog write.** Workers never touch task/milestone/decision files or any `status` — they implement, commit code via `/commit` in their worktree, and report. Every status flip goes through `bash ../_shared/scripts/backlog.sh set-status …` (relative to this skill's directory), and every task-file edit (grader feedback, closing records) is yours.

## Setup

1. **Model map** — `cat .workflow-overrides/model-map 2>/dev/null || echo "low=sonnet medium=opus high=opus"`. Workers are dispatched with the Agent tool's `model` parameter set per the task's `complexity`; the task file stays abstract.
2. **Reclaim crashed tasks** — any task `backlog.sh by-status task in-progress` lists that has no live worktree behind it (`git worktree list`) is a crashed or killed prior run: flip it back to `todo`. This is what makes `/burn` resumable and idempotent.
3. **Available set** — `backlog.sh ready`: `status: todo` with every `depends_on` done, ascending id. That id order IS the pick order. Re-derive this set each pass — landings unlock new tasks mid-run.
4. **Run state** (session-only, never persisted): per task — escalation used? (max once per task per run, whatever triggered it), grader rejections this run, excluded-from-run flag. After a crash, resume restarts a task at its **base** tier; only the appended grader feedback survives as guidance.

## The per-task sequence

Claim: `backlog.sh set-status task <id> in-progress`, commit the flip (pathspec, see Commits below). Then:

### 1. Worker

Create a worktree (`git worktree add .worktrees/task-<id> -b task/<id>`), and spawn a `burn-worker` there at the task's mapped tier with: the worktree path, the full task body (including any `## Grader feedback` from earlier rejections), and the linked decisions' digest lines (pull the relevant lines from `documentation/<topic>.md` / the specific records the task's `decisions:` list names — never page the whole log). Up to `<workers>` workers run in parallel, one task each.

- Worker returns `UNDERESTIMATED` → flip the task back to `todo`, exclude it from this run, and hand it to `/enrich` for re-shaping (surface the `learned:` block to the user). Never burn tokens pushing a doomed attempt through.
- Worker returns `blocked` → surface to the user, back to `todo`, exclude from run.

### 2. Grader

Spawn the `grader` with the task's acceptance criteria, linked decisions, the worktree + commit, and the worker's report. It grades **strictly against criteria and decisions — nothing else**, reviewing diff and report; it does not re-run tests (the worker owned them pre-commit, the merge re-runs them post-merge).

- **Reject (first):** flip the task to `todo`, append the grader's feedback to the task file under `## Grader feedback`, commit that edit, drop the worktree, and retry with a **fresh worker at the next model tier up** (a `high` task retries at the same top tier — there is nothing above). This consumes the task's one escalation for the run.
- **Reject (second):** surface to the user with both grade reports; the task stays `todo` and is excluded from this run's later passes, so the run can't loop on it.
- **Accept:** proceed to merge.

### 3. Merge (sequential)

Spawn the `merger` — one at a time across the whole run, in landing order — with the repo root, mainline, worktree/branch, and the test command.

- **BOUNCE (textual conflict):** not a quality problem. Task back to `todo`, re-queued for a fresh worker on the updated base **at the same tier** (a bounce never triggers escalation, and doesn't consume the escalation budget). A task bouncing repeatedly while the base churns is normal in wide runs; if it bounces more than twice, serialize it to the end of the run.
- **TESTS-FAILED (clean merge, red suite):** escalate a worker at the next tier up to fix forward on the merged mainline (this consumes the task's one escalation). If that doesn't succeed, **break out of the run** and surface the problem to the user — a red mainline outranks everything else.
- **MERGED:** proceed.

### 4. Doc-sync (serialized)

Spawn the `doc-syncer` with the merge commit, the task's `documents` list, and the worker's notes. Strictly one at a time, in landing order — parallel workers exist, parallel doc edits to the same files don't. `no-op` is the common, correct result for internal changes.

### 5. Closing record

Write the worker's report into the task file: a `## Manual testing` section (how a human can see it working) and a `## Deviations` section (where the implementation departed from the plan). Flip the task to `done`. This once-written record is what every `/land` covering the task reads — a multi-milestone task is never re-processed. Then commit the backlog change.

## Commits

Code commits belong to workers (via `/commit`, in their worktrees) and land through the merger. Every backlog-file change you write — status flips, grader feedback, closing records — is committed separately with an explicit pathspec: `git add <task file> && git commit -m "burn: task NNNN <event>" -- <task file>`, only the file(s) just written, so bookkeeping can never sweep unrelated working-tree changes along. Batch tiny flips with the closing record where they'd be pure noise, but never batch across tasks.

## Run wrap-up

Stop when `<count>` tasks landed, the available set is empty, or a break-out fired. Report: tasks landed (with merge commits), tasks bounced/excluded and why, escalations used (note a landed escalation in the task's `## Notes`), UNDERESTIMATED hand-backs, and the board (`backlog.sh board`). If `backlog.sh milestone-ready` reports a READY milestone, point at `/land`.
