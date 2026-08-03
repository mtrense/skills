---
name: harvest
description: >
  Close an open slice in the slice-driven workflow: make the fate call (approve / adjust /
  discard), turn observations into grounded decisions, and ratchet the learnings into
  INTENT.md, QUESTIONS.md, and the work item's Results section. Trigger when the user says
  "/harvest", "close the slice", "the slice is done", "let's harvest", or after a /slice
  session ends and the user has judged the result. Do NOT trigger for closing features or
  chores — /build handles those.
argument-hint: <optional fate call: approve | adjust | discard>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Agent, Bash
---

# Harvest — Turn a Slice into Settled Ground

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

A slice only pays off here: this is where evidence becomes recorded decisions and the spec ratchets forward. Harvest is mandatory — the workflow's harvest-debt gate blocks new slices until this runs — but it should take minutes, because it is transcription of things just seen, not invention.

The user's argument, if any: `$ARGUMENTS` — the fate call (`approve`, `adjust`, or `discard`); take it as the user's judgment in step 2 and confirm it in one line instead of asking open-ended. If empty, frame the evidence and ask.

## Procedure

1. **Locate the open probe.** Find the `in-progress` probe item (`work-list.sh`); read its `decision:`, `branch:`, and accumulated Results notes.

2. **Fate call** (the user decides, you frame the evidence):
   - **approve** — the approach validated. Merge the slice branch into main. The code now evolves under TDD: if hardening work remains (backfill tests, refactor, wire in properly), append those as tasks to the blocked feature item, or create a chore item for standalone hardening. Flip the probe to `done`.
   - **adjust** — evidence was informative but the question isn't settled. Respin: refine the probe item's plan with what was learned and return to `/slice` (same item, same or new branch). Item stays `in-progress` — the harvest-debt gate intentionally keeps this loop tight.
   - **discard** — approach refuted. That is a *successful* probe: the decision is settled negatively, with evidence. Flip to `done`, leave the branch unmerged **and un-deleted** — branches stay around for later inspection.

3. **Record decisions** via `/decide`: every call the slice settled becomes a `grounded` decision with `evidence:` pointing at the slice branch (and specific commits/numbers where relevant). If the slice contradicted an existing provisional decision, supersede it. If it contradicted a *grounded* one, this slice is the new evidence — supersede with a note.

4. **Ratchet the docs** — only what the evidence validated, nothing speculative:
   - `QUESTIONS.md`: check off answered questions (link the decision/branch); add newly discovered ones.
   - `INTENT.md` Vocabulary: terms the slice coined or made precise.
   - `INTENT.md` Invariants: only if the slice *proved* a property must hold.
   - Validated examples (the API shape that felt right, the file format that worked) get kept verbatim as exemplars — in the work item and, where broadly relevant, in INTENT.md's Examples.

5. **Fill `## Results`** in the probe item: what was tested and how, the observation that settled the decision, naming deviations from the plan, surprises, follow-up items spawned (file them via `work-new.sh`; they're born `captured` and need a `/work` pass before they can be built).

6. **Unblock and route.** If a feature was `blocked_by` this probe, clear the blocker and flip it back to actionable; refresh its Decisions touched against the new decisions. Close by showing `work-next.sh` — usually the resumed feature.
