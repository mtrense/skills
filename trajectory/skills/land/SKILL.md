---
name: land
description: >
  Run the human test cycle on a green trajectory demo: re-run its check at HEAD, compose a
  verified walk-through (setup, numbered steps with expected observations, the human-only
  checks, deviations and caveats) from the demo's scenario and the closing records of the
  tasks behind it, let the user try it, turn their feedback into new tasks, clear the proof
  claims the demo now evidences after consulting the user (routing contradicted decisions to
  /decide instead of editing them), update documentation, flip the demo to shown, and
  settle the verdict items other demos were waiting on.
  Trigger on "/land", "show me the demo", "what can I test", "land the demo", "demo time",
  "is the demo ready", or when /burn reports a demo ready to show. Do NOT trigger for
  task-level completion (that's /burn's job) or for progress questions (answer with
  backlog.sh board / demo-state).
argument-hint: <optional demo id>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent, Skill, AskUserQuestion
---

# Land — The Human Test Cycle

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — a demo id. If empty, take the lowest-id green demo (`bash ../_shared/scripts/backlog.sh by-status demo green`, relative to this skill's directory); if none is green, print `backlog.sh demo-state` verbatim (what each red demo is waiting on, which are STALLED) and stop.

A demo is landed when a human has seen it work and accepted it — not when its tasks are done, and not when its check passed once. This skill is the bridge between the two: it turns a green check into something the user can actually try, then turns what the user found into new work.

## Step 1: Re-run the check

Run `backlog.sh demo-check <id>` at HEAD — the green status may be from an older commit, and the tree has moved since. Red now means the demo regressed after it turned green: report the log's first failing step, point at `/burn` (if the demo still has live tasks) or `/enrich <id>`, and stop. A demo is only ever shown green at the commit the user is looking at. The user will commit the demo file this rewrites along with the rest of this skill's changes.

## Step 2: Gather and verify the record

Read the demo file, the check log (`.trajectory/demo-<id>.log`), and the closing records — `## Manual testing` and `## Deviations` — of the `done` tasks `backlog.sh by-demo <id>` lists. Tasks that serve the demo without listing it do not appear there; the passing check is what says the outcome works, the records only explain how.

**A closing record is a claim about the code, not a substitute for it.** It was written by a worker and checked once by a grader; nothing has compared it to the tree since. For the records the walk-through will rely on — every command you are about to hand the user, every quoted output, and every record you are about to tick a proof claim against — verify before you rely on them: confirm each command still exists, and trace each quoted output literal to the code producing it (grep the exact string), or just run it. A step marked `[unverified]` was an expectation the worker could not observe, and stays one until you observe it here. A record contradicted by the code is a finding: correct it in the task file and say so in the showing record.

## Step 3: Hand over the walk-through

Compose the demo as a script the user will follow literally, and present it:

- **Setup** — what to build, start, or seed, as exact commands.
- **The scenario** — the demo's `## Scenario` steps, numbered, each with the exact command or action and the observation to expect. Where a step drives one of the demo's examples, point at the artifact path — the user tries the very bytes the spec was settled on, and may want to edit a copy to probe beyond it. Synthesis means composing verified records and the scenario into one sequence, never inventing the glue between them: a step you had to make up to connect two records is a step to run first. A wrong line costs more than a missing one.
- **Your part** — the `## Human check` items, phrased as what to look at while walking through.
- **Known caveats** — deviations from the records, `[unverified]` steps you could not observe here, scenario steps the check does not reach.

Then let the user try it. They may run it themselves or ask you to drive steps; either way, this is their test cycle.

## Step 4: Collect the feedback

Ask what they found in **prose** — what worked, what surprised them, what felt wrong. This is open discovery; options would steer it. Follow up where a finding is vague until it is concrete enough to act on (what they did, what they saw, what they expected).

Then settle each finding's disposition — closed calls, batched into one `AskUserQuestion` call where several arrive together:

- **Fix before showing** — the demo is not acceptable without it. It becomes a task listing this demo. If the finding changes an *expectation* the scenario states (or adds one the check could assert), update the `## Scenario` step and make the task extend the check too — the demo turns red again until the fix lands, which is the honest state. A finding only a human can judge stays in `## Human check`.
- **Follow-up** — worth doing, not a reason to withhold acceptance. It becomes a task serving no demo, or the next demo (name it).
- **Not a problem** — explained, or out of scope. Recorded in the showing record, nothing minted.

Shape every task a finding produces with full rigor — plan, acceptance criteria, linker scan, vocabulary check: invoke `Skill(supplement)` with the finding and, for a fix-before-showing finding, the demo id to list. A finding that contradicts an accepted decision is never just a task: route it to `/decide <id>`. A finding that changes what an example pins (the definition should look different, the CLI output should read differently) is never just a task either: revise the example via `Skill(example)` first — the check reads its bytes, so the demo turns red on the new expectation — then capture the fix as a task listing the demo. Showing never reopens a done task — its record stands, and new tasks build on it.

## Step 5: Clear the proofs (with the user)

For each `proof: pending` decision back-referenced from the demo (`decision: NNNN` markers; `backlog.sh pending-proofs` shows their proving tasks and how many claims are ticked):

- **Go claim by claim, never decision by decision.** `backlog.sh proof-claims <id>` lists the decision's `## Proof` claims. For each *open* claim, find the evidence and say which task demonstrated it **through which surface** — a claim satisfied only by a test driving the library API is not satisfied by the CLI the claim names. The demo's green check, at the commit the user just tried, is evidence for any claim about the scenario it drives. Tick the claim in the decision record (`- [x] … — demonstrated by task NNNN` / `— demonstrated by demo NNNN check at <sha>`) only when the evidence actually holds. An `[unverified]` step, or a quote you could not trace to producing code, is not evidence.
- A claim with no evidence is uncovered ground, not a formality: name it, and either leave it open for a later demo (say which) or capture the missing work (Step 4's fix-before-showing route).
- **Consult the user** — the flip is theirs: present the per-claim evidence in prose, then ask per pending proof (options: *proven — flip it* / *not yet — keep it pending* / *contradicted — route to `/decide`*). Several pending proofs go in one call, one question each. On approval: `backlog.sh set-proof <id> proven` (it refuses while any claim is unticked — that refusal is a finding, not an obstacle to route around with `--force`), and tick the demo's needs-proving item.
- **Contradicting evidence** — do not edit the decision; route to `/decide <id>` for revision or supersession. The proof stays `pending` on the old record until that resolves.

Proofs never decide whether the demo is shown — a demo can be accepted with a claim still open, and the claim stays visible on the board.

## Step 6: Documentation and the showing record

Update project documentation where the demonstrated result (as opposed to any single task — `doc-syncer` already handled those) makes it stale: overview docs, getting-started flows, the README's "what works" story. Engage in dialog if unsure whether a doc should change — where that reduces to "which of these docs did this demo make stale?", ask it as one `AskUserQuestion` with `multiSelect` over the candidates. Leave `documentation/<topic>.md` digests to the `decision-summarizer` (they only move when decisions move).

Fill the demo's `## Showing` section (append a dated block when the demo is shown more than once):

- The commit it was shown at and the verdict.
- **How to run it** — the verified walk-through from Step 3, as it stood.
- Human check results, and each finding with its disposition and the task ids it produced.
- Deviations from what the demo originally described (scope adjustments, naming drift, surprises) — recorded, never laundered; contradictions with decisions routed to `/decide`.
- Proof clearances, and claims left open.

## Step 7: Disposition

Settle the demo itself with `AskUserQuestion`:

- **Shown** — accepted: `backlog.sh set-status demo <id> shown`. Valid only when there are no fix-before-showing findings (the script refuses a non-green demo, and a fix that extended the check has already turned it red at the next check).
- **Not yet** — fix-before-showing tasks were captured; the demo stays as it is and comes back to `/land` once `/burn demo:<id>` has landed them (a green demo with live tasks is burned until they are done).
- **Drop** — the demo is abandoned: `backlog.sh set-status demo <id> dropped`, and ripple its live tasks (`backlog.sh by-demo <id>`): reject, re-point to another demo, or keep as plain tasks — one closed question per task.

## Step 8: Settle the verdicts other demos wait on

Run `backlog.sh waiting-on <id>`: the verdict items (`— after: <id>`) other demos hold open until this one was seen. They exist because a later demo builds on what the user thinks of this one — and the user has just formed that judgment, so this is the cheapest moment to record it.

- **Shown** — for each item, ask (one `AskUserQuestion`, one question per item): *decide it now* (recommended — invoke `Skill(decide)` with the item; it grounds the dialog in the `## Showing` record you just wrote) / *later* (the item is decidable from now on; `/decide` argless will pick it up). Each verdict settled here unblocks `/enrich` for the waiting demo.
- **Dropped** — the verdict will never come. Per item: *decide it without the verdict* (remove the `after:` marker, then `/decide`) / *re-point it to another demo* (edit the marker) / *drop the item* (and say whether the waiting demo still makes sense — it may need `/aim` re-shaping or dropping too).
- **Not yet** — nothing to settle; the waiting demos keep waiting.

## Wrap-up

Run `bash ../_shared/scripts/backlog.sh check`. Do **not** commit — this skill runs in the foreground; name every file touched (demo file, decision files, task files, docs) and leave them for the user to review and commit (`/commit`). Show the board and point forward: the next green demo, `/burn demo:<id>` for captured fixes, `/enrich` for a demo this showing unblocked, or `/aim` for the next demo when the runway is clear.
