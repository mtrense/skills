---
name: enrich
description: >
  Break a trajectory milestone down into well-shaped tasks: a dialog that ticks the boxes of
  the next (or given) milestone and persists tasks/NNNN-slug.md files, each with a plan,
  decision/documentation references, complexity, dependencies, acceptance criteria, and
  proves links for pending-proof decisions. Refuses to break down a milestone with unresolved
  decision or needs-proving items (routes to /decide first). Also the re-shaping entry point when /burn hands
  back an UNDERESTIMATED task. Trigger on "/enrich", "break down the milestone", "turn the
  milestone into tasks", "reshape task NNNN", or when /burn routes an underestimated task
  here. Do NOT trigger for milestone-less small tasks (that's /supplement) or milestone
  definition (that's /aim).
argument-hint: <optional milestone id, or task id to re-shape>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent, AskUserQuestion
---

# Enrich — Milestone to Well-Shaped Tasks

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — a milestone id, or a task id to re-shape (see "Re-shaping" below). If empty, take the lowest-id open milestone that has unbroken-down ground (`bash ../_shared/scripts/backlog.sh by-status milestone open`, then `backlog.sh by-milestone <id>` to see what already exists — relative paths from this skill's directory).

**A persisted task is by definition clear and well shaped.** All shaping happens *before* writing files — propose several tasks where the milestone item looks like one, merge where two items are one change — because tasks are never split after persistence; their ids stay live for their whole life.

## Gate: open decisions block breakdown

Read the milestone file. If any `## Decisions to make` **or** `## Needs proving` item is unchecked (no `decision: NNNN` back-reference), **refuse to break the milestone down** and route the items to `/decide` — a task written against an unmade decision just encodes a guess, and a needs-proving item that never became a `proof: pending` decision can't be wired into any task's `proves` list, so the obligation silently evaporates (`pending-proofs` comes back empty and `/land` finds nothing to clear). This is a hard gate; the user overriding it should be rare and explicit.

**A partial breakdown is the dangerous shape, not a compromise.** The tempting move when one item blocks one task is to mint everything else and come back later — and that is exactly how a milestone ends up with every task it has `done` while the outcome is undelivered, because a task that was never written is invisible to every status query. So if the user does override the gate, the ground the blocked item covers is **still written down** as an unresolved line in the coverage map below, and the milestone stays OPEN by construction until it is broken down. Say that plainly when overriding: *"minting N tasks now; `<element>` stays uncovered and blocks landing until the logging decision is made"*.

## The breakdown dialog

Work through the milestone's outcome with the user, proposing a breakdown into tasks. For each proposed task, assemble:

- **Plan** — concrete implementation steps, including the files to touch if possible (ground this in the actual codebase — targeted Reads/Greps or a quick scout, not guesswork).
- **References** — the relevant decisions (ids into `decisions:`) and other documentation/examples (`documents:`). Read the `documentation/<topic>.md` digests, not the full records.
- **Complexity** — `low | medium | high`, an abstract reasoning-difficulty estimate (never a model name); `/burn` dispatches its model tiers on it.
- **Dependencies** — `depends_on` edges to other tasks (existing or in this batch).
- **Acceptance criteria** — externally observable checks, one list; this is exactly what the `grader` will hold the worker to, so write them testable.
- **Proves** — for any `proof: pending` decision this task will demonstrate, its id in `proves:`. Check `backlog.sh pending-proofs` for obligations this milestone (or an earlier one) is still carrying — a task here may prove an earlier milestone's decision.

**Wire proves against the claims, not the decision.** `backlog.sh proof-claims <id>` lists a pending decision's `## Proof` claims. Walk them one at a time and name which task demonstrates each — several claims of one decision routinely land in different tasks, and the surface matters (a claim demonstrated through the library API is not demonstrated through the CLI entry point). Then state the leftovers explicitly: **any claim no proposed task covers is uncovered ground** — either a task is missing from this breakdown, or the claim belongs to a later milestone and the user should say so. Never let `proves: [NNNN]` on one task stand in for a claim list it only partly delivers; the decision stays `pending` until every claim is ticked, and `/land` will block on it.

**Duplicate/link scan:** for each proposed task, spawn the `task-linker` subagent (proposal + `backlog.sh` path). It proposes links to existing open tasks instead of duplicating them — fold its verdicts into the breakdown (drop covered tasks, add proposed edges) and surface judgment calls to the user.

**Vocabulary check:** check every task's names, terms, and acceptance criteria against `VISION.md`'s `## Vocabulary` section. A task that needs a term the vision doesn't have surfaces that gap explicitly — extend the vocabulary via a `/kickoff` revision, or fix the wording — never quietly coin a synonym.

The user reorders, vetoes, and re-scopes; nothing persists until the breakdown is agreed.

**How to ask** (see [Asking the user](../_shared/workflow-overview.md#asking-the-user)). Present the proposed breakdown as prose — a list of tasks is not a multiple choice, and the user's reordering and re-scoping needs room. Reach for `AskUserQuestion` on the closed calls that fall out of it:

- **Cut lines** — when one milestone item could reasonably be one task or several, offer the candidate splits as options (`preview` showing each split's task titles makes the comparison concrete).
- **Linker judgment calls** — per surfaced overlap: *fold into task NNNN* / *keep separate, add a `depends_on` edge* / *keep separate, unrelated*.
- **Vocabulary gaps** — *extend the vocabulary via a `/kickoff` revision* / *reword the task to an existing term* — never silently pick one.
- **Complexity** when genuinely borderline: `low` / `medium` / `high`, with the description naming what the tier buys (it is `/burn`'s model routing).

Batch related closed calls into one `AskUserQuestion` call rather than one turn each.

## Persist

Per agreed task: `bash ../_shared/scripts/backlog.sh new task <slug> <title>`, then Edit the frontmatter lists (`milestones: ["<this milestone>"]`, `complexity`, `depends_on`, `decisions`, `proves`, `documents`) and fill `## Plan`, `## Acceptance criteria`, `## Notes`.

### The coverage map

Then write the milestone's `## Breakdown` section — **one line per element of the outcome**, each resolved one of exactly two ways:

```markdown
## Breakdown
- <outcome element, in the milestone's own words> — tasks: 0009, 0012
- <outcome element> — deferred: <why, and what unblocks it>
```

Derive the elements from `## Outcome` (and any proof claim the tasks are meant to demonstrate), not from the task list — reading the tasks back would only tell you the milestone is covered by the tasks you just wrote. Then check each element against the breakdown and resolve it: covered by tasks, or deliberately deferred with the reason. **An element you cannot resolve either way stays on the list unresolved** — `milestone-ready` reads a line with neither `tasks:` nor `deferred:` as uncovered ground and holds the milestone OPEN. That unresolved line is the whole point: it is what makes a gap survive the session instead of evaporating.

On a re-run against a milestone that already has a coverage map, update the existing lines rather than appending a second map.

Then: `bash ../_shared/scripts/backlog.sh check` (hard gate — fix anything it flags). Do **not** commit — this skill runs in the foreground; name the task files written and leave them for the user to review and commit (`/commit`).

## Re-shaping an underestimated task

When `/burn` hands back an UNDERESTIMATED task (or the user names one), reshape without splitting: **narrow the original in place** — its id, dependents, and `proves` links stay live — and mint fresh tasks for the carved-off remainder, wiring their `depends_on` and moving any `proves` link the narrowed original no longer delivers. Use the worker's `learned:` report as the primary input; the same linker/vocabulary/check rigor applies (and the same no-commit rule).

## Rejection ripple

If the dialog rejects a task (the human decides not to do it): `backlog.sh set-status task <id> rejected`, then immediately `backlog.sh dependents <id>` and rewire every edge in this session — to a replacement or by dropping it (a live dependency on a rejected task fails `check`). If the task was on a decision's `proves` side, re-home the proof on another task or route the decision to `/decide`. Both rewirings are closed sets — ask them with `AskUserQuestion` (one question per dangling edge: *repoint to task NNNN* / *drop the edge*; for the proof: *re-home on task NNNN* / *route to `/decide`*), so nothing is silently chosen on the user's behalf.

## Wrap-up

Show the board, then run `bash ../_shared/scripts/backlog.sh milestone-ready <id>` and report its blockers verbatim — that is the honest statement of what this breakdown did and did not cover, and it is what `/land` will see later. Note that `/burn` can start and list what `backlog.sh ready` would pick first; if the readiness report still names uncovered elements, open items, or open proof claims, name them as the work that has to happen before landing and point at what unblocks each (`/decide` for an open item, another `/enrich` pass for uncovered ground).
