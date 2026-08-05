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

Compare what landed against the milestone's `## Outcome` — the original goal, not a drifted memory of it — using the `## Breakdown` coverage map as the checklist. Take each element of the outcome and ask what actually demonstrates it: an element whose tasks are `done` is *claimed* covered, not *shown* covered, and a `deferred:` line is ground the milestone knowingly does not deliver (say so in the landing record rather than letting it pass as met). Where the outcome names a user-facing surface — a command, an endpoint, a screen — check the closing records show that surface working, not only the layer beneath it.

**A closing record is a claim about the code, not a substitute for it.** It was written by a worker and checked once by a grader; nothing has compared it to the tree since, and the tree has moved (merges, later tasks, doc syncs). So for the records that carry this landing — the ones demonstrating a named surface, and the ones you are about to tick a proof claim against — verify before you rely on them: confirm each command still exists, and trace each quoted output literal to the code producing it (grep the exact string), or just run it. A step marked `[unverified]` was an expectation the worker could not observe, and stays one until you observe it here. A record contradicted by the code is a finding, not a formatting problem: correct it in the task file, say so in the landing record, and treat the underlying element as *not shown* until something actually shows it — a record quoting output that was never what shipped is the failure mode where every task is `done`, every record reads convincing, and the outcome is not there.

- **Compliant** — the outcome is delivered as stated.
- **Deviations and oddities** — departures the closing records carry (scope adjustments, naming drift, surprises). Persist them in the milestone file; deviations are recorded, never laundered.
- **Contradictions** — a deviation that contradicts an existing decision is **never just recorded**: route it to `/decide <id>` so the decision is revised or superseded, keeping the decision log truthful. The landing waits on that dialog or explicitly notes it as open.

If the outcome is materially not delivered despite all tasks being done, that is a shaping failure worth naming: name the gap in prose, then settle it with `AskUserQuestion` — *land with the gap recorded* / *reopen via `/enrich`* (new tasks against the same milestone) / *revise the milestone's outcome to what was actually built*. The diagnosis is open work; the disposition is a closed set, and it is the user's call.

## Step 3: Clear the proofs (with the user)

For each `proof: pending` decision back-referenced from the milestone (`decision: NNNN` markers; `backlog.sh pending-proofs` shows their proving tasks and how many claims are ticked):

- **Go claim by claim, never decision by decision.** `backlog.sh proof-claims <id>` lists the decision's `## Proof` claims. For each *open* claim, find the evidence in the closing records and say which task demonstrated it **through which surface** — a claim satisfied only by a test driving the library API is not satisfied by the CLI the claim names. Tick the claim in the decision record (`- [x] … — demonstrated by task NNNN`) only when the evidence actually holds — which means the record's account of that surface survived the verification above. An `[unverified]` step, or a quote you could not trace to producing code, is not evidence a claim was demonstrated; run it here or leave the claim open.
- A claim with no evidence is uncovered ground, not a formality: it means no task delivered that part of the decision. Name it, and treat it as a gap for the disposition question in Step 2 (reopen via `/enrich`) rather than waving it through — this is the failure mode where every task is `done` and the outcome still isn't there.
- **Consult the user** — the flip is theirs to approve, and this is exactly what `AskUserQuestion` is for: present the per-claim evidence in prose, then ask per pending proof (options: *proven — flip it* / *not yet — the evidence is thin, keep it pending* / *contradicted — route to `/decide`*). Several pending proofs go in one call, one question each. On approval: `backlog.sh set-proof <id> proven` (it refuses while any claim is unticked — that refusal is a finding, not an obstacle to route around with `--force`), and tick the milestone's proving item.
- **Contradicting evidence** — the proving task showed the decision wrong or shaky: do not edit the decision; route to `/decide <id>` for revision or supersession. The proof stays `pending` on the old record until that resolves.

## Step 4: Documentation and the landing record

Take the outcomes of all tasks and update project documentation where the composed result (as opposed to any single task — `doc-syncer` already handled those) makes it stale: overview docs, architecture notes, getting-started flows. Engage in dialog if unsure whether a doc should change — where that reduces to "which of these docs did this milestone make stale?", ask it as one `AskUserQuestion` with `multiSelect` over the candidates instead of a doc-by-doc prose round-trip. See [Asking the user](../_shared/workflow-overview.md#asking-the-user). Leave `documentation/<topic>.md` digests to the `decision-summarizer` (they only move when decisions move).

Fill the milestone's `## Landing` section:

- Goal compliance (met / met-with-deviations) and the persisted deviations/oddities.
- **How to test and demo the outcome** — a concrete walk-through synthesized from the tasks' `## Manual testing` records: setup, numbered steps, expected observations. Synthesis means composing verified records into one sequence, never inventing the glue between them: a step you had to make up to connect two records is a step to run first. The user will follow this script literally, and a wrong line in it costs more than a missing one.
- Proof clearances (which decisions flipped to proven) and anything routed to `/decide`.

Flip the milestone: `backlog.sh set-status milestone <id> landed`.

## Wrap-up

Run `bash ../_shared/scripts/backlog.sh check`. Do **not** commit — this skill runs in the foreground; name every backlog file touched (milestone file, decision files, task files, docs) and leave them for the user to review and commit (`/commit`). Show the board and point forward: the next READY milestone, or `/aim` when the runway is clear.
