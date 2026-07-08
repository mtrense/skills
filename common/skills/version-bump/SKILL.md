---
name: version-bump
description: >
  Bump the current project's version and cut an annotated git tag carrying a
  changelog. Detects the version manifest (package.json, Cargo.toml,
  pyproject.toml, and similar), computes the new SemVer from an argument that is
  either an explicit version or one of `major`/`minor`/`patch`, gathers a
  changelog from the commits since the last version tag (via the
  `changelog-gatherer` subagent), writes it to CHANGELOG.md, and creates a git
  tag whose message is that changelog. User-invoked only (`/version-bump`) —
  cutting a release is an explicit human decision, never an inferred one.
disable-model-invocation: true
argument-hint: "major | minor | patch | <x.y.z>"
model: sonnet
allowed-tools: Bash(git tag *), Bash(git log *), Bash(git describe *), Bash(git rev-parse *), Bash(git push *), Bash(git status *), Bash(ls *), Bash(head *), Bash(grep *), Bash(printf *), Bash(for *), Read, Write, Edit, Glob, Skill, Agent
---

# Version Bump — Increment the Version and Cut a Tagged, Changelogged Release

You bump the project's declared version, record a changelog, and create an
annotated git tag whose message *is* that changelog. The changelog is gathered
from the commits since the last release by a subagent so the raw `git log` never
lands in this session's context.

This skill does **not** commit directly. Per the repo convention, `/commit` is the
only commit point — so you make the file edits, delegate the release commit to
`/commit`, then tag the resulting commit. Correct release semantics (tag points at
the commit that contains the bump) without breaking the single-commit-point rule.

## Pre-rendered repository state

The blocks below are the captured stdout of shell commands run *before* this skill
loaded. Treat them as the source of truth — do not re-run the same commands unless
you need something they don't cover.

### Version manifests present (with their version lines)

```
!`for f in package.json Cargo.toml pyproject.toml setup.py setup.cfg composer.json go.mod deno.json build.gradle build.gradle.kts pom.xml mix.exs pubspec.yaml Chart.yaml VERSION version.txt; do [ -f "$f" ] && printf '=== %s ===\n' "$f" && grep -inE 'version' "$f" | head -5; done 2>/dev/null || echo '(no known manifest matched)'`
```

### Most recent version tag

```
!`git describe --tags --abbrev=0 2>/dev/null || echo '(no tags yet)'`
```

### Recent tags (naming style reference)

```
!`git tag --list --sort=-version:refname 2>/dev/null | head -20 || echo '(none)'`
```

### Commit count since the last tag

```
!`LAST=$(git describe --tags --abbrev=0 2>/dev/null); if [ -n "$LAST" ]; then printf 'range: %s..HEAD\n' "$LAST"; git log --oneline "$LAST"..HEAD | wc -l; else printf 'range: (entire history — no prior tag)\n'; git log --oneline | wc -l; fi`
```

### Existing CHANGELOG.md (top)

```
!`[ -f CHANGELOG.md ] && head -40 CHANGELOG.md || echo '(no CHANGELOG.md yet)'`
```

### Working tree status

```
!`git status --short 2>/dev/null || echo '(not a git repo)'`
```

## Workflow

### Step 0: Parse the argument

The user passes `$ARGUMENTS`. It is exactly one of:

- `major` — increment major, zero the rest (`0.4.2` → `1.0.0`).
- `minor` — increment minor, zero patch (`0.4.2` → `0.5.0`).
- `patch` — increment patch (`0.4.2` → `0.4.3`).
- An explicit version like `1.2.3` (a leading `v` is tolerated and stripped for
  computation, but see Step 3 for how the tag is named).

If `$ARGUMENTS` is empty or is none of the above, stop and ask the user which bump
they want. Do not guess.

### Step 1: Identify the manifest and current version

From the **Version manifests present** block, pick the project's authoritative
version file:

- Exactly one manifest with a version → that's it.
- Multiple manifests (e.g. a JS `package.json` and a `Cargo.toml`) → prefer the one
  that matches the project's primary language/build, but if two disagree on the
  current version, stop and ask the user which to treat as source of truth. (You
  will bump only the one you're told to unless the user asks to keep them in sync.)
- No manifest with a parseable version → ask the user where the version lives, or
  whether to create a `VERSION` file.

`Read` the chosen manifest to capture the **exact current version string and its
surrounding syntax** (quotes, key name, formatting) so the edit in Step 5 is
surgical. Note the manifest's version format — some use pre-release/build suffixes
(`1.2.0-rc.1`, `1.2.0+build.5`); preserve or drop them deliberately, not by accident.

### Step 2: Compute the new version

- **Explicit version:** use it verbatim (after stripping any leading `v`). Sanity-check
  it is valid SemVer and **greater than** the current version; if it is not greater,
  warn the user and ask for confirmation before proceeding.
- **`patch`:** `x.y.(z+1)`.
- **`minor`:** `x.(y+1).0`.
- **`major`:** `(x+1).0.0`.

`major` and `minor` truncate all lower components to zero. Drop any pre-release/build
suffix from the current version when incrementing unless the user asked to keep it.

State the transition plainly to the user before editing: *"Bumping `<manifest>` from
`X.Y.Z` to `A.B.C`."*

### Step 3: Determine the tag name and commit range

- **Tag name:** match the existing tag naming style from the **Recent tags** block. If
  existing tags are `vX.Y.Z`, name the new tag `vA.B.C`; if they are bare `X.Y.Z`, use
  `A.B.C`. With no prior tags, default to the `v`-prefixed form (`vA.B.C`).
- **Commit range for the changelog:** `<last tag>..HEAD` when a prior tag exists,
  otherwise the entire history. Take the range from the **Commit count since the last
  tag** block.

### Step 4: Gather the changelog (delegated to `changelog-gatherer`)

Dispatch the `changelog-gatherer` subagent via the `Agent` tool
(`subagent_type: changelog-gatherer`). Pass it:

- the **commit range** (e.g. `v0.4.2..HEAD`, or "entire history" when there is no prior tag),
- the **new version string** (`A.B.C`),
- the **repo root** (current working directory).

It runs `git log` over that range itself (via its Bash tool — the range is dynamic,
so it can't be inlined at load time), groups commits into Keep-a-Changelog sections,
and returns a single ready-to-use changelog block. The raw commit list stays inside
the subagent. It returns markdown of the shape:

```markdown
## [A.B.C] - YYYY-MM-DD

### Added
- ...

### Fixed
- ...
```

If the subagent reports there are no user-relevant commits in the range, tell the user
and confirm they still want to cut the release before continuing.

### Step 5: Apply the version edit

`Edit` the manifest chosen in Step 1 to replace the current version with the new one.
Change **only** the version value — match the exact quoting/formatting you captured in
Step 1. If the user asked to keep multiple manifests in sync, edit each of them.

### Step 6: Update CHANGELOG.md

- **CHANGELOG.md exists:** insert the new section from Step 4 immediately below the
  top header (and below an `## [Unreleased]` heading if one is present), above the most
  recent prior release section. Preserve the rest of the file verbatim.
- **CHANGELOG.md is absent:** create it with a standard header, then the new section:

  ```markdown
  # Changelog

  All notable changes to this project are documented in this file. The format is
  based on [Keep a Changelog](https://keepachangelog.com/) and this project adheres
  to [Semantic Versioning](https://semver.org/).

  <new section here>
  ```

### Step 7: Commit the bump (delegated to `/commit`)

Invoke the `commit` skill via the `Skill` tool, passing guidance that this is a
release commit and requesting the message `chore(release): <tag name>` (e.g.
`chore(release): v1.2.0`). This stages and commits the manifest + CHANGELOG.md
changes. `/commit` is the only commit point — do **not** run `git commit` yourself.

If the working tree had **unrelated** uncommitted changes at Step 0 (see the status
block), point them out first and ask whether to include them or stop — a release
commit should contain only the bump.

### Step 8: Create the annotated tag

Write the changelog block from Step 4 to `$TMPDIR/tag-message.txt` with the `Write`
tool, then create the annotated tag on the release commit:

```
git tag -a "<tag name>" -F "$TMPDIR/tag-message.txt"
```

Using `-F` with a temp file keeps the multi-line markdown message intact and needs no
escaping. If a tag with that name already exists, stop and tell the user — do not
overwrite or force a tag.

### Step 9: Report

Output to the user:

1. The full changelog block from Step 4 (this is the "output in the chat" deliverable).
2. A summary line: *"Bumped `<manifest>` `X.Y.Z` → `A.B.C`, committed as `<hash>`, tagged `<tag name>`."*
3. The files changed.
4. A reminder that the tag is local: *"Run `git push && git push origin <tag name>` (or `git push --follow-tags`) to publish."* Do not push unless the user asks.

## Important Principles

- **Never commit or push on your own.** Editing files is yours; committing belongs to
  `/commit`; pushing is the user's explicit call. This preserves the repo's
  single-commit-point rule.
- **The tag message is the changelog.** The same block goes to CHANGELOG.md, the tag
  annotation, and the chat — one source, three destinations.
- **Bump exactly one version value.** Surgical edits only; never reformat the manifest.
- **Match existing tag naming.** Don't introduce a `v` prefix (or drop one) that breaks
  the project's tag history.
- **Refuse to clobber.** An existing tag of the same name, or a target version not
  greater than the current one, is a stop-and-ask, not an overwrite.
- **Never use `git -C`.** Always run git from the current working directory — the `-C`
  flag breaks Claude Code's permission system.
