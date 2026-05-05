---
name: milestone-closing
description: >
  Close out a completed milestone by documenting results, noting discrepancies, adding
  manual testing/demo steps, and preparing PLAN.md for the next cycle. Trigger whenever
  the user says "close milestone", "milestone done", "wrap up", "close it out", "phase 4",
  "finish the milestone", "we're done", or when all tasks in PLAN.md are marked complete
  and the user wants to finalize. Also trigger when the user asks to document what was
  built, write demo steps, or prepare for the next planning cycle.
model: opus
allowed-tools: Read, Write, Glob, Grep, Edit, Bash(grep *), Bash(git log:*), Bash(head:*), Bash(cargo build:*), Bash(cargo test:*), Bash(cargo clippy:*), Bash(pnpm install:*), Bash(pnpm run:*)
---

# Milestone Closing — Documentation, Verification, and Reset

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You are guiding the human through the **Milestone Closing** phase of an AI-native
milestone-driven workflow. Your job is to verify completeness, document the outcome, record
anything noteworthy, and reset `PLAN.md` for the next cycle.

## Prerequisites

- `PLAN.md` exists with tasks — ideally all marked `[x]` (done) or `[~]` (postponed).
- `ROADMAP.md` exists with the relevant milestone marked `in progress`.

## Phase Workflow

### Step 1: Completeness Check

Read `PLAN.md` and `ROADMAP.md`. Verify:

1. **All tasks resolved.** Every task should be `[x]` or `[~]`. If any are still `[ ]`,
   ask the human: "Task N is still open — should we implement it, postpone it, or drop
   it before closing?"

2. **Success criteria met.** Read the milestone's success criteria from `ROADMAP.md`
   (formatted as `- [ ]` checkboxes by `strategic-planning`). For each criterion, assess
   whether the implemented tasks collectively satisfy it, then **edit `ROADMAP.md` to
   tick the box** (`- [ ]` → `- [x]`) for every met criterion. Leave unmet criteria as
   `- [ ]` and either flag them for discussion or annotate them inline (e.g.,
   `- [ ] <criterion> — descoped, see closing notes`). Do not skip this edit: an
   unticked criterion in a "completed" milestone is a documentation bug.

3. **Postponed tasks.** For each `[~]` task, confirm the postponement reason is documented
   and ask whether it should become part of a future milestone.

If any tasks are unresolved or criteria are not fully met, discuss with the human before
proceeding.

### Step 2: Write Closing Notes to ROADMAP.md

Once all tasks are resolved, write the closing content **directly to the milestone entry
in `ROADMAP.md`**. Do not compose it in chat first — the file is the artifact.

Update the milestone's status from `in progress` to `completed` and append:

```markdown
**Status:** completed
**Completed:** <date>

**Closing Notes:**
- <Scope changes: tasks that grew, shrunk, split, or were added mid-milestone>
- <Architectural surprises: tech debt, unexpected coupling, performance issues>
- <Decision changes: original decisions revised during implementation, and why>
- <Postponed items summary: what was deferred and why>

### Manual Testing & Demo

**Prerequisites:**
- <Environment setup, seed data, config needed>

**Verification Steps:**
1. <Step to verify criterion 1>
   - Expected: <what should happen>
2. <Step to verify criterion 2>
   - Expected: <what should happen>
...

**Demo Script** (for stakeholder presentation):
1. <Start state>
2. <Action to show the new capability>
3. <Point out what changed / what's new>
```

### Step 3: Review on File

After writing to `ROADMAP.md`, tell the human the closing notes are ready for review and
point them to the file. Apply any requested changes directly to `ROADMAP.md` — keep the
feedback loop on the file, not in chat.

Ask the human to walk through the verification steps and confirm everything works.

### Step 4: Re-iterate on Deviations

If verification surfaces **deviations from the success criteria** or **missing pieces /
errors that block shippable user value**, do not proceed to reset. Instead, add one or
more tasks to `PLAN.md` so the human can re-iterate via `task-implementation`:

- Phrase each task in the same format as `milestone-breakdown` produces (`- [ ] <task>`
  with a brief description, file hints if known, and acceptance criteria).
- Group them under a heading like `## Re-iteration: <milestone title>` so they're
  distinguishable from the original breakdown.
- After tasks are added, hand back to the human: they run `task-implementation` until
  all new tasks are `[x]`, then re-invoke `milestone-closing`, which restarts at Step 1.

**If in doubt, ask the human** before adding tasks — small polish issues may be better
folded into a patch commit, while genuine scope gaps belong in PLAN.md. Borderline cases
(e.g., "is this a bug or a future enhancement?") should be surfaced explicitly rather
than silently turned into tasks or silently ignored.

Only proceed to Step 5 once verification passes cleanly with no blocking deviations.
Steps 5 and 6 must not run while deviation tasks are open — they only execute on a
clean pass through Step 4.

### Step 5: Update README.md

With the milestone verified and closed, bring `README.md` up to date so it reflects the
project's current state. Read the existing `README.md` and reconcile it against what
was actually shipped in this milestone:

- Update feature lists, capability descriptions, or status claims that are now stale.
- Add documentation for newly shipped capabilities (commands, flags, configuration,
  endpoints, etc.) where the README is the right home for them.
- Remove or rewrite sections describing behavior that was changed or replaced.
- Refresh examples, screenshots references, or quickstart steps if they no longer
  match reality.

Keep edits scoped to what changed in this milestone — do not rewrite unrelated parts of
the README. If the milestone produced no user-visible or developer-visible changes that
warrant a README update, note that explicitly to the human and skip the edit.

### Step 6: Reset PLAN.md

Truncate `PLAN.md` to prepare for the next cycle. Replace its contents with:

```markdown
# Plan

> Ready for next milestone breakdown.
> Last completed: <milestone title> (<date>)
```

This keeps a breadcrumb of what came before while making the file clean for the next
breakdown phase.

### Step 7: Hand Off

Briefly note what was delivered and suggest the user commit using `/commit`, then:
- Move to **Strategic Planning** if there's no next open milestone, or
- Move to **Break-Down** if there is one ready.

## Handling Common Situations

**Not all criteria met but human wants to close:**
This is fine — real projects have pragmatic scope cuts. Document what was descoped and
why. Suggest creating a follow-up milestone for the remaining criteria if they're still
important.

**Human discovers a bug during manual testing:**
Use Step 4's re-iteration path: add a task (or a small cluster of tasks) to `PLAN.md`
describing the bug and its acceptance criteria, then let `task-implementation` handle it
under TDD. For trivial polish (typos, copy tweaks), a direct patch is fine — but
anything that touches behavior covered by success criteria should go through a task so
it gets test coverage. If unsure whether something is a "bug now" vs. "future
enhancement", ask the human before deciding.

**Postponed tasks need a home:**
For each postponed task, help the human decide: does it belong in a future milestone?
Should it be tracked as tech debt? Or is it no longer relevant? Add appropriate notes
to `ROADMAP.md`.

## Important Principles

- **Honesty over polish.** The closing notes should be candid about what went well and
  what didn't. This history is valuable for future planning.
- **Verification is not optional.** The human must actually run through the testing steps.
  Automated tests passing is necessary but not sufficient — manual verification catches
  integration and UX issues that unit tests miss.
- **Clean break.** After closing, `PLAN.md` should be empty and ready. No leftover state
  bleeding into the next cycle.
- **Celebrate progress.** Closing a milestone is an achievement. Acknowledge what was
  built before moving on.
