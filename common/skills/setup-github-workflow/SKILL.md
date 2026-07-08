---
name: setup-github-workflow
description: >
  Analyze the current project and propose GitHub Actions workflows for CI and
  releases tailored to its technology and goal — or, when workflows already
  exist, refresh the pinned versions of every action and library to the latest
  available. Interviews the human on the judgement calls (which branching model
  to support, when CI runs, when a release is cut) until there is a shared
  understanding, pins every action to a specific commit SHA at its most current
  version, has those target versions security-assessed by the
  `action-security-auditor` subagent, and asks for explicit confirmation before
  writing. Never commits. User-invoked only (`/setup-github-workflow`).
disable-model-invocation: true
argument-hint: "(no args — analyzes the current project)"
model: opus
allowed-tools: Bash(ls *), Bash(cat *), Bash(head *), Bash(find *), Bash(grep *), Bash(git tag *), Bash(git describe *), Bash(git remote *), Bash(git branch *), Bash(git rev-parse *), Read, Write, Edit, Glob, Grep, Agent
---

# Setup GitHub Workflow — Propose or Refresh CI & Release Workflows

You design (or update) the project's `.github/workflows/*.yml` files. You pick CI
and release actions that fit the detected technology and project goal, pin every
action to a **specific commit SHA** at its most current version, and get those
target versions security-checked before proposing them. You interview the human on
every judgement call and get explicit confirmation before writing any file.

You do **two** related jobs depending on what already exists:

- **Greenfield** (no `.github/workflows/`) — propose a fresh set of workflows from
  scratch, tailored to the stack and goal.
- **Refresh** (workflows already present) — keep the existing structure and logic,
  but bump every action and library version to the latest available and re-pin to
  the current commit SHA, surfacing any new security concerns.

This skill **never commits** and **never pushes**. Per the repo convention, `/commit`
is the only commit point. You write (or edit) the workflow files, then stop and tell
the user to review and commit.

## Pre-rendered repository state

The blocks below are the captured stdout of shell commands run *before* this skill
loaded. Treat them as the source of truth for the initial read — don't re-run the
same commands unless you need something they don't cover.

### Existing GitHub Actions workflows

```
!`if [ -d .github/workflows ]; then for f in .github/workflows/*; do [ -f "$f" ] && printf '=== %s ===\n' "$f" && cat "$f"; done; else echo '(no .github/workflows directory — greenfield)'; fi 2>/dev/null`
```

### Technology signals (build manifests / lockfiles present)

```
!`for f in package.json pnpm-lock.yaml yarn.lock package-lock.json Cargo.toml pyproject.toml setup.py requirements.txt poetry.lock go.mod build.gradle build.gradle.kts pom.xml composer.json Gemfile mix.exs pubspec.yaml deno.json Dockerfile Makefile .tool-versions .nvmrc .python-version rust-toolchain.toml; do [ -f "$f" ] && printf '=== %s ===\n' "$f" && head -30 "$f"; done 2>/dev/null || echo '(no known manifest matched)'`
```

### Project identity (README top, for the project goal)

```
!`for f in README.md README.rst docs/README.md; do [ -f "$f" ] && printf '=== %s ===\n' "$f" && head -60 "$f" && break; done 2>/dev/null || echo '(no README found)'`
```

### Git remote (is this even a GitHub project?)

```
!`git remote -v 2>/dev/null | head -4 || echo '(no git remote)'`
```

### Default / current branch and branch list

```
!`printf 'HEAD: '; git rev-parse --abbrev-ref HEAD 2>/dev/null; printf 'branches:\n'; git branch -a 2>/dev/null | head -20 || echo '(not a git repo)'`
```

### Existing tags (release-cadence signal)

```
!`git tag --list --sort=-version:refname 2>/dev/null | head -10 || echo '(none)'`
```

### CHANGELOG present?

```
!`[ -f CHANGELOG.md ] && head -20 CHANGELOG.md || echo '(no CHANGELOG.md)'`
```

## Workflow

### Step 1: Understand the project

From the pre-rendered blocks, build a model of:

- **Stack** — language(s), package manager, build/test tooling, whether there's a
  Dockerfile, monorepo vs single package. If the signals are ambiguous (e.g. both a
  `package.json` and a `Cargo.toml`), read the relevant files with `Read`/`Glob` to
  resolve which is primary before proposing anything.
- **Goal / distribution shape** — from the README: is this a library published to a
  registry (npm/crates.io/PyPI), a container image, a CLI binary, a hosted service,
  a static site? The distribution shape decides what a *release* workflow even does.
- **Current state** — greenfield (no workflows) vs refresh (workflows present). In
  the refresh case, note the existing workflow names, triggers, jobs, and every
  `uses:` action reference and version already pinned.

If this is not a GitHub project (no GitHub remote), say so and ask whether to proceed
anyway (the workflows still work on any GitHub mirror) before continuing.

### Step 2: Interview the human on the judgement calls

Do **not** guess the things below — they are human decisions. Ask them, one coherent
round at a time, and keep asking follow-ups until you and the user share a clear
understanding. Confirm your understanding back in a short summary before moving on.

Cover at minimum:

1. **Branching / workflow model.** Which does the project use — **trunk-based**
   (commits/merges to `main` trigger everything), **PR-based** (checks run on pull
   requests, merges are gated), **release-branch / GitFlow** (long-lived
   `release/*` or `develop` branches), or a mix? This decides the `on:` triggers.
2. **When CI runs.** On every push? Only on PRs to the default branch? On tags?
   Which branches? Should it run on a schedule (nightly) as well? Matrix across
   multiple language/OS versions, or a single target?
3. **What CI does.** Lint, type-check, test, build, coverage upload — confirm the
   exact steps against the detected tooling. Ask about anything the manifests hint
   at but don't confirm (e.g. is there an integration-test suite that needs
   services?).
4. **When a release is cut and what it produces.** Manual tag push? A `release`
   GitHub event? A version-bump commit? And what's the artifact — a published
   package, a GitHub Release with binaries, a container image pushed to a registry?
   Tie this to the distribution shape from Step 1 and to the existing tag naming
   (from the tag list above). If prior tags establish a convention, follow it
   verbatim; if there is no clear prior convention, default to the `v`-prefixed
   `vX.Y.Z` format (e.g. `v0.1.0`).
5. **Secrets / permissions.** Which published targets need tokens
   (`NPM_TOKEN`, `CARGO_REGISTRY_TOKEN`, `PYPI_API_TOKEN`, `GHCR`/`GITHUB_TOKEN`,
   etc.)? Note them so the workflow references them by name — never invent or embed
   secret values; reference `${{ secrets.NAME }}` and tell the user which to set.

For a **refresh**, the interview is lighter: confirm whether the existing triggers
and structure should stay as-is (default: yes — only bump versions) or whether the
user also wants to revisit any of the judgement calls above.

Only proceed once the plan is unambiguous. If the user defers a decision to you,
recommend a sensible default for the detected stack and state it explicitly rather
than leaving it implicit.

### Step 3: Draft the workflow set (in your head / as a plan, not yet written)

Translate the shared understanding into concrete workflow file(s). Typical shape:

- `ci.yml` — the CI workflow, triggers and jobs per Step 2.
- `release.yml` — the release workflow, if the project publishes anything.

For every `uses:` reference, choose the **most up-to-date stable version available
at the time of calling** for each action and, where relevant, the latest stable
version of any language-setup toolchain the steps install. Collect the full list of
action references you intend to use (e.g. `actions/checkout`, `actions/setup-node`,
`actions/upload-artifact`, `docker/build-push-action`, `softprops/action-gh-release`)
— you will hand this list to the subagent in Step 4 to resolve exact SHAs and vet
them. Do **not** finalize version numbers yourself from memory; the subagent returns
the authoritative current version + SHA.

### Step 4: Resolve pinned SHAs and security-assess (delegated to `action-security-auditor`)

Dispatch the `action-security-auditor` subagent via the `Agent` tool
(`subagent_type: action-security-auditor`). Pass it:

- the **list of every action** you plan to `uses:` (owner/repo form, e.g.
  `actions/checkout`),
- for a **refresh**, also the **currently pinned version/SHA** of each action found
  in the existing workflows (from the pre-rendered block), so it can report what's
  changing,
- the **repo root** (current working directory).

The subagent resolves each action's latest stable release, pins it to the exact
**commit SHA** for that release, and assesses each target version for security risk
(known CVEs, recently-compromised actions, maintainer/ownership red flags,
unpinned transitive references). It returns, per action, `owner/repo`, the chosen
version tag, the full commit SHA, and any security findings. It does **not** edit
files.

**Surface every security finding to the human.** If the subagent flags a risk on any
action (e.g. a known-compromised tag, an action with no recent maintenance, a
publisher change), present it plainly and ask how to proceed — swap for an
alternative, pin to an older known-good SHA, or accept the risk knowingly — before
writing. Do not silently include a flagged action.

### Step 5: Confirm before writing

Show the user the **complete proposed content** of each workflow file (or, for a
refresh, a clear diff of the version/SHA changes), including:

- every `uses:` line in the form `owner/repo@<full-sha> # vX.Y.Z` — the SHA is the
  pin, the trailing comment records the human-readable version,
- the triggers and jobs reflecting the agreed plan,
- the secret names the user must configure.

Ask for explicit confirmation. Only after the user approves do you write files. If
they want changes, revise and re-confirm.

### Step 6: Write the files (no commit)

`Write` new workflow files (or `Edit` existing ones for a refresh) under
`.github/workflows/`. Create the directory implicitly via the write path. Change only
what was agreed:

- **Greenfield:** write the full workflow files.
- **Refresh:** edit only the version/SHA references (and anything else the user
  explicitly asked to change) — preserve the existing structure, comments, and
  formatting otherwise.

Do **not** run `git add`, `git commit`, or `git push`. This skill is not a commit
point.

### Step 7: Report

Tell the user:

1. Which files you wrote or edited.
2. A one-line-per-action summary of the pinned versions (`owner/repo vX.Y.Z @ sha`).
3. Any security findings that were accepted knowingly.
4. The secrets they still need to configure in the repo settings.
5. A reminder that nothing is committed: *"Review the workflows and run `/commit`
   when you're ready."*

## Important Principles

- **Pin to commit SHAs, always.** Every `uses:` reference is `owner/repo@<full-sha>`
  with a `# vX.Y.Z` comment. A mutable tag (`@v4`) or branch (`@main`) is never an
  acceptable pin — it's a supply-chain risk. The SHA comes from the subagent, not
  from memory.
- **Latest version at call time.** Use the most current stable release of each action
  and toolchain as resolved *now*, not a version baked into these instructions.
- **Judgement calls belong to the human.** Branching model, CI triggers, release
  cadence, and what a release produces are asked, discussed, and confirmed — never
  assumed. Keep interviewing until the understanding is shared.
- **Security findings are never buried.** Anything the subagent flags is surfaced and
  resolved with the user before that action lands in a file.
- **Confirm before writing; never commit.** File writes happen only after explicit
  approval; committing is the user's call via `/commit`.
- **Never embed secret values.** Reference `${{ secrets.NAME }}` and list the names
  for the user to set; never write a literal token into a workflow.
- **Refresh preserves intent.** When updating existing workflows, change versions and
  SHAs (and only what the user asked); don't silently restructure their pipeline.
