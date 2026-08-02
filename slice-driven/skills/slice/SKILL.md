---
name: slice
description: >
  Run an exploratory probe in the slice-driven workflow: build the smallest vertical slice of
  running code, on its own branch, that settles one named decision. Trigger when the user says
  "/slice", "spike this", "probe this", "let's find out with code", "settle this with a slice",
  when /work has filed a probe-type work item, or when /decide routed a challenged provisional
  decision to experimentation. Do NOT trigger for buildable features or chores — those go
  through /work and /build.
allowed-tools: Read, Glob, Grep, Edit, Write, Agent, Bash
---

# Slice — One Branch, One Session, One Decision

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You are running a probe: throwaway-grade code whose only job is to produce the evidence that settles one decision. Speed over craft — no TDD, no ceremony, subagents allowed to be sloppy. The session must end with something the user can run and judge.

## Entry contract

A slice requires a probe-type work item in `work/` whose `decision:` field names the decision it unblocks. If invoked without one:

1. Ask the user: **"What decision does this slice unblock?"** If they can answer, create the probe item (`work-new.sh probe <slug> <title>` from the `work` skill's scripts) and fill `decision:`.
2. If they can't name a decision, this is not a slice — route to `/work` (it's a feature or chore; build it for real).

**Harvest-debt gate:** before starting, check for existing probe items with status `in-progress` (`work-list.sh`). If one exists unharvested, stop — it must be closed via `/harvest` first. One open slice at a time.

## Procedure

1. **Scope check.** Restate the decision and the observation that would settle it (a number, a working interaction, a failed approach). If the slice can't plausibly produce that observation within one session, the question is too big — split it into smaller questions (new probe items) with the user and take the first.
2. **Branch.** `git checkout -b slice/NNNN-slug` (matching the work item). Record the branch in the item's `branch:` frontmatter and flip status to `in-progress` (`work-status.sh`).
3. **Seed from examples.** If the user has a concrete example — an API sketch, a file-format vision, pseudo-code — the slice's job is to *make the sketch real* so it can be judged. Paste it into the item's Examples section if not already there and build toward it directly.
4. **Build fast.** Vertical, minimal, hardcoded where possible. Cut every corner that doesn't touch the decision. Prefer running ugly code in 30 minutes over clean code in 3 hours. Commit freely on the branch; messages can be terse.
5. **Run it, together.** Demo the result — command transcript, output, benchmark numbers, screenshots. The user judges against the decision.
6. **Capture observations** in the item's `## Results` section as you go: what was tried, what happened, numbers, dead ends. Raw is fine — `/harvest` distills.

## Exit

Do not merge, do not write decisions, do not update INTENT.md — that is `/harvest`'s job and the user's fate call belongs there. End by pointing at `/harvest`. The branch stays around regardless of fate, for later inspection.
