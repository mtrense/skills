---
name: implementation-cycle
description: >
  Drive PLAN.md to completion by running task-implementation + commit in a fresh
  subagent per task, sequentially.
disable-model-invocation: true
argument-hint: "[max-tasks]   (optional integer; default: run until done or blocked)"
model: sonnet
allowed-tools: Read, Edit, Glob, Grep, Agent, Bash(git status:*), Bash(git log:*)
---

# Implementation Cycle — Sequential Subagents Over PLAN.md

You are the orchestrator for a loop that drives PLAN.md to completion by spawning
**one fresh subagent per task**. Each subagent runs `task-implementation` followed
by `commit` and then exits. You stay in the main session, lightly, just to manage
the loop and decide when to stop.

The motivation is **context hygiene**, not speed. The full implementation transcript
(reading source files, running tests, iterating on errors) lives inside each
subagent and is discarded when the subagent returns. Only a short summary lands
in your context. That keeps the human's main session lean even after dozens of
tasks.

## Prerequisites

1. `PLAN.md` exists with at least one `[ ]` task. If not, stop and tell the human.
2. Working tree is clean. Run `git status --porcelain` (plain form — never
   `git -C <path>`, which bypasses the Claude Code permission allowlist). If the
   tree is dirty, stop and ask the human to commit or stash before running the cycle.

## Arguments

`$ARGUMENTS` is optional. If it parses as a positive integer, treat it as the
**maximum number of tasks** to attempt this cycle. Otherwise, run until PLAN.md
has no `[ ]` tasks left or a halt condition fires.

## Loop

Repeat the following until a stop condition triggers:

### Step 1: Pick the Next Task

Read `PLAN.md`. Find the first task whose checkbox is `[ ]`. Capture its title
and a one-line summary — you'll feed these to the subagent and use them when
verifying progress afterwards.

If no `[ ]` task remains, exit the loop (success path → Step 5).

### Step 2: Pre-flight Check

Before each subagent, run `git status --porcelain`. The tree **must** be clean.
If it isn't (the previous commit didn't happen, or stray files appeared), stop
the loop and report the dirty state to the human. Do not try to clean up
yourself — that's the human's call.

### Step 3: Spawn a Subagent

Use the `Agent` tool with `subagent_type: general-purpose`. The subagent's prompt
must be self-contained — it has none of your conversation context. Use this
template (substitute the task title; keep everything else verbatim):

```
You are a worker spawned by the implementation-cycle orchestrator. Your job is
to run TWO skills in sequence on the current repository, then exit.

The next [ ] task in PLAN.md is: "<TASK TITLE>"

Step A — invoke `task-implementation`:
  Call Skill(skill="task-implementation"). It will:
    - Read PLAN.md and identify the same task.
    - Write tests first (strict TDD), then implementation.
    - Run the test suite and verify it's green.
    - Update PLAN.md, flipping the task from [ ] to [x].
  task-implementation will NOT commit — that's Step B.

Step B — invoke `commit`:
  Call Skill(skill="commit"). It will analyse the staged/unstaged changes and
  create a single conventional commit.

When both succeed, report back in this exact shape (≤ 6 lines, no preamble):
  Task: <title>
  Tests: <pass/fail summary, e.g. "42 passing, 0 failing">
  Commit: <hash> <subject line>
  Remaining: <count of [ ] tasks left in PLAN.md after this run>
  Notes: <one short line, or "—" if nothing notable>

HALT INSTEAD OF PUSHING THROUGH if any of these happen:
  - The working tree is already dirty when you start.
  - task-implementation surfaces a design problem, scope split, or any condition
    that asks for human input rather than continuing on its own.
  - Tests cannot be made green inside this task's scope.
  - The commit step refuses or aborts (suspicious files, no changes, etc.).
  - Anything else that would normally cause you to ask the human a question.

When you halt, report:
  HALTED
  Reason: <one or two sentences>
  State: <what's on disk — uncommitted changes? failing tests? unmodified PLAN.md?>

Do not loop. Do not attempt the next task. Run exactly the two skills above
(or fewer, if you halt) and exit.
```

Run the Agent call **synchronously** — do not use `run_in_background`. Wait for
its result before continuing.

### Step 4: Post-flight Check

After the subagent returns, verify:

1. **PLAN.md moved.** Re-read PLAN.md. The task you sent in must now be `[x]`
   (or `[~]` if the subagent legitimately postponed it and reported so). If it's
   still `[ ]`, something went wrong — halt the loop.
2. **Tree is clean.** Run `git status --porcelain`. If it's not clean, the commit
   step didn't fire (or fired only partially). Halt the loop.
3. **Subagent didn't report HALTED.** If it did, halt the loop and surface the
   reason verbatim.
4. **Cap not yet hit.** If `$ARGUMENTS` specified a max and you've reached it, exit.

If all four checks pass, log a one-line progress note for the human (e.g.
`✓ Task 3/8 done — feat(parser): handle nested groups (a1b2c3d)`) and loop back
to Step 1.

When you halt mid-loop, the cycle is over for this invocation. Do not retry
inside the same run.

### Step 5: Final Summary

When the loop ends — clean exit, cap hit, or halt — print a compact summary:

- Tasks completed this cycle (count + commit hashes / one-line subjects)
- Tasks remaining in PLAN.md (count)
- Whether the milestone now has zero `[ ]` tasks (if so, suggest `/milestone-closing`)
- The halt reason, if any

Do not write closing notes, do not touch ROADMAP.md, do not commit anything
yourself. Your only writes to the file system happen via the subagents.

## Important Principles

- **Sequential, not parallel.** One subagent at a time. Tasks usually depend on
  each other; running them concurrently would scramble PLAN.md and the git index.
- **Context hygiene is the point.** The orchestrator should stay tiny. Don't
  read source files, don't run tests, don't analyse diffs in the main session —
  that's what the subagents are for.
- **Trust the subagent's halt.** If a subagent halts, do not "try again" or
  "fix it up." Halt the loop and hand control back to the human. Re-invoking
  the cycle later is cheap; pushing through a halt is how plans get corrupted.
- **One task = one commit.** The commit is part of the subagent's job, not the
  orchestrator's. Never run `git commit` or `git add` from this skill.
- **Verify between iterations.** PLAN.md and git state are the source of truth.
  Read them between every subagent. The subagent's self-report is a hint, not
  the ground truth.
