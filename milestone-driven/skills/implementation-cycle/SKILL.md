---
name: implementation-cycle
description: >
  Drive PLAN.md to completion by running task-implementation + commit in a fresh
  subagent per task, sequentially.
disable-model-invocation: true
argument-hint: "[max-tasks]   (optional integer; default: run until done or blocked)"
model: sonnet
allowed-tools: Read, Edit, Glob, Grep, Agent, Bash(git status:*), Bash(git log:*), Skill(task-implementation), Skill(commit)
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
`milestone-driven/agents/task-worker.md`. Your prompt only needs to name the task
and pass any context the worker can't infer from PLAN.md itself.

Use this template:

```
The next [ ] task in PLAN.md is: "<TASK TITLE>"

Run your standard contract: invoke `task-implementation`, then `commit`, then
return your report block. Halt instead of asking questions — the orchestrator
will surface anything you halt on.
```

Run the Agent call **synchronously** — do not use `run_in_background`. Wait for
its result before continuing.

If the `task-worker` subagent isn't available in this environment (e.g., the
milestone-driven workflow's `agents/` wasn't installed), fall back to
`subagent_type: general-purpose` and inline the contract from
`milestone-driven/agents/task-worker.md` into the prompt. This is a fallback, not
the default — running on `task-worker` keeps the contract in one place.

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
`✓ Task 3/8 done — feat(parser): handle nested groups (a1b2c3d)`) and proceed to
Step 4.5 before looping back to Step 1.

When you halt mid-loop, the cycle is over for this invocation. Do not retry
inside the same run.

### Step 4.5: Sync Documentation

Now that the task's code commit has landed cleanly, spawn a documentation worker
to keep reference docs and examples in step with what just changed. Use the
`Agent` tool with `subagent_type: doc-updater`. Its full contract — inspect the
single task commit, update docs/examples **only** if the change is user- or
developer-visible, `commit` them as a separate `docs(...)` commit, otherwise no-op
— lives in `milestone-driven/agents/doc-updater.md`.

Use this template:

```
The task just completed is: "<TASK TITLE>"
Its commit hash is: <HASH FROM THE task-worker REPORT>

Run your standard contract: inspect that commit's diff, update reference docs and
examples only if the change is surface-visible, commit them separately, and return
your report block. Default to NO-CHANGES for internal-only changes.
```

Run this Agent call **synchronously**, like the task-worker call. Then:

1. **Report block present.** The worker's final message must end with a fenced
   ` ```report ` block (the UPDATED, NO-CHANGES, or HALTED variant). If it's
   missing, note it and move on — do not halt the whole cycle for a doc-worker
   reporting glitch.
2. **Tree is clean.** Run `git status --porcelain`. The worker either committed
   its doc edits or made none — either way the tree must be clean before the next
   iteration's pre-flight. If it's dirty, halt the loop and surface it: stray
   uncommitted doc edits would corrupt the next task's pre-flight check.
3. **Doc-worker HALTED is non-fatal.** Unlike `task-worker`, a `doc-updater` halt
   does not kill the cycle — the code already landed. Log the halt reason for the
   human and continue to Step 1. Documentation drift is recoverable at
   `/milestone-closing`.

Fold the doc outcome into the progress note, e.g.
`✓ Task 3/8 done — feat(parser): handle nested groups (a1b2c3d) · docs(e4f5g6h)`
or `· docs: none`.

If the `doc-updater` subagent isn't available in this environment, skip Step 4.5
with a one-line note to the human (the milestone's `/milestone-closing` README
pass will reconcile docs at the end) and continue the loop.

### Step 5: Final Summary

When the loop ends — clean exit, cap hit, or halt — print a compact summary:

- Tasks completed this cycle (count + commit hashes / one-line subjects), noting
  any accompanying `docs(...)` commits from Step 4.5
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
