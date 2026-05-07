---
name: pr
description: >
  Create or update a GitHub pull request for the current branch using `gh`. Synthesises
  a What/Why/How description from the branch's commits and diff, adds a test plan when
  code changed, surfaces deviations reviewers should know about, and links any issues
  referenced in commits. Trigger whenever the user says "create PR", "open PR", "make
  a PR", "open a pull request", "update PR", "submit PR", "ship it as PR", "PR this",
  or `/pr`. Also trigger after `/commit` when the user signals readiness to ship (e.g.
  "now open a PR", "let's get this reviewed"). Do NOT trigger for exploratory questions
  ("what's the PR status?", "show me the PR") that don't request creation or update.
argument-hint: "[final] [base=<branch>] [free-form guidance]"
model: sonnet
allowed-tools: Bash(git status *), Bash(git diff *), Bash(git log *), Bash(git push *), Bash(git fetch *), Bash(git rev-parse *), Bash(git branch *), Bash(git merge-base *), Bash(git symbolic-ref *), Bash(gh pr *), Bash(gh repo view *), Bash(gh issue view *), Bash(gh auth status *), Read, Write, Glob
---

# PR — Create or Update a GitHub Pull Request for the Current Branch

You are responsible for shipping the current branch as a GitHub pull request — either
creating one if none exists, or updating the existing one. The description follows the
**What / Why / How** structure, with a test plan when code changed and a notes section
for deviations reviewers should be aware of.

This skill is orthogonal to `/commit`. It assumes the working tree is clean. If it is
not, refuse and tell the user to run `/commit` first.

## Workflow

### Step 0: Parse Arguments

The user may pass `$ARGUMENTS`. Recognise:

- `final` — open as a regular PR. **Default is draft.**
- `base=<branch>` — override the base branch (e.g. `base=develop`).
- Anything else — treat as free-form guidance for shaping the description (e.g.
  "focus on the migration risk", "this is a partial fix").

### Step 1: Preflight

Run these checks in parallel and stop early if any fails:

1. `git status --short` — the tree must be clean. If there are staged or unstaged
   changes, **refuse** and tell the user: *"There are uncommitted changes. Run `/commit`
   first, then re-run `/pr`."* Do not attempt to commit on the user's behalf.
2. `git symbolic-ref --short HEAD` — confirm we're on a branch. If we're on `main`,
   `master`, or detached HEAD, refuse: *"PRs can't be opened from `<branch>`. Switch
   to a feature branch first."*
3. `gh auth status` — confirm `gh` is authenticated. If not, surface the error and
   stop.
4. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` — capture the
   repo's default branch. Use this as the base unless `base=<branch>` was passed.

### Step 2: Detect Existing PR

Run `gh pr view --json number,state,title,body,isDraft,baseRefName,url` (this targets
the current branch by default).

- **No PR yet** → proceed to Step 3 and create one.
- **PR exists, state OPEN** → proceed to Step 3 and update title + body. Preserve the
  existing draft/non-draft state unless the user passed `final` (then mark ready for
  review via `gh pr ready`).
- **PR exists, state MERGED or CLOSED** → refuse: *"PR #N is already \<state\>. Open a
  new branch if you want to ship more changes."* Do not reopen.

### Step 3: Push the Branch

If the upstream is unset or the branch is ahead of origin:

```
git push -u origin HEAD
```

If `git push` fails (non-fast-forward, hook failure, etc.), surface the error and
stop. Do not force-push.

### Step 4: Gather Context

Run in parallel:

- `git log <base>..HEAD --pretty=format:'%h %s%n%b%n---'` — every commit on the branch
  with bodies. This is the primary source for the description.
- `git diff --stat <base>...HEAD` — file-level overview.
- `git diff <base>...HEAD` — full diff. If huge (>2000 lines), sample the most-changed
  files instead of reading the whole thing.

Read project context files when present:
- `PLAN.md` — for the current task's expected test cases.
- `ROADMAP.md` — for milestone/issue context.
- `CLAUDE.md` and/or `AGENTS.md` — for documented test commands.
- `package.json` (`scripts.test`), `Makefile` (`test:` target), `pyproject.toml`,
  `Cargo.toml`, etc. — for runnable test commands.

Scan commit messages and bodies for issue references: `closes #N`, `fixes #N`,
`resolves #N`, `refs #N` (case-insensitive). Capture these for later.

### Step 5: Detect Whether Code Changed

A change counts as "code" when the diff touches files outside of `*.md`, `docs/`,
`.github/`, `.gitignore`, and similar pure-doc/meta paths. If only docs changed, skip
the test plan section. Otherwise, build one.

### Step 6: Draft the Title

- **If only one commit is ahead of base**, use that commit's subject verbatim — it
  already reflects conventional-commit style from `/commit`.
- **If multiple commits**, synthesise a title that summarises the branch:
  - Preserve the conventional-commit prefix (`feat:`, `fix:`, `refactor:`, etc.) when
    all commits share one. Otherwise pick the dominant type.
  - Under 72 characters. No trailing period.

### Step 7: Draft the Body

Use this template. Drop sections that don't apply (e.g. omit "Testing" for docs-only
PRs, omit "Notes for reviewers" when there's nothing to flag).

```markdown
## What

<1–3 sentences describing the change in concrete terms. Name the files/modules/
behaviours affected. No marketing language.>

## Why

<The motivation. Reference the milestone, issue, or user need driving the change.
If `PLAN.md` or `ROADMAP.md` provides context, cite it.>

## How

<The approach taken. Highlight non-obvious decisions, trade-offs, or alternatives
considered. A reviewer reading this should understand the shape of the diff before
opening it.>

## Testing

<Concrete steps a reviewer can run. Prefer commands from `PLAN.md` task tests, then
`package.json` scripts, then `Makefile` targets, then anything else documented in
`CLAUDE.md`/`AGENTS.md`. Format as a checklist:>

- [ ] `<command>` — <what it verifies>
- [ ] <manual step, if any>

## Notes for reviewers

<Only include if there's something genuinely worth flagging: known gaps, follow-ups
deferred to another PR, breaking changes, migration steps, performance caveats,
deviations from the plan. Skip the section entirely if none apply — don't pad.>

Closes #N
```

Rules for filling it in:

- **Source of truth is the commits + diff.** Don't speculate about features that
  aren't visible in the change.
- **If the commits are too sparse or ambiguous to write a meaningful Why or How**,
  stop and ask the user for context rather than fabricating one. Quote the
  commit subjects you saw and ask "What's the broader motivation here?" or "What
  was the alternative you ruled out?".
- **Test plan source** — try `PLAN.md` first, then project test commands. If neither
  yields anything concrete and code changed, ask the user: *"What's the test plan
  for this PR? I couldn't find runnable test commands in PLAN.md or the project
  manifests."*
- **Issue links** — append `Closes #N` (or `Fixes #N`) for every issue captured in
  Step 4. Use `Refs #N` for weaker references. One per line, at the end of the body.
- **Free-form guidance from `$ARGUMENTS`** shapes the framing but does not override
  the commits — the diff is ground truth.

### Step 8: Create or Update

Write the body to `$TMPDIR/pr-body.md` via the Write tool, then:

**Creating a new PR:**

```
gh pr create \
  --base "<base>" \
  --title "<title>" \
  --body-file "$TMPDIR/pr-body.md" \
  $DRAFT_FLAG
```

Where `$DRAFT_FLAG` is `--draft` by default, or empty if the user passed `final`.

**Updating an existing OPEN PR:**

```
gh pr edit <N> \
  --title "<title>" \
  --body-file "$TMPDIR/pr-body.md"
```

If the user passed `final` and the PR is currently a draft, additionally run
`gh pr ready <N>`.

### Step 9: Report

Report:
- The PR URL (from `gh pr create` output or `gh pr view --json url`).
- Whether it was created or updated.
- Draft / ready-for-review status.
- The base branch.
- Any issues linked.
- A one-line note if the test plan was inferred from project files (so the user knows
  to double-check it).

## Important Principles

- **Don't commit on the user's behalf.** This skill is orthogonal to `/commit`. Refuse
  cleanly when the tree is dirty.
- **Don't force-push.** If `git push` rejects, surface the error and stop — the user
  needs to resolve it.
- **Don't reopen merged or closed PRs.** Tell the user to start a new branch.
- **Default to draft.** It's cheaper to mark ready than to retract a too-early review
  request. Only skip draft when the user explicitly passes `final`.
- **Ask when context is thin.** A PR description fabricated from one-line commit
  messages is worse than a one-question pause.
- **Ground the description in commits and diff.** Don't invent features or motivations
  that aren't in the change.
- **Never use `git -C`.** Always run git commands from the current working directory.
  The `-C` flag breaks Claude Code's permission system.
