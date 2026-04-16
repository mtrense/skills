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
allowed-tools: Read, Glob, Grep, Edit, Write
---

# Milestone Breakdown — Decomposing into Actionable Tasks

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You are guiding the human through the **Break-Down** phase of an AI-native engineering
workflow. Your job is to turn the next open milestone from `ROADMAP.md` into a concrete,
ordered list of tasks in `PLAN.md` — each small enough to implement in a single focused
session, each independently testable and committable.

## Prerequisites

1. `ROADMAP.md` must exist with at least one milestone with status `open`.
2. `PLAN.md` should be empty or contain only completed/postponed tasks from a prior
   milestone. If it has uncompleted tasks, confirm with the user before overwriting.

## Phase Workflow

### Step 1: Select the Milestone

Read `ROADMAP.md` and identify the next `open` milestone. If multiple are open, approach the next one in order of writing. Update its status to `in progress`.

### Step 2: Deep Codebase Assessment

Before writing any tasks, thoroughly understand the current state:

**Read project structure.** Use `Glob` and `Read` tool on the project root directory to understand
the layout. Identify source directories, test directories, config files, and documentation.

**Read key files.** Based on the milestone's scope, read the files most likely to be
affected. Focus on:
- Entry points and public APIs
- Data models and schemas
- Existing test structure and conventions
- Configuration and environment setup
- CI/CD pipeline if visible

**Read project documentation.** Check README.md, ARCHITECTURE.md, CONTRIBUTING.md, or
any docs/ directory for conventions, patterns, and constraints.

**Identify patterns.** Note the project's:
- Testing framework and conventions (Jest, pytest, etc.)
- Code organization patterns (feature folders, layered, etc.)
- Error handling approach
- Logging and observability patterns
- Authentication/authorization patterns if relevant

If anything is unclear or ambiguous about the milestone's scope — ask the human now,
before writing. Keep clarification questions focused and minimal. Once open questions are
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

### Step 4: Review on File

After writing `PLAN.md`, tell the human the plan is ready for review and point them to
the file. The human reviews and comments on the file directly (or asks for changes in
chat). Iterate by editing `PLAN.md` until the human approves.

### Step 5: Hand Off

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

> Milestone: <link or reference to the ROADMAP.md entry>
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
