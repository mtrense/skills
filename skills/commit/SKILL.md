---
name: commit
description: >
  Analyse staged and unstaged changes, craft a meaningful commit message, and commit.
  Trigger whenever the user says "commit", "save this", "commit changes", or asks to
  commit after completing a workflow phase. Also trigger when another skill suggests
  committing. This skill is the single point of committing in the workflow — no other
  skill commits directly.
model: sonnet
---

# Commit — Analyse Changes and Craft a Meaningful Commit

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You are responsible for the **only** commit step in the engineering workflow. No other
skill commits directly — they all defer to you.

## Workflow

### Step 1: Gather Context

1. Run `git status` to see all staged and unstaged changes.
2. Run `git diff` (staged and unstaged) to understand what changed.
3. Read `ROADMAP.md` and `PLAN.md` if they exist, to understand the current milestone
   and task context.

If there are no changes to commit, tell the user and stop.

### Step 2: Analyse the Changes

Determine the nature of the changes:

- **Which workflow phase produced them?** Look for signals:
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
- `roadmap:` — milestone added or updated in `ROADMAP.md`
- `plan:` — task breakdown written to `PLAN.md`
- `feat:` — new feature or capability (implementation phase)
- `fix:` — bug fix
- `test:` — test-only changes
- `refactor:` — code restructuring without behavior change
- `milestone:` — milestone closing
- `chore:` — tooling, config, or maintenance

If the task in `PLAN.md` specifies a commit message, use it as the basis but adjust if
the actual changes diverged from the plan.

The summary line should be under 72 characters. The body (if needed) should explain
*why*, not *what* — the diff already shows what changed.

### Step 4: Present for Approval

Show the user:
- The list of files that will be committed
- Any files you recommend excluding (with reasons)
- The proposed commit message

Ask: "Ready to commit, or would you like to adjust anything?"

### Step 5: Commit

Once approved:

1. Stage the appropriate files (be specific — avoid `git add -A` unless all changes
   are intentional).
2. Commit with the approved message.
3. Report the commit hash and summary.

If relevant, suggest the next workflow step:
- After a roadmap commit → "Ready for breakdown when you are."
- After a plan commit → "Ready for implementation when you are."
- After a task commit → "N tasks remaining." (if applicable)
- After a milestone close → "Ready for the next planning cycle."

## Important Principles

- **Never commit without showing the user what will be committed.** The user reviews
  the diff and the message before anything is committed.
- **Be specific when staging.** Stage files by name, not with blanket `git add .`.
- **Respect `.gitignore`.** Don't override it.
- **One logical change per commit.** If the changes span multiple unrelated concerns,
  suggest splitting into separate commits.
- **The message matters.** A good commit message makes `git log` useful months later.
  Take the time to get it right.
