---
name: commit
description: >
  Analyse staged and unstaged changes, craft a meaningful commit message, and commit.
  Trigger whenever the user says "commit", "create a commit", "make a commit", "commit
  these changes", "commit the work", "commit and push", "/commit", or otherwise asks to
  persist current git changes. Also trigger after any workflow skill completes (e.g.
  task-implementation, milestone-closing, milestone-breakdown, strategic-planning,
  project-inception, research-investigation, research-refine, codebase-survey-module,
  codebase-derive-instructions) and the user signals readiness to commit (e.g. "looks
  good, commit it", "ship it", "save this"). This is the ONLY commit point across all
  workflows — every other skill defers commit creation to this skill. Do NOT trigger
  for purely exploratory git questions ("what's changed?", "show me the diff") that do
  not request a commit.
argument-hint: Optional guidance on what to commit or how to slice changes
model: sonnet
allowed-tools: Bash(git status *), Bash(git diff *), Bash(git add *), Bash(git commit *), Bash(git log *), Bash(git rm *), Bash(git init *), Bash(echo *), Read, Glob
---

# Commit — Analyse Changes and Craft a Meaningful Commit

You are responsible for the **only** commit step across all workflows (engineering,
research, codebase-survey, ad-hoc). No other skill commits directly — they all defer
to you.

## Workflow

### Step 0: User Guidance

The user may provide free-text guidance: `$ARGUMENTS`

When provided, use this to decide **which changes to include** and **how to slice them**
(e.g. "only the tests", "split config from implementation", "everything in src/").
When empty, commit all related changes as a single logical commit.

### Step 1: Gather Context

1. Run `git status` to see all staged and unstaged changes.
2. Run `git diff --staged` to check for already-staged files.
3. If there **are** staged files, those represent the user's explicit intent — **only
   operate on the staged changes**. Skip unstaged files entirely.
4. If there are **no** staged files, run `git diff` (unstaged) and consider all
   modifications as candidates.
5. Read `ROADMAP.md` and `PLAN.md` if they exist, to understand the current milestone
   and task context.

If there are no changes matching the guidance (or no changes at all), tell the user and stop.

### Step 2: Analyse the Changes

Determine the nature of the changes:

- **Which workflow phase produced them?** Look for signals:
  - Foundational files created (`README.md`, `CLAUDE.md`, `INDEX.md`, etc.) in a
    new or nearly empty project → inception phase
  - Only `ROADMAP.md` changed → strategic planning phase
  - `PLAN.md` written/rewritten + `ROADMAP.md` status update → breakdown phase
  - Source code + test files + `PLAN.md` task status update → implementation phase
  - `ROADMAP.md` completion + `PLAN.md` reset → milestone closing phase
  - None of the above → ad-hoc change

- **What's the scope?** List the files changed and summarize the purpose of each change.

- **Is anything suspicious?** Flag files that probably shouldn't be committed:
  - `.env`, credentials, secrets, API keys
  - Build artifacts, `node_modules/`, `__pycache__/`
  - Large binary files
  - Unrelated changes that may have been accidentally staged

### Step 3: Craft the Commit Message

Write a commit message following conventional commit format:

```
<type>(<scope>): <short summary>

<optional body — what changed and why>
```

**Type selection:**
- `init:` — project inception (initial project structure and foundational files)
- `roadmap:` — milestone added or updated in `ROADMAP.md`
- `plan:` — task breakdown written to `PLAN.md`
- `feat:` — new feature or capability (implementation phase)
- `fix:` — bug fix
- `test:` — test-only changes
- `refactor:` — code restructuring without behavior change
- `milestone:` — milestone closing
- `improve:` — enhancement or refinement to existing functionality
- `chore:` — tooling, config, or maintenance

If the task in `PLAN.md` specifies a commit message, use it as the basis but adjust if
the actual changes diverged from the plan.

The summary line should be under 72 characters. The body (if needed) should explain
*why*, not *what* — the diff already shows what changed.

### Step 4: Commit

1. If files were already staged, commit exactly those — do not add or remove anything
   from the index. If no files were staged, stage the appropriate files by name (avoid
   `git add -A`). Exclude any suspicious files identified in Step 2.
2. Commit with the crafted message.
3. Report the commit hash, summary, and list of files committed.

If relevant, suggest the next workflow step:
- After a roadmap commit → "Ready for breakdown when you are."
- After a plan commit → "Ready for implementation when you are."
- After a task commit → "N tasks remaining." (if applicable)
- After a milestone close → "Ready for the next planning cycle."

## Important Principles

- **Commit immediately — do not ask for approval.** The user can always amend or
  revert if needed. Stopping to ask defeats the purpose of the skill.
- **Respect the user's staging.** If files are already staged, treat that as the
  user's explicit selection — commit only those files, ignoring unstaged changes.
- **Be specific when staging.** Stage files by name, not with blanket `git add .`.
- **Respect `.gitignore`.** Don't override it.
- **One logical change per commit.** If the changes span multiple unrelated concerns,
  suggest splitting into separate commits.
- **The message matters.** A good commit message makes `git log` useful months later.
  Take the time to get it right.
- **Never use `git -C`.** Always run git commands from the current working directory.
  The `-C` flag breaks Claude Code's permission system.
