---
name: burn
description: >
  Burn a trajectory backlog down: drive available tasks (todo with all dependencies done,
  ascending id) through parallel burn-worker subagents in git worktrees — strict TDD, commit
  via /commit — then grader → serialized closing-record scribe → sequential merge →
  serialized doc-sync → demo checks for the demos the task serves. Workers and graders
  self-brief from pointers (task file path, worktree); the worker's full report lives in
  .burn/REPORT.md, never in this session. Takes a [<count>|all|demo:<id>][@<workers>]
  argument (demo:<id> burns only what that demo needs and stops when its check turns
  green), dispatches workers on the model tier each task's complexity maps to, escalates
  one tier on grader rejection or post-merge test failure (at most once per task per run),
  bounces merge conflicts to a fresh worker on the updated base, stops at hold-gated demos
  that turn green, and hands UNDERESTIMATED tasks back to /enrich. Resumable and idempotent.
  Trigger on "/burn", "burn down the backlog", "work the tasks", "start implementing", "run
  the workers", "build until the demo works". Do NOT trigger for shaping work (that's
  /enrich or /supplement) or the human test cycle on a green demo (that's /land).
argument-hint: "[<count>|all|demo:<id>][@<workers>]  (default all@1)"
model: sonnet
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent, AskUserQuestion
---

# Burn — The Burn-down

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — `<target>@<workers>` (e.g. `5@2`, `all@4`, `demo:0003@2`, `3`, `@2`); default `all@1`. The target is one of:

- `<count>` — land at most that many tasks;
- `all` — burn until the available set is empty;
- `demo:<id>` — burn only the tasks that demo needs (`backlog.sh ready --demo <id>`: tasks listing it plus what they transitively depend on) and **stop once its check is green and no live task lists it**. This is the natural unattended goal: not "N tasks" but "until the thing can be shown". (A demo can be green with live tasks still listing it — fixes `/land` captured for things only a human can judge; those are burned before the goal counts as met.)

`<workers>` is the parallel worker width.

**You are the orchestrator, and you own the backlog.** Workers never touch task/demo/decision files or any `status` — they implement, commit code via `/commit` in their worktree, and report. Every status flip goes through `bash ../_shared/scripts/backlog.sh …` (relative to this skill's directory), and grader-feedback appends are yours; the one delegated backlog write is the closing record, written by the serialized `burn-scribe` on your behalf. Demo statuses are never yours to set: `backlog.sh demo-check` runs each demo's check and flips it.

**Pass pointers, not content.** Never read a task body, decision digest, or worker report into your own context: workers and graders self-brief from the task file and `documentation/` inside the worktree, workers park their full report at `.burn/REPORT.md` in the worktree (returning only a compact control block), and the scribe reads that file directly. You handle ids, paths, statuses, and one-line results.

## Setup

1. **Model map** — `cat .workflow-overrides/model-map 2>/dev/null || echo "low=sonnet medium=opus high=opus"`. Workers are dispatched with the Agent tool's `model` parameter set per the task's `complexity`; the task file stays abstract.
2. **Reclaim crashed tasks** — any task `backlog.sh by-status task in-progress` lists that has no live worktree behind it (`git worktree list`) is a crashed or killed prior run: flip it back to `todo`. This is what makes `/burn` resumable and idempotent.
3. **Demo target** (`demo:<id>` only) — run `backlog.sh demo-check <id>` first. Already green with no live task listing it → there is nothing to burn; say so and point at `/land`. Green with live tasks → burn those. Red with an empty `ready --demo <id>` set → `demo-state <id>` tells you whether it is waiting on in-progress or blocked work or is STALLED; for a stalled demo point at `/enrich <id>` and stop.
4. **Available set** — `backlog.sh ready` (or `backlog.sh ready --demo <id>`): `status: todo` with every `depends_on` done, ascending id. That id order IS the pick order. Re-derive this set each pass — landings unlock new tasks mid-run.
5. **Run state** (session-only, never persisted): per task — escalation used? (max once per task per run, whatever triggered it), grader rejections this run, excluded-from-run flag; per run — demos that turned green, demos that regressed, and whether a `hold` gate fired. After a crash, resume restarts a task at its **base** tier; only the appended grader feedback survives as guidance.

## The per-task sequence

Claim: `backlog.sh set-status task <id> in-progress`, commit the flip (pathspec, see Commits below). Then:

### 1. Worker

Create a worktree (`git worktree add .worktrees/task-<id> -b task/<id>`), and spawn a `burn-worker` there at the task's mapped tier with pointers only: the worktree path and the task file's path inside it. The worker self-briefs — it reads the task body (including any `## Grader feedback` from earlier rejections; the claim/feedback commits precede worktree creation, so its copy is current) and the linked decisions' digest lines itself. It parks its full report at `.burn/REPORT.md` in the worktree and returns a compact control block. Up to `<workers>` workers run in parallel, one task each.

- Worker returns `UNDERESTIMATED` → flip the task back to `todo`, exclude it from this run, and hand it to `/enrich` for re-shaping (surface the `learned:` block to the user). Never burn tokens pushing a doomed attempt through.
- Worker returns `blocked` → surface to the user, back to `todo`, exclude from run.

### 2. Grader

Spawn the `grader` with pointers only: the task id, the task file's path (in the worktree), the worktree path + commit, and the report file (`.burn/REPORT.md`). It self-briefs on the criteria and linked decision digests, then grades **strictly against criteria and decisions — nothing else**, reviewing diff and report file; it does not re-run tests (the worker owned them pre-commit, the merge re-runs them post-merge). It also verifies the report's manual-testing record against the shipped code — that record is about to become the task's durable closing record, and this is the only point where anything compares it to reality; an unsupported quote is a rejection even when every criterion is met.

- **Reject (first):** flip the task to `todo`, append the grader's feedback to the task file under `## Grader feedback`, commit that edit, drop the worktree, and retry with a **fresh worker at the next model tier up** (a `high` task retries at the same top tier — there is nothing above). This consumes the task's one escalation for the run.
- **Reject (second):** surface to the user with both grade reports; the task stays `todo` and is excluded from this run's later passes, so the run can't loop on it.
- **Accept:** proceed to merge.

### 3. Closing record (serialized scribe)

On accept, before the merge (the merger removes the worktree — and the report file with it): spawn the `burn-scribe` — strictly one at a time, in landing order — with the task id, the **mainline** task file's path, and the report file (`.burn/REPORT.md` in the worktree). It writes the `## Manual testing` and `## Deviations` sections into the task file and commits them with a pathspec. This once-written record is what every `/land` relying on the task reads. (If the merge later bounces, the record is stale but harmless: the retry's scribe pass replaces it wholesale before the task can land.)

### 4. Merge (sequential)

Spawn the `merger` — one at a time across the whole run, in landing order — with the repo root, mainline, worktree/branch, and the test command.

- **BOUNCE (textual conflict):** not a quality problem. Task back to `todo`, re-queued for a fresh worker on the updated base **at the same tier** (a bounce never triggers escalation, and doesn't consume the escalation budget). A task bouncing repeatedly while the base churns is normal in wide runs; if it bounces more than twice, serialize it to the end of the run.
- **TESTS-FAILED (clean merge, red suite):** escalate a worker at the next tier up to fix forward on the merged mainline (this consumes the task's one escalation). If that doesn't succeed, **break out of the run** and surface the problem to the user — a red mainline outranks everything else.
- **MERGED:** proceed.

### 5. Doc-sync (serialized)

Spawn the `doc-syncer` with the repo root, the merge commit, and the task file's path (it reads the `documents` list and the just-written closing record itself). Strictly one at a time, in landing order — parallel workers exist, parallel doc edits to the same files don't. `no-op` is the common, correct result for internal changes.

### 6. Land

Flip the task to `done` and commit the flip (pathspec).

### 7. Demo checks

If the task lists demos (`backlog.sh get task <id>` → `demos`), run `backlog.sh demo-check <those ids>` on the merged mainline and commit the demo files it rewrote (pathspec — `demo-check` updates `status` and `checked_at`). Read only its one-line-per-demo output; the full output stays in `.trajectory/demo-NNNN.log`. Then act on each line:

- **Turned green** (`GREEN … FLIPPED from red`) — the demo is ready for the human test cycle. Record it in run state. If its `gate` is `hold`, the run **stops dispatching**: let in-flight tasks finish their sequence, then wrap up — the next work depends on the human's verdict. With `flag`, keep burning. If it is the `demo:<id>` target and no live task lists it any more, the run's goal is met: let in-flight tasks finish, then wrap up.
- **Regressed** (`RED … FLIPPED from green`) — a demo that worked no longer does, and this merge is the first suspect. Surface it (see below) before dispatching more work; never let a demo the human may be about to look at silently break.
- **Still red** — expected while the demo's tasks are still in flight; nothing to do.
- **Still green** — in `demo:<id>` mode, re-test the goal: once no live task lists the target, it is met.

Demo checks run project code with this session's permissions. A red result caused by the environment (a sandbox-blocked port bind, no network) is not a regression — say so in the wrap-up rather than acting on it.

## Surfacing to the user

`/burn` runs unattended by design, so the few points where it *does* stop for the user are exactly the ones worth posing as `AskUserQuestion` — each is a closed set with a clear default, and an option list resolves it in one turn instead of a prose round-trip mid-run:

- **Second grader rejection** — *hand to `/enrich` for re-shaping* / *retry once more at the top tier* / *leave in `todo`, excluded from this run* (the default).
- **Worker `UNDERESTIMATED` or `blocked`** — *re-shape via `/enrich` now* / *park it and continue the run* (the default) / *stop the run here*.
- **Break-out on a red mainline** (post-merge tests still failing after the escalation) — *revert the merge* / *stop the run and leave mainline as-is for inspection*. A red mainline outranks everything else, so ask, never guess.
- **Demo regression** — *revert the merge of task NNNN* / *fix forward: escalate a worker on the regression* / *continue and record it* (the regression then heads the wrap-up). Default to fixing forward when the log points squarely at the merged change.

Keep the surrounding narration compact: the question carries the decision, not a replay of the worker's report (which stays in `.burn/REPORT.md`). Everything else in the run — status flips, escalations, bounces, doc-sync, demo checks — is yours to decide and merely reported at wrap-up. See [Asking the user](../_shared/workflow-overview.md#asking-the-user).

## Commits

Code commits belong to workers (via `/commit`, in their worktrees) and land through the merger; closing records to the scribe. Every backlog-file change you write yourself — status flips, grader feedback, the demo files `demo-check` rewrote — is committed separately with an explicit pathspec: `git add <files> && git commit -m "burn: <event>" -- <files>`, only the file(s) just written, so bookkeeping can never sweep unrelated working-tree changes along. Never batch across tasks. `.trajectory/` holds scratch logs and is never committed.

## Run wrap-up

Stop when the target is met (`<count>` tasks landed, the `demo:<id>` check green with no live task listing it), a `hold` demo turned green, the available set is empty, or a break-out fired. Before reporting, run `backlog.sh demo-check --all` once on the final mainline (commit the rewritten demo files) — a demo can turn green from work no task declared, and every report should state each open demo's status at the commit the run ended on.

Report:

- **Demos ready to show** — every demo that is green now, its gate, and the pointer: `/land <id>` runs the human test cycle. Lead with this; it is why the run happened.
- **Regressions** — demos that went from green to red, with the suspected merge.
- **Stalled demos** — red with no live task (`backlog.sh demo-state`): the missing work was never written down → `/enrich <id>`. In `demo:<id>` mode, an exhausted available set with the target still red is exactly this.
- Tasks landed (with merge commits), tasks bounced/excluded and why, escalations used (note a landed escalation in the task's `## Notes`), UNDERESTIMATED hand-backs, and the board (`backlog.sh board`).
