---
name: work
description: >
  Single entry point of the slice-driven workflow: take any change request, idea, improvement,
  or outcome description, triage it (chore / feature / probe), and shape it into a work item
  under work/. Trigger whenever the user says "/work", "new work item", "I want to add…",
  "here's an idea", "change request", "shape this", "let's plan this change", or hands over
  any description of something the project should do or become. Also trigger when the user
  pastes an example, API sketch, or file-format vision and asks to turn it into work. Do NOT
  trigger for pure questions about existing work items ("what's next?", "list work") — answer
  those directly with the scripts.
argument-hint: <optional change description, idea, or pasted example>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Agent, Bash
---

# Work — Triage and Shape a Change

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — the incoming change description (prose, an idea, or a pasted example/sketch); start triage from it directly. If empty, ask what change the user wants to shape.

You are the single gate through which every change enters a slice-driven project. Your job: triage the incoming description, then shape it into a filed work item — cheaply. Shaping takes minutes, not days; anything that would take longer is a sign you're settling questions that only code can settle.

## Prerequisites

`INTENT.md` should exist (run `/intent` first on a fresh project). If it doesn't and the user wants to proceed anyway, note that invariants/vocabulary grounding is unavailable and continue.

## Step 1: Triage

Type the incoming change with one question: **"Could this just be built and judged, or is there a decision that can't be made without evidence?"**

- **chore** — no unknown at all (e.g. "add structured logging to the server"). Mechanical, however large.
- **feature** — outcome known, path mostly known (e.g. "when started with `--admin <port>`, the server opens a local admin API"). The default type.
- **probe** — a *named decision* is blocked and can't be grounded without running code, AND being wrong about it would be expensive to reverse. If the user can't name the decision it unblocks, it is not a probe — it's a feature or chore.

Bias deliberately toward **feature/chore**: uncertainty alone doesn't earn a probe; cheap-to-reverse calls get a provisional decision (via `/decide`) and real code. State your triage call in one sentence and let the user veto it.

## Step 2: Ground against settled decisions

Before shaping, spawn the `decision-briefer` subagent with the change description and the subsystems it touches. It returns the decisions that constrain this work. **Never re-ask what a grounded decision already settles** — this is the workflow's re-litigation guard. If the change as described cuts against a grounded decision, surface that now: the user either adjusts the change or brings evidence to reopen (route through `/decide`).

For anything beyond a trivial chore, also spawn the `work-scout` subagent for codebase reconnaissance (relevant files, conventions, risks) so the breakdown is implementation-aware. Skip the scout for chores whose touchpoints are obvious.

## Step 3: Shape (dialogue, kept short)

Create the item first so there's always a file: run `scripts/work-new.sh <type> <slug> <title>` (from this skill's directory) and then fill the body via Edit. Sharpen **only what's needed to build**:

- **Outcome** — one or two sentences, the user's words tightened.
- **Examples** — if the user supplied sketches (API shapes, file formats, CLI transcripts, pseudo-code), paste them **verbatim** as the leading artifact; they outrank prose. Examples are first-class: a concrete example is often the best possible shaping input.
- **Evidence of done** — externally observable checks, checkbox list.
- **Decisions touched** — existing decisions this relies on (from the lookup), plus any new calls made during shaping. Every new call goes through `/decide` as `provisional` — shaping never grounds anything.
- **Tasks** (features only) — an ordered markdown checkbox list (`- [ ] …`, one task per line; `/build` ticks each to `- [x]` and stamps its commit SHA as it lands), each task independently testable and sized for one TDD session, **walking-skeleton first**: task 1 always produces something runnable end-to-end, however thin. Co-edit with the user; they reorder and veto. Chores get a task list only if genuinely multi-step.
- **Results** — leave empty; `/build` and `/harvest` fill it.

**When an ungroundable question surfaces mid-shaping**, offer exactly two exits: (a) decide provisionally via `/decide` and move on, or (b) if expensive-to-be-wrong, create a probe item scoped to exactly that decision (`work-new.sh probe …`, set the feature's `blocked_by` to the probe's id) and point the user at `/slice`. Never let the dialogue debate an ungroundable question — that is the failure mode this workflow exists to kill.

## Step 4: File and stop

For probes triaged at step 1: fill `decision:` in the frontmatter with the decision the probe unblocks, keep the Tasks section to the probe plan (what to build, what observation settles the decision), and point the user at `/slice`.

Shaping and building are decoupled — do **not** start building. Queuing several `/work` items before any `/build` is normal. Close by showing `scripts/work-list.sh` output and, if relevant, noting which item `scripts/work-next.sh` would pick.

## Staleness rule

Nothing shaped here is permanent: decisions made during shaping are provisional, and `/build` re-checks an item's Decisions touched against the current decision log when it picks the item up. Keep shaping cheap accordingly — a stale item is cheap to refresh, not a sunk cost.
