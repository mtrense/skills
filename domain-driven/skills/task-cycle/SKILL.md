---
name: task-cycle
description: >
  Drive ready `todo` tasks to `done`. Reads the dependency-respecting ready-set from the tasks.sh helper, claims each task (todo -> in progress), and delegates implementation to a task-worker subagent (strict TDD, verify, commit) — dispatched on the model tier the task's `complexity` frontmatter maps to (project-overridable via the .workflow-overrides/model-map file), with one escalation retry at the next tier up when a worker fails. With one worker it works in-place sequentially; with more it implements in parallel git worktrees and delegates sequential merge-back to the integrator subagent (bounce-on-conflict). The orchestrator owns every status write. Takes [<limit>|all][@<workers>] (default all@1); resumable and idempotent.
disable-model-invocation: true
argument-hint: "[<limit>|all][@<workers>]   (e.g. `all`, `3`, `all@4`, `@2`; default `all@1`)"
model: opus
allowed-tools: Read, Edit, Glob, Grep, Agent, Skill, Bash(bash */skills/task-status/tasks.sh *), Bash(git status:*), Bash(git log:*), Bash(git worktree:*), Bash(git branch:*), Bash(date *), Bash(cat .workflow-overrides/*)
---

# Task Cycle — Burn Down the Ready Backlog

You are the orchestrator. You drive tasks that are ready (`todo` with every dependency `done`) to `done`, delegating the actual implementation to subagents so your own context stays lean — you hold only ids, statuses, and worker reports, never the corpus or the implementation transcripts.

## Invariants (do not violate)

- **You own every status write.** Workers implement and commit code; they never edit a task's `status`. Only you write `todo → in progress → done` (or bounce to `todo`). This keeps the enum single-writer and race-free.
- **Never scan task files.** Every question about the backlog comes from `bash <skills-root>/task-status/tasks.sh …`, which returns ids only.
- **Only dispatch ready tasks.** A task is dispatchable only when `tasks.sh ready` lists it. Recompute the ready-set after every batch — completing a task unblocks its dependents.

## Step 0 — Parse the argument & preflight

- Parse `[<limit>|all][@<workers>]` (default `all@1`): `limit` = max tasks to complete this run (`all` = no cap); `workers` = parallelism.
- **Refuse on a dirty tree.** Run `git status --porcelain`; if it is non-empty, stop and tell the human to `/commit` or stash first — workers commit, and a dirty tree makes bounce/rollback ambiguous.
- **Guard the graph.** Run `bash <skills-root>/task-status/tasks.sh check-dag`. If it reports a cycle or dangling reference, stop and report — the backlog is unschedulable until `/task-refine` fixes it.
- **Resolve the model map.** Each task's `complexity` frontmatter (`low | medium | high`, set by `/task-refine`) routes it to a model tier. The effective map — the project's `.workflow-overrides/model-map` file (one line, e.g. `low=haiku, medium=sonnet, high=opus`), or the default when that file doesn't exist — is resolved right here at invocation:

  !`cat .workflow-overrides/model-map 2>/dev/null || echo 'low=sonnet, medium=sonnet, high=opus   (default — no .workflow-overrides/model-map file)'`

  Use exactly this map; do not re-derive it. An empty/missing `complexity` routes as `medium`. The escalation ladder is the map's distinct models ordered `low → medium → high`.

## Step 1 — Scheduling loop

Repeat until `limit` is reached or no tasks are ready:

1. `ready=$(bash <skills-root>/task-status/tasks.sh ready)`.
2. If `ready` is empty:
   - If tasks remain in `todo` (blocked by not-yet-done deps) but none are ready, report the stall (which tasks, blocked on what — use `tasks.sh blockers`) and stop. This is not an error; their prerequisites simply aren't done.
   - Otherwise the backlog is drained — stop with a summary.
3. Take the next `min(workers, |ready|, remaining_limit)` ids as this batch. (Tasks in one ready-batch never depend on each other — a dependent isn't ready until its dependency is `done` — so batch order is unconstrained.)
4. **Claim** each batch task: edit its frontmatter `status: todo → in progress`, noting its `complexity` (it's in the same frontmatter) for routing.
5. Dispatch by mode (below), passing each worker the `model` its task's complexity maps to (via the Agent tool's `model` parameter — the task file itself stays abstract; the mapping is this skill's business, never written into the task).
6. Apply results: each completed task → `status: done` + `completed: <date -u +%Y-%m-%dT%H:%M:%SZ>`, and write the worker report's `MANUAL_TESTING` and `DEVIATIONS` blocks verbatim into that task's `### Manual testing` and `### Deviations from plan` subsections (under `## Closing`, replacing their placeholders), committed via `Skill(commit)`; each failed/bounced task → back to `status: todo` (record why in its `## Notes`). If the `DEVIATIONS` block is non-trivial (anything beyond "none"/"as planned"), also set `deviated: true` in that task's frontmatter — this flags the task for the drift worklist (`tasks.sh deviated`) that a later `/domain-model` or `/context-mapping` revision reads and clears; the shipped code departed from the spec, so the model may be wrong somewhere. **You are the only writer of the task file** — the worker returns these records in its report and never edits the file itself.
7. Recompute and continue.

## Mode A — single worker (`@1`, the default): in-place, sequential

For each batch task (batch size is 1 here), in turn:
1. Spawn **task-worker** (`subagent_type: task-worker`, `model:` per the task's complexity) with the task file path and the repo root, working on the **current checkout**. The worker does strict TDD (test first where the change has testable behavior), verifies, and commits the code via `Skill(commit)`. It returns a parser-friendly report (`ok` / `failed`, summary, commit sha).
2. On `ok`: you flip the task to `done` + `completed` and commit that status change (`Skill(commit)`). On `failed`: first try one **escalation retry** (below); if that doesn't land it, reset the task to `todo`, note the reason, and — because the worker may have left partial edits — ensure the tree is clean before continuing (the worker is instructed to leave a clean tree on failure; verify with `git status --porcelain`).

## Mode B — multiple workers (`@N`, N>1): parallel worktrees, serial integration

For a batch of up to N tasks:
1. For each batch task create an isolated worktree on a fresh branch: `git worktree add ../.dd-worktrees/task-NNNN -b task/NNNN`.
2. Spawn one **task-worker** per task **in parallel** (all in a single message), each given its worktree path + task path, each with `model:` per its task's complexity. Each worker does TDD + verify + commit **inside its own worktree/branch**, touching only its own task's files, and returns its report.
3. Await the whole batch. For each `failed` worker, try one **escalation retry** (below) in that task's worktree before writing it off. Collect which workers succeeded.
4. Delegate merge-back to the **integrator** subagent (`subagent_type: integrator`) with the list of `(task id, branch, worktree path)` for successful workers. The integrator merges each branch onto the base branch **one at a time**, and on a conflict aborts that one merge and reports it **bounced** (it never auto-resolves). It returns which task ids integrated cleanly and which bounced.
5. For integrated ids → `done` + `completed`; for bounced ids and failed workers → back to `todo` with a note. Remove the worktrees (`git worktree remove … && git branch -D task/NNNN`) for handled tasks.

Parallel implementation, serial integration, bounce-on-conflict: a bounced task is simply picked up again on a later pass (or by a `@1` run), never silently merged.

## Escalation retry

When a worker reports `RESULT: failed` and its model was **not** the top of the escalation ladder, respawn the task-worker **once** at the next tier up (same task, same working directory — the failed worker left a clean tree). This applies only to worker *failures* (a reasoning/implementation miss, possibly a mis-estimated `complexity`) — never to Mode B *bounces*, which are merge conflicts, not model problems, and gain nothing from a stronger model. If the retry lands, treat it as a normal success but record the escalation in the task's `## Notes` (e.g. `escalated: sonnet → opus on failure`) — a signal to the human that the `complexity` estimate was low. If the retry also fails, or the first attempt was already at the top tier, take the normal failure path (reset to `todo`, note why). One retry, never a loop.

## Resumability

The cycle is idempotent: every pass re-derives the ready-set from disk, so a run that stops (limit reached, stall, interruption) can be re-invoked and it picks up exactly the tasks still `todo`. A task left `in progress` by a crashed run should be reset to `todo` by the human (or note it and reset it yourself at start if the tree is clean).

## When you are done

Report the tally: tasks completed this run, any bounced/failed (and why), any stall (tasks blocked on unmet deps), and the remaining `board` counts (`bash <skills-root>/task-status/tasks.sh board`).
