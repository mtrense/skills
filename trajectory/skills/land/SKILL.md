---
name: land
description: >
  Land a trajectory milestone: take the next milestone whose tasks are all done (or the one
  given), check the outcome against the milestone's original goal, persist deviations and
  oddities in the milestone file, describe how the result can be tested and demoed, update
  documentation from the tasks' closing records, and clear the milestone's proof: pending
  decisions after consulting the user — routing contradicted decisions to /decide instead of
  editing them. Trigger on "/land", "land the milestone", "close the milestone", "is the
  milestone done", "milestone landing". Do NOT trigger for task-level completion (that's
  /burn's job) or for progress questions (answer with backlog.sh board / milestone-ready).
argument-hint: <optional milestone id>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent, AskUserQuestion
---

# Land — Verify, Record, Clear the Proofs

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — a milestone id. If empty, run `bash ../_shared/scripts/backlog.sh milestone-ready` (relative to this skill's directory) and take the lowest-id milestone reporting `READY`; if none is ready, report each open milestone's blockers verbatim and stop.

**Cross-milestone proof is the one deliberate synchronization point milestones have.** A milestone whose tasks are all done but whose remaining proof lives in a later milestone's task is reported as exactly that — `blocked on proof: task NNNN (milestone MMMM)` (the helper prints this) — rather than looking stuck. Don't work around it; name it and stop.

## Step 1: Gather the record

Confirm readiness (`backlog.sh milestone-ready <id>`). Then read the milestone file, and the closing records — `## Manual testing` and `## Deviations` — of exactly the ids `backlog.sh by-milestone <id>` lists that are `done`. These records were written once by `/burn` when each task landed; a task shared with an already-landed milestone is read here, never re-processed. Rejected tasks in the list are part of the story: note what was deliberately not done.

## Step 2: Check against the original goal

Compare what landed against the milestone's `## Outcome` — the original goal, not a drifted memory of it:

- **Compliant** — the outcome is delivered as stated.
- **Deviations and oddities** — departures the closing records carry (scope adjustments, naming drift, surprises). Persist them in the milestone file; deviations are recorded, never laundered.
- **Contradictions** — a deviation that contradicts an existing decision is **never just recorded**: route it to `/decide <id>` so the decision is revised or superseded, keeping the decision log truthful. The landing waits on that dialog or explicitly notes it as open.

If the outcome is materially not delivered despite all tasks being done, that is a shaping failure worth naming: name the gap in prose, then settle it with `AskUserQuestion` — *land with the gap recorded* / *reopen via `/enrich`* (new tasks against the same milestone) / *revise the milestone's outcome to what was actually built*. The diagnosis is open work; the disposition is a closed set, and it is the user's call.

## Step 3: Clear the proofs (with the user)

For each `proof: pending` decision back-referenced from the milestone (`decision: NNNN` markers; `backlog.sh pending-proofs` shows their proving tasks):

- Present the evidence: the proving task(s), their closing records, what was demonstrated.
- **Consult the user** — the flip is theirs to approve, and this is exactly what `AskUserQuestion` is for: present the evidence in prose, then ask per pending proof (options: *proven — flip it* / *not yet — the evidence is thin, keep it pending* / *contradicted — route to `/decide`*). Several pending proofs go in one call, one question each. On approval: `backlog.sh set-proof <id> proven`, and tick the milestone's proving item.
- **Contradicting evidence** — the proving task showed the decision wrong or shaky: do not edit the decision; route to `/decide <id>` for revision or supersession. The proof stays `pending` on the old record until that resolves.

## Step 4: Documentation and the landing record

Take the outcomes of all tasks and update project documentation where the composed result (as opposed to any single task — `doc-syncer` already handled those) makes it stale: overview docs, architecture notes, getting-started flows. Engage in dialog if unsure whether a doc should change — where that reduces to "which of these docs did this milestone make stale?", ask it as one `AskUserQuestion` with `multiSelect` over the candidates instead of a doc-by-doc prose round-trip. See [Asking the user](../_shared/workflow-overview.md#asking-the-user). Leave `documentation/<topic>.md` digests to the `decision-summarizer` (they only move when decisions move).

Fill the milestone's `## Landing` section:

- Goal compliance (met / met-with-deviations) and the persisted deviations/oddities.
- **How to test and demo the outcome** — a concrete walk-through synthesized from the tasks' `## Manual testing` records: setup, numbered steps, expected observations.
- Proof clearances (which decisions flipped to proven) and anything routed to `/decide`.

Flip the milestone: `backlog.sh set-status milestone <id> landed`.

## Wrap-up

Run `bash ../_shared/scripts/backlog.sh check`. Do **not** commit — this skill runs in the foreground; name every backlog file touched (milestone file, decision files, task files, docs) and leave them for the user to review and commit (`/commit`). Show the board and point forward: the next READY milestone, or `/aim` when the runway is clear.
