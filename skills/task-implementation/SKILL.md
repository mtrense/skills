---
name: task-implementation
description: >
  Implement the next unfinished task from PLAN.md using strict test-driven development.
  Writes tests first, then writes just enough code to make them pass, and prepares the
  result for human review and commit. Operates at the individual task level — one task
  per invocation.
model: sonnet
disable-model-invocation: true
allowed-tools: Read, Write, Glob, Grep, Edit, Bash(grep *), Bash(git status:*), Bash(cargo build:*), Bash(cargo test:*), Bash(cargo clippy:*), Bash(pnpm install:*), Bash(pnpm run:*), Bash(mkdir:*)
---

# Task Implementation — Strict TDD, One Task at a Time

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You are guiding the human through the **Implementation** phase of an AI-native engineering
workflow. You implement exactly one task from `PLAN.md` per invocation, using strict
test-driven development: tests first, then just enough code to pass them.

## Prerequisites

1. The git working tree must be clean (no uncommitted changes). Run `git status --porcelain`
   to check (plain form — do not use `git -C <path> status`, which bypasses the
   Claude Code permission allowlist and triggers a permission prompt). If the tree is
   dirty, stop immediately and ask the human to commit or stash their changes before
   proceeding.
2. `PLAN.md` must exist with at least one task marked `todo`.

## Phase Workflow

### Step 1: Identify the Task

Read `PLAN.md`. Find the first task with status `todo`, unless the user specifies
a different task by number or name.

Display the task briefly (title, files, test cases) and proceed directly to
implementation. Any adjustments should have been made to `PLAN.md` before invoking
this skill.

### Step 2: Understand the Context

Read all files listed in the task's **Files** section. Also read:
- Any files imported by those files (one level deep)
- The existing test files in the same directories
- Any configuration files relevant to the testing framework

Build a mental model of:
- How existing code is structured and styled
- What testing patterns and assertions are used
- What utilities, fixtures, or test helpers exist
- The naming conventions for files, functions, variables, and tests

### Step 3: Write the Tests FIRST

This is the core TDD discipline. Before writing any production code:

1. Create or open the test file(s) for this task.
2. Write test cases as described in the task's **Test Cases** section.
3. Include both happy-path tests and edge-case/error tests.
4. Follow the existing test conventions you observed in Step 2.

**Test quality guidelines:**
- Each test should test exactly one behavior.
- Test names should describe the expected behavior, not the implementation.
- Use descriptive assertion messages where the framework supports them.
- Set up test fixtures/data clearly at the top of each test.
- Clean up any side effects (especially for integration tests).

After writing the tests, run them. They should **fail** — this confirms they're testing
something meaningful and that you haven't accidentally written tautological tests.

Show the human the test file(s) and the failing test output, then proceed directly
to writing the implementation.

### Step 4: Write Just Enough Code

Implement the minimum code required to make all tests pass. Follow these principles:

- **Match existing patterns.** If the codebase uses a specific error handling pattern,
  repository pattern, or module structure — follow it. Don't introduce new patterns
  unless the task explicitly calls for it.
- **No speculative code.** Don't add features, parameters, or abstractions not required
  by the tests. If it's not tested, it shouldn't exist.
- **Respect the architecture decisions** listed in the task's plan entry.
- **Handle the non-functional concerns** noted in the task (security checks, input
  validation, logging, etc.).

Run the tests after implementation. If any fail, fix the implementation (not the tests,
unless the test itself has a bug). Iterate until all tests pass.

### Step 5: Verify and Polish

Once tests pass:

1. **Run the full test suite** (not just the new tests) to check for regressions.
2. **Run linting/formatting** if the project has configured linters.
3. **Review your own changes** — look for:
   - Unused imports
   - Debugging artifacts (console.log, print statements)
   - Hardcoded values that should be configurable
   - Missing error handling on the boundaries
4. Fix any issues found.

Show the human a summary:
- Which files were created or modified
- Test results (all passing, including count)
- Any lint warnings
- Anything you noticed that's worth discussing

### Step 6: Update Plan and Hand Off

Once verification passes:

1. Update `PLAN.md`: change the task's status from `[ ]` to `[x]`.
2. Present a summary of all changes, noting any judgment calls or points worth reviewing.
3. Suggest the user commit using `/commit`.
4. If there are remaining `[ ]` tasks, mention how many are left.

## Handling Common Situations

**Tests reveal a design problem:**
If writing tests exposes an issue with the task's design (e.g., the interface doesn't
make sense, or a dependency is missing), stop and discuss with the human. Propose a
modification to the task or the plan. Don't silently deviate from the plan.

**Task is larger than expected:**
If during implementation you realize the task exceeds the ~50% context window guideline,
stop and propose splitting it. Suggest a natural seam and ask the human to approve the
split before continuing.

**Existing tests break:**
If the full test suite reveals a regression, fix it if the fix is small and obvious.
If it's non-trivial, flag it to the human and discuss whether to fix it in this task
or create a new task.

**Postponing a task:**
If the human decides to skip a task, mark it as `[~]` in `PLAN.md` with a brief note
explaining why. Move to the next `[ ]` task.

## Important Principles

- **Tests first, always.** Never write production code before the test that demands it.
  This isn't a guideline — it's the core discipline of this phase.
- **One task, one commit.** Each task produces exactly one atomic, meaningful commit.
- **Match the codebase.** Your code should look like it was written by the same team that
  wrote the rest of the project. Adapt to their style, not yours.
- **The plan is the contract.** Implement what the plan says. If the plan is wrong, change
  the plan first (with the human's approval), then implement the change.
- **Show your work.** The human should see failing tests before passing tests. This builds
  trust and catches misunderstandings early.
