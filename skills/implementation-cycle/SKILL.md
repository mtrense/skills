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

Use the `Agent` tool with `subagent_type: task-worker`. The subagent's full
contract — invoke `task-implementation`, then `commit`, return a fenced
`report` block, halt instead of pushing through ambiguity — lives in
`agents/task-worker.md`. Your prompt only needs to name the task and pass any
context the worker can't infer from PLAN.md itself.

Use this template:

```
The next [ ] task in PLAN.md is: "<TASK TITLE>"

Run your standard contract: invoke `task-implementation`, then `commit`, then
return your report block. Halt instead of asking questions — the orchestrator
will surface anything you halt on.
```

Run the Agent call **synchronously** — do not use `run_in_background`. Wait for
its result before continuing.

If the `task-worker` subagent isn't available in this environment (e.g.,
`agents/` wasn't installed), fall back to `subagent_type: general-purpose` and
inline the contract from `agents/task-worker.md` into the prompt. This is a
fallback, not the default — running on `task-worker` keeps the contract in one
place.

### Step 4: Post-flight Check

After the subagent returns, verify in order. Any failure → halt the loop.

1. **Report block present and well-formed.** The subagent's final message must
   end with a fenced ` ```report ` block. If the block is missing or malformed,
   halt with reason `subagent omitted required report block`. Do not infer
   success from a clean tree alone — a missing report is itself the bug.
2. **Subagent didn't report HALTED.** If the report block is the HALTED variant,
   halt the loop and surface the reason verbatim.
3. **Commit line present and valid.** The success report must contain a line
   matching `^Commit: [0-9a-f]{7,40} `. If absent, halt with reason
   `subagent skipped commit step` — even if PLAN.md was updated and tests pass.
   Do not auto-recover by spawning a commit-only subagent; hand back to the human.
4. **PLAN.md moved.** Re-read PLAN.md. The task you sent in must now be `[x]`
   (or `[~]` if the subagent legitimately postponed it and reported so). If it's
   still `[ ]`, halt.
5. **Tree is clean.** Run `git status --porcelain`. If it's not clean, the commit
   step didn't fire (or fired only partially). Halt.
6. **Commit hash exists.** Run `git log -1 --format=%H` and confirm it matches
   (by prefix) the hash from the report. If not, the subagent fabricated or
   misreported the hash — halt.
7. **Cap not yet hit.** If `$ARGUMENTS` specified a max and you've reached it, exit.

If all checks pass, log a one-line progress note for the human (e.g.
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
