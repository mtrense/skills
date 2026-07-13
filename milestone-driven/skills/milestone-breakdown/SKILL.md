---
name: milestone-breakdown
description: >
  Break down the next open milestone from ROADMAP.md into small, actionable, independently
  testable tasks in PLAN.md. Trigger whenever the user says "break down", "plan tasks",
  "create tasks", "task breakdown", "decompose milestone", "phase 2", "let's break this
  down", references PLAN.md in a planning context, or asks to prepare for implementation.
  Also trigger when the user has just finished strategic planning and wants to move to the
  next phase. This skill reads the codebase and docs to produce implementation-aware tasks
  with architectural hints, test cases, and file associations.
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Agent
---

# Milestone Breakdown — Decomposing into Actionable Tasks

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You are guiding the human through the **Break-Down** phase of an AI-native milestone-driven
workflow. Your job is to turn the next open milestone from `ROADMAP.md` into a concrete,
ordered list of tasks in `PLAN.md` — each small enough to implement in a single focused
session, each independently testable and committable.

## Prerequisites

1. `ROADMAP.md` (the index) must exist with at least one milestone whose status is `open`.
   The full content of each milestone lives in `roadmap/NNNN-slug.md`.
2. `PLAN.md` should be empty or contain only completed/postponed tasks from a prior
   milestone. If it has uncompleted tasks, confirm with the user before overwriting.

## Phase Workflow

### Step 1: Select the Milestone

Read the `ROADMAP.md` index and identify the next `[open]` milestone. If multiple are
open, approach the next one in order of writing (lowest number). Open its
`roadmap/NNNN-slug.md` file to read the full milestone content. Update the status to
`in progress` in **both** places: the `[open]` → `[in progress]` marker on the index line
and the `**Status:**` field in the milestone file.

### Step 2: Codebase Reconnaissance — Delegate to `milestone-scout`

Before writing any tasks, you need a structured picture of the part of the
codebase the milestone touches: relevant files, conventions to match, test
posture, risks. **Delegate this discovery to the `milestone-scout` subagent**
rather than reading the codebase yourself — that keeps your opus session
focused on synthesis instead of file paging.

Spawn the scout with `subagent_type: milestone-scout` and a self-contained
prompt:

```
Milestone (verbatim from roadmap/NNNN-slug.md):

<paste the full milestone block — title, value/impact, outcome, success
criteria, notes>

Repo root: <absolute path, or "current working directory">

Hint: <if a top-level CODEBASE.md or specific <module>/CODEBASE.md is
relevant, name it; otherwise omit this line>

Follow your standard report format.
```

The scout returns a structured report covering:
- **Orientation** — language, framework, layout shape, dominant conventions.
- **Relevant files** — capped at ~20, each with a one-line "why".
- **Conventions to match** — tests, code organization, error handling,
  logging, config, async — each cited to a concrete file.
- **Risks** — tech debt, fragile coupling, missing coverage, migration
  implications.
- **Preparatory work suggestions** — things that ought to happen before the
  main tasks. These are *suggestions*; you decide whether they make it into
  PLAN.md.
- **Sources used** and **tooling notes** (so you know the report's accuracy
  ceiling).

If the scout subagent isn't available in this environment, fall back to
reading the codebase yourself: project root layout (`Glob`), key affected
files, README/ARCHITECTURE/CONTRIBUTING docs, and existing test conventions.
Note the same categories the scout would have produced.

**Consult prior architectural decisions too.** In parallel with the scout,
spawn the `decision-lookup` subagent (`subagent_type: decision-lookup`) with the
milestone's title and the subsystems it touches. It locates and reads the project's
decision index (`decisions/INDEX.md` by default, or the `decision-path:` directory set
in `CLAUDE.md`),
pulls only the relevant records, and returns a compact briefing of the decisions
that constrain how this milestone should be built — so you inherit them without
paging the whole decision log into your opus session. If it reports no log exists,
proceed normally. Fold any binding decision it returns into the tasks' **Architecture
& Decisions** notes, and if the milestone as scoped would cut against an `Accepted`
decision, raise that with the human before writing the plan.

After the scout returns: if anything about the milestone's scope is unclear
or contradicts what the scout found, ask the human now, before writing. Keep
clarification questions focused and minimal. Once open questions are
resolved, move directly to writing the plan.

### Step 3: Write PLAN.md

**Write the plan to `PLAN.md` immediately** after resolving any open questions. Do not
present the plan in chat first — the file is the artifact. Follow the format in the
appendix at the end of this document.

**Task sizing rules:**
- Each task should be implementable within roughly 50% of the available context window.
  In practice this means: a task should touch at most 3–5 files and produce at most
  ~200 lines of new/changed code plus tests.
- If a task feels too large, split it. Prefer more small tasks over fewer large ones.
- Each task must be independently committable — the codebase should pass all tests after
  each task is completed.

**Ordering rules:**
- Order tasks so that each builds on the previous.
- Put foundational work (types, schemas, interfaces) before implementation.
- Put tests alongside their implementation task, not as separate tasks (TDD is handled
  in the implementation phase).
- End with integration, wiring, and polish tasks.

**Cross-cutting concerns** — include a section at the end of the plan:

```markdown
## Cross-Cutting Concerns

- **Security:** <any auth, input validation, secrets management notes>
- **Performance:** <any known performance constraints or targets>
- **Observability:** <logging, metrics, alerting expectations>
- **Migration:** <data migration steps if applicable>
- **Rollback:** <how to safely revert if something goes wrong>
```

### Step 4: Record Architectural Splits

Most per-task choices belong in a task's **Architecture & Decisions** notes and nowhere
else — that field exists precisely so small, local decisions stay local. But breaking a
milestone down occasionally forces a **milestone-level architectural split**: a fork that
shapes many tasks at once and would be expensive to reverse — introducing a new service
boundary, choosing a persistence model for a whole feature, committing to a protocol or a
cross-cutting pattern the rest of the work must honour. When the breakdown lands such a
split, record it as an ADR so the reasoning survives past this planning session.

Record one only when the decision **splits the architecture across tasks or commits to a
direction that is costly to undo** — not for ordinary per-task choices. For each that
clears the bar, read `references/decision-record.md` and follow it. Records live in
`<decisions-dir>/` — `decisions/` by default, or the directory named by a `decision-path:
<directory>` line in `CLAUDE.md`. Number the record,
write `<decisions-dir>/NNNN-kebab-title.md`, and append the one-sentence entry to
`<decisions-dir>/INDEX.md`. Reference the record from the affected tasks' **Architecture &
Decisions** notes (e.g. "per ADR 0007") so the implementer follows it. If the split would
contradict a decision the Step 2 `decision-lookup` briefing surfaced, flag it to the
human rather than silently overriding — that is a superseding decision and their call.

### Step 5: Review on File

After writing `PLAN.md`, tell the human the plan is ready for review and point them to
the file (note any decision records you wrote). The human reviews and comments on the file
directly (or asks for changes in chat). Iterate by editing `PLAN.md` until the human approves.

### Step 6: Hand Off

Once approved:

1. Present a brief summary and suggest the user commit using `/commit`.
2. Suggest they move to the **Implementation** phase when ready.

## Important Principles

- **Implementation-aware, not implementation-dictating.** Provide enough architectural
  context that the implementer (which may be a different Claude model or the human
  themselves) can make good decisions, but don't write pseudocode or dictate exact
  implementations.
- **Test cases are first-class.** Every task must have test cases described. These become
  the starting point for TDD in the implementation phase.
- **One task, one commit.** If a task can't be meaningfully committed on its own, it's
  either too small (merge it) or entangled with another task (restructure).
- **File associations matter.** Listing the files a task will touch helps the implementer
  scope their work and helps the reviewer know what to check.
- **Surface unknowns.** If during codebase assessment you discover something that could
  affect the milestone (tech debt, missing tests, fragile code), flag it as a risk or
  add a preparatory task.

---

## Appendix: PLAN.md Format Reference

# Plan: <Milestone Title>

> Milestone: roadmap/NNNN-slug.md
> Started: <date>

## Tasks

[x] 1. Example finished task
- **Files:** `path/to/file.ts`, `path/to/file.test.ts`
- **Description:** <What this task accomplishes, written so that an implementer with
  access to the codebase but no other context can execute it>
- **Architecture & Decisions:**
  - <Pattern to follow, e.g. "Use the existing Repository pattern from `src/repos/`">
  - <Key decision, e.g. "Store as JSON column, not a separate table — scope is small">
- **Non-Functional Considerations:**
  - <Security, performance, accessibility, compliance notes if any>
- **Test Cases:**
  - <Test 1: description of what to test and expected outcome>
  - <Test 2: ...>
  - <Edge case or error scenario>
- **Commit Message:** `<conventional commit message for this task>`

[ ] 2. Example unfinished task
