---
name: codebase-survey-update
description: >
  Incremental refresh of an existing codebase survey. With no argument, each
  module is diffed from its own recorded surveyed_sha to HEAD. With a commit
  range or PR# argument, that range is used uniformly. Maps changed paths to
  affected module docs, dispatches narrowly-scoped subagents for only those
  modules, then bumps each touched module's surveyed_sha. Model-invocable so
  it can be wired to a post-merge hook later.
argument-hint: "[commit-range | PR#]"
model: opus
allowed-tools: Read, Write, Glob, Grep, Edit, Agent, Bash(git rev-parse:*), Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(gh pr view:*), Bash(gh pr diff:*)
---

# Codebase Survey — Update

You refresh an existing survey incrementally. Init produces the baseline; the
module skill produces detail; this skill keeps both current as the codebase
moves. The goal is a small, scoped pass: only re-survey the modules whose code
actually changed, and only re-derive instructions if their sources moved.

## Inputs

`$ARGUMENTS` is optional:

- **Empty** — per-module mode: diff each module from its own `surveyed_sha`
  (recorded in its `<module>/CODEBASE.md` front-matter) to `HEAD`. Different
  modules may have different bases. This is the default and the most common
  mode.
- **Commit range** (e.g., `abc123..HEAD`, `main..feature/foo`, `HEAD~5..HEAD`) —
  use the same range for every module. Useful when reviewing one logical
  change.
- **PR number** (e.g., `123` or `#123`) — fetch the PR's changed file list
  via `gh pr diff --name-only <N>`. Maps each changed file to its module(s)
  and treats the PR's base..head as the range for those modules.

## Phase Workflow

### Step 1: Determine scope

1. Read top-level `CODEBASE.md`. Extract the module map. If absent, abort —
   `/codebase-survey-init` must run first.

2. Build the per-module change set:

   - **Per-module mode**: for each module, read its `surveyed_sha` from
     `<path>/CODEBASE.md` front-matter. Run `git diff --name-only <surveyed_sha>..HEAD -- <module-path>`.
     If `surveyed_sha` is `(no git)` or absent, treat the module as fully
     dirty (re-survey it from scratch).
   - **Range mode**: for each module, run
     `git diff --name-only <range> -- <module-path>`.
   - **PR mode**: run `gh pr view <N> --json baseRefOid,headRefOid` to get
     the base..head SHAs, then proceed as range mode.

   If git is unavailable or the SHAs are unknown, surface the failure and
   ask the user how to proceed (full re-run? skip update? specify a range?).

3. Map changed files to **survey targets**:

   | Path | Affects |
   |---|---|
   | `<module-path>/...` | that module's `CODEBASE.md` |
   | `CODEBASE.md` (root) | top-level |
   | `docs/codebase/architecture.md`, `tech-stack.md`, `operations.md` | top-level survey context |
   | Manifest files (`package.json`, `Cargo.toml`, …) at repo root | top-level survey + dep-grapher reruns on every module that depends on root manifest |
   | New top-level directory not in any module's path | unmapped — surface to user; may indicate a new module |
   | Files under `.github/workflows/`, root `Dockerfile*`, `k8s/`, etc. | repo-level operations only (does not invalidate modules) |

   Build two sets:
   - **Modules to re-survey** (their source changed).
   - **Top-level updates needed** (e.g., new module appeared, ops changed,
     module map needs revision).

   Report the scope to the user before doing work — a one-line per module
   ("`packages/api`: 12 changed files, will re-survey") plus any unmapped
   paths flagged.

### Step 2: Halt cases

Stop and ask the user before continuing if any of these are true:

- **Schema drift**: any `<module>/CODEBASE.md` (or top-level) has a
  `survey_schema` that doesn't match the current schema (`1`). Patch logic
  doesn't apply across schema versions — the user should re-init or run a
  full module re-survey.
- **Unmapped new directory**: there's a path in the diff that doesn't fall
  under any known module and looks like a new module (has its own manifest
  or its own `CODEBASE.md` stub). Surface it; don't invent a place for it.
- **Deleted module**: a module's path in the map no longer exists. Surface
  it; the user should decide whether to remove it from the map.
- **No changes**: the diff is empty for every module. Report and exit
  cleanly — no writes.

### Step 3: Re-survey the affected modules

For each module in **Modules to re-survey**, invoke the same orchestration
as `/codebase-survey-module` would: spawn the five subagents in parallel
(`dep-grapher`, `api-surface-extractor`, `wire-api-extractor`, `test-auditor`,
`ops-detective`) targeting the module path, then assemble the new
`<module>/CODEBASE.md`.

Optimisations specific to update mode:

- If the diff for a module touches only test files, you may skip
  `wire-api-extractor` and `api-surface-extractor` — the language and wire
  surface haven't changed. Always rerun `test-auditor` in this case.
- If the diff touches only docs (`*.md` outside the survey itself), you
  may skip everything and just bump `surveyed_sha` + `surveyed_at`. Note
  this in the run report so the user can verify.
- If the diff touches the manifest, rerun all five — manifest changes can
  affect any of them.

Preserve hand-edits in `Architectural Deviations` and `Open Questions`
exactly as `/codebase-survey-module` does.

### Step 4: Update top-level survey

If **Top-level updates needed** is non-empty:

- New module appeared: append to the module map after user confirmation.
  Do not auto-create the per-module stub — that's an init responsibility,
  but you may surface "run `/codebase-survey-module <path>` to populate it."
- Ops changed at repo level: rerun `ops-detective` on the repo root and
  rewrite `docs/codebase/operations.md`'s body.
- Tech stack changed (root manifest version bumps, language additions):
  update the `Tech Stack` section in `CODEBASE.md`.

Bump the top-level `surveyed_sha` only when the top-level file's body
actually changed. A module-only refresh leaves the top-level SHA alone —
it tracks repo-wide structural state, not the union of module states.

### Step 5: Flag derivation drift

`CLAUDE.md` files were derived from these surveys. Any module re-surveyed
in this run has a new `surveyed_sha`, which means `CLAUDE.md`'s
`derived_from_survey_sha` is now stale. After the survey writes are done:

- Read root `CLAUDE.md` (and any `<module>/CLAUDE.md`) front-matter.
- For every CLAUDE.md whose `derived_from_survey_sha` references a survey
  file you just rewrote, mark it as drifted in the run summary.

Do **not** rewrite `CLAUDE.md` here — `/codebase-derive-instructions` is
the only skill that writes it. Surface the drift in your hand-off.

### Step 6: Skip the assessment unless asked

Architectural assessment is not auto-rerun. Diffs almost never invalidate
cross-cutting findings cleanly, and rerunning `/codebase-architecture-assessment`
on every minor change would thrash `assessment.md`. Surface a hint
("Several modules changed — consider rerunning `/codebase-architecture-assessment`")
when more than ~30% of modules were re-surveyed in one run, but stop there.

### Step 7: Hand off

Report concisely:

- Modules re-surveyed (with one-line change summaries — "12 src files, 3
  test files").
- Modules **skipped** because the diff was empty (good — proves the per-module
  SHA is doing its job).
- Modules where you took an optimisation shortcut (tests-only, docs-only).
- Top-level updates applied.
- `CLAUDE.md` files now drifted (will need `/codebase-derive-instructions`).
- Any halt-case items the user needs to resolve manually.

Do **not** commit. The user reviews and runs `/commit`.

## Behavioural Guarantees

- **Idempotent**: running with no diff (a no-op) writes nothing.
- **Per-module SHA accuracy**: each module's `surveyed_sha` after this run
  equals `git rev-parse HEAD` *only* if the module was actually re-surveyed.
  Skipped modules retain their old SHA so the next update can still detect
  their changes.
- **No hidden writes**: the run report enumerates every file touched.
- **Safe in CI**: the skill never edits `CLAUDE.md` and never commits, so
  it's safe to wire to a post-merge hook later — that hook can simply
  surface a list of drifts for human review.

## Important Principles

- **Diff drives scope, not opinion.** Don't re-survey a module because it
  "feels stale" — only because its tracked path has commits since
  `surveyed_sha`.
- **Trust the per-module SHAs.** They're the contract that makes
  incremental updates correct. If you find one is wrong, fix that module,
  don't broaden the scope.
- **Surface, don't fix, top-level structural changes.** New modules,
  deleted modules, and schema drifts need human judgment. Halt and ask.
- **Light touch on `CLAUDE.md`.** This skill flags drift; it doesn't
  rewrite. Keeping the rewriting in `/codebase-derive-instructions` keeps
  the rule chain auditable.
