---
name: build
description: >
  Execute shaped work items from the slice-driven workflow under strict TDD: pick the next
  actionable item (or a named one), burn down its tasks with per-task subagents, and fill its
  Results section. Trigger when the user says "/build", "build the next item", "work on item
  N", "implement <work item>", "continue building", or after /work when the user says to go
  ahead and build. Do NOT trigger for probe-type items — those run through /slice.
argument-hint: <optional work item id or name>
allowed-tools: Read, Glob, Grep, Edit, Write, Agent, Bash, Skill
---

# Build — TDD Burn-Down of a Work Item

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You drive one work item from `shaped` to `done` with production discipline: tests first, small steps, honest results. This is where approved slices get hardened and features get real.

## Step 1: Pick the item

The user's argument, if any: `$ARGUMENTS` — a work item id or name; use that item. No argument → run `work-next.sh` (from `_shared/scripts/` next to the skills) and take its pick, announcing which item you're building — don't ask. If the picked item is a probe, redirect to `/slice`. Flip status to `in-progress` (`work-status.sh`).

**Dirty-tree check:** this skill commits after every task, and those commits sweep the working tree. If `git status` shows uncommitted changes unrelated to this item at start, surface them and let the user commit or stash first — don't silently fold their work into a task commit.

**Baseline SHA:** record where this build starts from — `git rev-parse --short HEAD` — as the first line under `## Results` (`baseline: <sha>`). Reverting the whole item is then a reset to that SHA. If the item already has a baseline from an earlier partial run, keep it and add this run's as a new line.

## Step 2: Staleness check

Items may have been shaped long before being built. Spawn `decision-briefer` with the item's summary and its Decisions touched list. If any decision the item relies on has been superseded or contradicted since shaping, surface the mismatch and refresh the item with the user (usually a 2-minute fix) before writing code. Never build against a superseded decision.

## Step 3: Burn down tasks

Work the `## Tasks` checklist strictly in order — walking skeleton first; the unticked `- [ ]` entries are the worklist, so a re-entered `/build` resumes exactly where the last one stopped. For each task, spawn a `build-worker` subagent with a self-contained prompt: the task text, the item's Outcome and Examples, relevant Evidence-of-done checks, binding decisions from step 2, and conventions/files from any prior scout report. The worker follows strict TDD (failing test → minimal code → refactor) and reports what it did, test evidence, and any deviations. Workers never commit — landing is the `task-lander`'s job (below).

After each task, land it as one commit — verification and the commit are delegated so the test output, commit playbook, and full diff never enter this session:

1. **Tick** the task's checkbox (`- [ ]` → `- [x]`) in the work item and append a one-line note under `## Results`, so the item update is in the tree when the lander commits.
2. **Spawn `task-lander`** with the task text, the worker's report, the work item path, and the project's test command(s). The lander independently re-runs the tests, checks the diff for weakened/gamed tests and the tree for unrelated changes, commits via `Skill(commit)` (code, tests, and the updated work item together — one self-contained commit per task, so the history reads as the burn-down), and returns the short SHA. Never fold this into the worker — the lander must be a separate agent from the one that implemented the task, or the verification is the worker grading itself.
3. **On `landed`**: append the returned SHA to the ticked task line — `- [x] <task text> — <sha>` — so each task points at the commit that reverts it. This stamp lands with the *next* commit (the following task's, or the closing bookkeeping commit) — never amend for it. Surface any lander `flags` to the user.
4. **On `failed`**: revert the tick and Results note, show the lander's evidence, and either re-spawn the worker with the failure or stop and ask — never commit around a red suite.

If a task turns out to hide an ungroundable decision, stop — offer the provisional-`/decide` vs probe fork exactly as `/work` does; don't let the worker guess silently.

Chores without a task list are executed directly as a single TDD pass, sized permitting, and landed the same way (one `task-lander` pass) when green — stamp that commit's short SHA on the `## Results` note.

## Step 4: Close the item

When all tasks and Evidence-of-done checks pass:

1. **Fill `## Results`** properly: how it was tested (test suites, manual checks, transcripts), naming deviations from the shaped plan (renamed concepts, moved boundaries), surprises, and follow-up items spawned (file them via `work-new.sh` as chores/features so they aren't lost — they're born `captured`, i.e. filed but unshaped, and stay that way until a `/work` pass shapes them; state the spawning context in their `## Outcome` so that pass has something to work from).
2. **Light harvest** — folded in here, not a ceremony: new vocabulary → INTENT.md Vocabulary; provisional decisions this build exercised with real code → note them in the decision records as grounding candidates (actual re-tiering goes through `/decide`); validated examples → keep as exemplars.
3. Flip status to `done`, then spawn `task-lander` in **closing mode** to commit the closing edits (Results, harvest notes, status flip, the last task's SHA stamp) — it runs the full suite once as the final gate before this bookkeeping-only commit. Show `work-next.sh` for what's next.

Report outcomes faithfully: failing tests are reported as failing, skipped checks as skipped. An item never flips to `done` with unmet Evidence-of-done checks — park it `blocked` with a Results note instead.
