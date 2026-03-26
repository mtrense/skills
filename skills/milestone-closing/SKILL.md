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
---

# Milestone Closing — Documentation, Verification, and Reset

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You are guiding the human through the **Milestone Closing** phase of an AI-native
engineering workflow. Your job is to verify completeness, document the outcome, record
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

2. **Success criteria met.** Read the milestone's success criteria from `ROADMAP.md`.
   For each criterion, assess whether the implemented tasks collectively satisfy it.
   Present a checklist:

   ```
   Success Criteria Assessment:
   - [x] Criterion 1 — satisfied by tasks 2, 3
   - [x] Criterion 2 — satisfied by task 5
   - [ ] Criterion 3 — partially addressed, see notes
   ```

   If any criteria are not fully met, discuss with the human: is this acceptable, or
   does it need more work?

3. **Postponed tasks.** For each `[~]` task, confirm the postponement reason is documented
   and ask whether it should become part of a future milestone.

### Step 2: Discrepancy and Discovery Notes

During implementation, things rarely go exactly as planned. Document what diverged:

- **Scope changes:** Did any tasks grow, shrink, split, or get added mid-milestone?
- **Architectural surprises:** Did you discover tech debt, unexpected coupling, or
  performance issues that weren't anticipated?
- **Decision changes:** Were any of the original architectural decisions revised during
  implementation? Why?
- **Postponed work:** Summarize what was deferred and why.

Present these notes to the human for review. They'll be appended to the milestone entry
in `ROADMAP.md`.

### Step 3: Manual Testing and Demo Steps

Write a section documenting how to manually verify and demonstrate the milestone's
outcomes. This serves two purposes: immediate verification and future reference.

```markdown
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

Ask the human to actually walk through these steps and confirm everything works. If
anything doesn't work, flag it — this may require going back to implementation.

### Step 4: Update ROADMAP.md

Once the human confirms the milestone is complete:

Append the following to the milestone entry in `ROADMAP.md`:

```markdown
**Status:** completed
**Completed:** <date>

**Closing Notes:**
- <Discrepancy and discovery notes from Step 2>
- <Postponed items summary>
- <Any other observations>

**Verification:**
<Manual testing and demo steps from Step 3>
```

Update the milestone's status from `in progress` to `completed`.

### Step 5: Reset PLAN.md

Truncate `PLAN.md` to prepare for the next cycle. Replace its contents with:

```markdown
# Plan

> Ready for next milestone breakdown.
> Last completed: <milestone title> (<date>)
```

This keeps a breadcrumb of what came before while making the file clean for the next
breakdown phase.

### Step 6: Present Summary and Hand Off

Present a summary to the human:

- What was delivered
- What was postponed (if anything)
- How many milestones remain open in `ROADMAP.md`

Suggest the user commit using `/commit`, then:
- Move to **Strategic Planning** if there's no next open milestone, or
- Move to **Break-Down** if there is one ready.

## Handling Common Situations

**Not all criteria met but human wants to close:**
This is fine — real projects have pragmatic scope cuts. Document what was descoped and
why. Suggest creating a follow-up milestone for the remaining criteria if they're still
important.

**Human discovers a bug during manual testing:**
If it's small, fix it and add it as a patch commit. If it's significant, discuss whether
to reopen the milestone or create a new one.

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
