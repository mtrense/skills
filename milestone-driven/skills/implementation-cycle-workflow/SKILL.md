---
name: implementation-cycle-workflow
description: >
  Workflow-backed twin of /implementation-cycle. Drives PLAN.md to completion by
  invoking the `implementation-cycle` Workflow script (one task-worker +
  doc-updater subagent per task, sequential) instead of running the loop in the
  main session. Exists so the two orchestration styles can be tested side by side.
disable-model-invocation: true
argument-hint: "[max-tasks]   (optional integer; default: run until done or blocked)"
model: sonnet
allowed-tools: Read, Bash(git status:*), Bash(git log:*), Workflow
---

# Implementation Cycle (Workflow-backed)

This is the **experimental twin** of `/implementation-cycle`. It burns down PLAN.md
the same way — one fresh subagent per task, `task-implementation` + `commit`, then a
`doc-updater` pass — but delegates the *entire loop* to a deterministic **Workflow
script** rather than driving it turn-by-turn in this session.

Use it to A/B the two styles: `/implementation-cycle` (in-session prose loop) vs
`/implementation-cycle-workflow` (scripted `agent()` loop) on the same PLAN.md, and
compare context footprint, wall-clock, and halt behavior.

**Workflow opt-in:** invoking this skill *is* the authorization to call the Workflow
tool — these instructions explicitly direct it. You do not need the user to say
"ultracode" or otherwise opt in again.

## Prerequisites

Cheap fast-fail checks before spending a Workflow run (the script's own gate repeats
them, but failing here is quicker and clearer):

1. `PLAN.md` exists with at least one `[ ]` task. If not, stop and tell the human.
2. Working tree is clean — run `git status --porcelain` (plain form, never
   `git -C <path>`). If dirty, stop and ask the human to commit or stash first.

## Arguments

`$ARGUMENTS` is optional. If it parses as a positive integer, that is the **max
number of tasks** to attempt this cycle — pass it as the Workflow `args`. Otherwise
omit `args` (the script runs until PLAN.md has no `[ ]` tasks or it halts).

## Run the workflow

Call the **Workflow** tool once. Prefer the installed-by-name form; fall back to the
in-repo script path if the name doesn't resolve (i.e. `install.sh` hasn't linked
`workflows/` into `.claude/workflows/` yet):

- Primary: `Workflow({ name: "implementation-cycle", args: <max-tasks int, or omit> })`
- Fallback: `Workflow({ scriptPath: "<this-repo>/milestone-driven/workflows/implementation-cycle.js", args: <...> })`

The Workflow runs in the background and returns a summary object when it finishes.
Do **not** re-implement the loop here, do not spawn `task-worker`/`doc-updater`
yourself, and do not read source files or run tests in this session — the whole point
is that the script owns all of that.

## Report the result

When the Workflow completes, it returns:

```
{ tasksCompleted, completed: [{title, commit, subject, docs}], halted, haltReason }
```

Turn that into a compact summary for the human:

1. Tasks completed this cycle (count + each `commit` short-hash / subject, noting any
   accompanying `docs(...)` hash).
2. Re-read `PLAN.md` and report the remaining `[ ]` count.
3. If zero `[ ]` tasks remain, suggest `/milestone-closing`.
4. If `halted` is true, surface `haltReason` verbatim — the cycle stopped there and
   will not have touched later tasks. Re-invoking after the human resolves it is safe
   (the script re-derives the next `[ ]` task from PLAN.md each run).

Do not write closing notes, do not touch ROADMAP.md, and do not commit anything
yourself — every filesystem write happened inside the Workflow's subagents.

## How this differs from `/implementation-cycle`

Same contract, different host. Two consequences worth watching when you compare:

- **Extra verification subagents.** A Workflow script has no filesystem/bash access,
  so the pre-flight clean-tree check + next-task pick (`gate`) and the independent
  post-flight check (`verify`) are done by small `general-purpose` agents instead of
  in-session git/PLAN reads. That is ~2 more subagents per task than the prose skill.
- **Structured returns replace report-block parsing.** The workers hand back
  schema-validated objects, not fenced ` ```report ` blocks — the script never parses
  text.
