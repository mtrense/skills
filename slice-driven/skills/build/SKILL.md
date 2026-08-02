---
name: build
description: >
  Execute shaped work items from the slice-driven workflow under strict TDD: pick the next
  actionable item (or a named one), burn down its tasks with per-task subagents, and fill its
  Results section. Trigger when the user says "/build", "build the next item", "work on item
  N", "implement <work item>", "continue building", or after /work when the user says to go
  ahead and build. Do NOT trigger for probe-type items — those run through /slice.
allowed-tools: Read, Glob, Grep, Edit, Write, Agent, Bash
---

# Build — TDD Burn-Down of a Work Item

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You drive one work item from `shaped` to `done` with production discipline: tests first, small steps, honest results. This is where approved slices get hardened and features get real.

## Step 1: Pick the item

No argument → run `work-next.sh` (from the `work` skill's scripts) and confirm the pick with the user. Named item → use it. If it's a probe, redirect to `/slice`. Flip status to `in-progress` (`work-status.sh`).

## Step 2: Staleness check

Items may have been shaped long before being built. Spawn `decision-briefer` with the item's summary and its Decisions touched list. If any decision the item relies on has been superseded or contradicted since shaping, surface the mismatch and refresh the item with the user (usually a 2-minute fix) before writing code. Never build against a superseded decision.

## Step 3: Burn down tasks

Work the `## Tasks` checklist strictly in order — walking skeleton first. For each task, spawn a `build-worker` subagent with a self-contained prompt: the task text, the item's Outcome and Examples, relevant Evidence-of-done checks, binding decisions from step 2, and conventions/files from any prior scout report. The worker follows strict TDD (failing test → minimal code → refactor) and reports what it did, test evidence, and any deviations.

After each task: verify the worker's claims (run the tests yourself), tick the checkbox, and append a one-line note under `## Results`. If a task turns out to hide an ungroundable decision, stop — offer the provisional-`/decide` vs probe fork exactly as `/work` does; don't let the worker guess silently.

Chores without a task list are executed directly as a single TDD pass, sized permitting.

## Step 4: Close the item

When all tasks and Evidence-of-done checks pass:

1. **Fill `## Results`** properly: how it was tested (test suites, manual checks, transcripts), naming deviations from the shaped plan (renamed concepts, moved boundaries), surprises, and follow-up items spawned (file them via `work-new.sh` as chores/features so they aren't lost).
2. **Light harvest** — folded in here, not a ceremony: new vocabulary → INTENT.md Vocabulary; provisional decisions this build exercised with real code → note them in the decision records as grounding candidates (actual re-tiering goes through `/decide`); validated examples → keep as exemplars.
3. Flip status to `done`. Suggest `/commit` if the user's commit skill is present, then show `work-next.sh` for what's next.

Report outcomes faithfully: failing tests are reported as failing, skipped checks as skipped. An item never flips to `done` with unmet Evidence-of-done checks — park it `blocked` with a Results note instead.
