---
name: enrich
description: >
  Break a trajectory demo down into well-shaped tasks: a dialog that turns the next (or
  given) demo's scenario into tasks/NNNN-slug.md files — the demo's executable check first,
  then the work that makes it pass — each with a plan, decision/documentation references,
  complexity, dependencies, acceptance criteria, and proves links for pending-proof
  decisions. Refuses to break down a demo with unresolved decision or needs-proving items
  (routes to /decide first). Also the entry point for a STALLED demo (red with no live task:
  reads the failing check and mints the missing work) and for re-shaping a task /burn
  handed back as UNDERESTIMATED. Trigger on "/enrich", "break down the demo", "turn the
  demo into tasks", "the demo is stalled", "reshape task NNNN", or when /burn routes an
  underestimated task here. Do NOT trigger for demo-less small tasks (that's /supplement)
  or demo definition (that's /aim).
argument-hint: <optional demo id, or task id to re-shape>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent, AskUserQuestion
---

# Enrich — Demo to Well-Shaped Tasks

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — a demo id, or a task id to re-shape (see "Re-shaping" below). If empty, run `bash ../_shared/scripts/backlog.sh demo-state` (relative to this skill's directory) and take the lowest-id demo reporting `STALLED` — a stalled demo is a gap in the running system and outranks fresh breakdown; otherwise the lowest-id red demo with no tasks yet. Demos reporting `WAITING` are skipped: they await a human verdict on another demo, not breakdown.

**A persisted task is by definition clear and well shaped.** All shaping happens *before* writing files — propose several tasks where a scenario step looks like one, merge where two steps are one change — because tasks are never split after persistence; their ids stay live for their whole life.

## Gate: open decisions block breakdown

Read the demo file. If any `## Decisions to make` **or** `## Needs proving` item is unchecked (no `decision: NNNN` back-reference), **refuse to break the demo down** and route the items to `/decide` — a task written against an unmade decision just encodes a guess, and a needs-proving item that never became a `proof: pending` decision can't be wired into any task's `proves` list, so the obligation silently evaporates. This is a hard gate; the user overriding it should be rare and explicit. When overridden, the step the blocked item covers simply gets no task yet — the demo's check will fail on it, the demo will stall once everything else lands, and the stall brings you back here. Say that plainly: *"minting N tasks now; step 3 stays unbuilt until the logging decision is made — the demo will stall there"*.

**Verdict items** (`— after: NNNN`) are the strongest form of this gate: they wait for the user to *see* demo NNNN, so the route is `/land NNNN` first, then `/decide`. Don't offer the override for them — breaking a demo down before the verdict it depends on is exactly the work this marker exists to hold back. `backlog.sh demo-state <id>` reports such a demo as **WAITING**; when invoked argless, skip it.

## The check task comes first

Every demo is built outside-in: **the first task of a fresh breakdown is the demo's check** — an end-to-end test or script that drives the scenario through the real entry point (start the binary, send the request, run the CLI) and asserts each step's observation. It is red when it lands (nothing behind it exists yet) and turns green only when the outcome really works, so the demo's status is decided by the code, never by task bookkeeping.

- Shape it like any task (plan, acceptance criteria). Its acceptance criteria: the check exists, exercises every `## Scenario` step through the real surface (not the layer beneath it), fails today for the right reason, and runs from the project root with one command.
- Name that command in the demo's frontmatter `check:` field now (e.g. `cargo test --test demo_0003`, `just demo-0003`, `./scripts/demo-0003.sh`) — before it exists, `demo-check` simply reports red.
- Keep it hermetic: ephemeral ports, temp directories, local fixtures. A check that needs the network or a fixed port will fail under a sandbox for reasons unrelated to the code.
- Its acceptance criteria name **what the check must not do**: weaken a scenario step to make it pass. Later tasks make the check pass by building the outcome, never by editing the check's expectations — a changed expectation is a scenario change, which goes through the user.
- The steps in `## Human check` are not automated — they are the human's part of `/land`.

The remaining tasks may `depends_on` the check task when they extend it, but need not: the check task is first in the breakdown, not a barrier.

## The breakdown dialog

Walk the demo's `## Scenario` step by step with the user and propose the tasks that make each step's observation come true. For each proposed task, assemble:

- **Plan** — concrete implementation steps, including the files to touch if possible (ground this in the actual codebase — targeted Reads/Greps or a quick scout, not guesswork).
- **References** — the relevant decisions (ids into `decisions:`) and other documentation/examples (`documents:`). Read the `documentation/<topic>.md` digests, not the full records.
- **Demos** — `demos: ["<this demo>"]`, plus any other demo the task plainly serves. This is a scheduling hint (`/burn` re-runs those demos' checks after merging the task, and `burn demo:<id>` scopes on it), never a definition of done.
- **Complexity** — `low | medium | high`, an abstract reasoning-difficulty estimate (never a model name); `/burn` dispatches its model tiers on it.
- **Dependencies** — `depends_on` edges to other tasks (existing or in this batch).
- **Acceptance criteria** — externally observable checks, one list; this is exactly what the `grader` will hold the worker to, so write them testable.
- **Proves** — for any `proof: pending` decision this task will demonstrate, its id in `proves:`. Check `backlog.sh pending-proofs` for obligations this demo (or an earlier one) is still carrying.

**Wire proves against the claims, not the decision.** `backlog.sh proof-claims <id>` lists a pending decision's `## Proof` claims. Walk them one at a time and name which task demonstrates each — several claims of one decision routinely land in different tasks, and the surface matters (a claim demonstrated through the library API is not demonstrated through the CLI entry point; a claim about the demo's own surface is demonstrated by its check). State the leftovers explicitly: **any claim no proposed task covers is uncovered ground** — either a task is missing from this breakdown, or the claim belongs to a later demo and the user should say so.

**Every step gets an owner.** Before persisting, go through the scenario once more and name the task(s) behind each step. A step nobody owns is fine only when the user knowingly leaves it for later — the check will keep the demo red on it, and that is the honest state.

**Duplicate/link scan:** for each proposed task, spawn the `task-linker` subagent (proposal + `backlog.sh` path). It proposes links to existing open tasks instead of duplicating them — fold its verdicts into the breakdown (drop covered tasks, add proposed edges, add this demo to an existing task's `demos`) and surface judgment calls to the user.

**Vocabulary check:** check every task's names, terms, and acceptance criteria against `VISION.md`'s `## Vocabulary` section. A task that needs a term the vision doesn't have surfaces that gap explicitly — extend the vocabulary via a `/kickoff` revision, or fix the wording — never quietly coin a synonym.

The user reorders, vetoes, and re-scopes; nothing persists until the breakdown is agreed.

**How to ask** (see [Asking the user](../_shared/workflow-overview.md#asking-the-user)). Present the proposed breakdown as prose — a list of tasks is not a multiple choice, and the user's reordering and re-scoping needs room. Reach for `AskUserQuestion` on the closed calls that fall out of it:

- **Cut lines** — when one step could reasonably be one task or several, offer the candidate splits as options (`preview` showing each split's task titles makes the comparison concrete).
- **Linker judgment calls** — per surfaced overlap: *fold into task NNNN* / *keep separate, add a `depends_on` edge* / *keep separate, unrelated*.
- **Vocabulary gaps** — *extend the vocabulary via a `/kickoff` revision* / *reword the task to an existing term* — never silently pick one.
- **Complexity** when genuinely borderline: `low` / `medium` / `high`, with the description naming what the tier buys (it is `/burn`'s model routing).

Batch related closed calls into one `AskUserQuestion` call rather than one turn each.

## Stalled demos

A demo is STALLED when it is red and no live task lists it: every known piece of work landed and the outcome still does not run. That is the gap signal — the missing work was never written down — and it is this skill's job to write it down.

1. Run `bash ../_shared/scripts/backlog.sh demo-check <id>` to get a fresh result at HEAD (the board's may be stale), then read `.trajectory/demo-<id>.log`. Find the **first failing step** and why it fails. If there is no check command or the check task was never written, the gap is the check itself — mint it (above).
2. Rule out the environment before blaming the code: a sandbox-blocked port bind, a missing network, a missing tool is not a gap in the product. Say so to the user and stop instead of minting tasks against it.
3. Diagnose in prose with the user — what is missing between the done tasks and the failing step — then shape the missing work exactly like a fresh breakdown (same gate, linker, vocabulary, proves wiring). New tasks list the demo; never reopen a done task — its record stands, the new task builds on it.
4. If the failure means the scenario itself was wrong (the expectation, not the code), that is the user's call: ask *fix the code to meet the step* / *revise the scenario step (and the check) to what we now know is right* / *drop the step from this demo*. A revised step is edited in the demo file and the check task carrying it is a new task.

## Persist

Per agreed task: `bash ../_shared/scripts/backlog.sh new task <slug> <title>`, then Edit the frontmatter lists (`demos`, `complexity`, `depends_on`, `decisions`, `proves`, `documents`) and fill `## Plan`, `## Acceptance criteria`, `## Notes`. Set the demo's `check:` field if this breakdown named the command.

Then: `bash ../_shared/scripts/backlog.sh check` (hard gate — fix anything it flags). Do **not** commit — this skill runs in the foreground; name the task files written and leave them for the user to review and commit (`/commit`).

## Re-shaping an underestimated task

When `/burn` hands back an UNDERESTIMATED task (or the user names one), reshape without splitting: **narrow the original in place** — its id, dependents, and `proves` links stay live — and mint fresh tasks for the carved-off remainder, wiring their `depends_on`, carrying the original's `demos`, and moving any `proves` link the narrowed original no longer delivers. Use the worker's `learned:` report as the primary input; the same linker/vocabulary/check rigor applies (and the same no-commit rule).

## Rejection ripple

If the dialog rejects a task (the human decides not to do it): `backlog.sh set-status task <id> rejected`, then immediately `backlog.sh dependents <id>` and rewire every edge in this session — to a replacement or by dropping it (a live dependency on a rejected task fails `check`). If the task was on a decision's `proves` side, re-home the proof on another task or route the decision to `/decide`. Both rewirings are closed sets — ask them with `AskUserQuestion` (one question per dangling edge: *repoint to task NNNN* / *drop the edge*; for the proof: *re-home on task NNNN* / *route to `/decide`*), so nothing is silently chosen on the user's behalf.

## Wrap-up

Show the board, then run `bash ../_shared/scripts/backlog.sh demo-state <id>` and report it verbatim. Note that `/burn` can start — `/burn demo:<id>` burns only what this demo needs and stops when it turns green — and list what `backlog.sh ready --demo <id>` would pick first.
