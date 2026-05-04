---
name: codebase-survey-module
description: >
  Deep-dive survey of one module. Spawns the dep-grapher, api-surface-extractor,
  wire-api-extractor, test-auditor, and ops-detective subagents in parallel,
  then assembles the module's CODEBASE.md from their reports. Idempotent — re-running
  rewrites the file. Trigger after /codebase-survey-init has produced module
  stubs, or whenever a single module needs a fresh detailed survey. Argument:
  the module path (relative to repo root).
argument-hint: "<module-path>"
model: opus
allowed-tools: Read, Write, Glob, Grep, Edit, Agent, Bash(git rev-parse:*), Bash(git log:*)
---

# Codebase Survey — Module Deep-Dive

You are filling in (or refreshing) `<module-path>/CODEBASE.md` for one module
by orchestrating five specialized subagents in parallel, then assembling
their findings into the module's survey file.

You are model-invocable on purpose: an outer orchestrator (e.g., an
`/implementation-cycle`-style burndown over the module list) can iterate
this skill across modules without user intervention.

## Inputs

`$ARGUMENTS` is the module path relative to the repo root (e.g.,
`packages/core`, `services/auth`, `.`). If empty, abort with a clear error —
this skill needs an explicit target.

## Phase Workflow

### Step 1: Locate and read the module stub

1. Confirm `<module-path>/CODEBASE.md` exists. If not, ask the user whether
   they want you to:
   - Run `/codebase-survey-init` first (preferred, when no top-level survey
     exists), or
   - Create the stub on the fly here (acceptable when this is a one-off
     survey of a module the user added after init).

2. Read the stub. Note its current `surveyed_sha` (used later) and any
   non-TODO content the user has hand-edited — you will preserve hand-edits
   in the `Open Questions` and `Architectural Deviations` sections rather
   than overwriting them blindly.

3. Capture `git rev-parse HEAD` for the new `surveyed_sha`. Capture today's
   date for `surveyed_at`.

4. Detect the module's primary manifest (`package.json`, `Cargo.toml`,
   `pyproject.toml`, `go.mod`, `pom.xml`, `build.gradle*`, `*.csproj`,
   `mix.exs`, `composer.json`). Pass it to the subagents so they don't
   re-detect.

### Step 2: Spawn subagents in parallel

Use the `Agent` tool **multiple times in a single message** so the subagents
run concurrently. Spawn five:

| subagent_type | Self-contained prompt template |
|---|---|
| `dep-grapher` | "Compute the dependency graph for module at `<absolute-module-path>`. Manifest: `<manifest-path>`. Follow your standard report format." |
| `api-surface-extractor` | "Extract the language-level public API for module at `<absolute-module-path>`. Manifest: `<manifest-path>`. Sample cap: 80 symbols. Follow your standard report format." |
| `wire-api-extractor` | "Extract the wire/network API for module at `<absolute-module-path>`. Manifest: `<manifest-path>`. Follow your standard report format." |
| `test-auditor` | "Audit tests for module at `<absolute-module-path>`. Manifest: `<manifest-path>`. Follow your standard report format." |
| `ops-detective` | "Inventory operational artifacts for module at `<absolute-module-path>`. Follow your standard report format. Note: repo-level CI/CD will be handled separately at the architecture-assessment phase — focus on module-local Dockerfiles, scripts, .env.example, observability libs in this module's manifest." |

If a subagent fails or returns no useful data, capture its `Tooling Notes` and
proceed — the module survey still has signal from the others.

### Step 3: Assemble the module CODEBASE.md

Write `<module-path>/CODEBASE.md` (overwriting any prior content **except**
the hand-edit zones — see Step 4) with this exact structure:

```markdown
---
surveyed_sha: <new SHA>
surveyed_at: <YYYY-MM-DD>
survey_schema: 1
---

# <Module Name>

## Purpose
<2–3 sentence synthesis: what this module does, who calls it, where it sits.
Sources: manifest description, README, the module path's role in the layout,
the wire-api report's contract location, the dep-grapher's inbound list.>

## Functional Requirements
<Bulleted list of capabilities the module provides. Derive from API surface
and wire API: each top-level public symbol or endpoint corresponds to a
capability. Rephrase as user-facing capability, not API mechanics.
If the module is plumbing (no clear FRs), state that explicitly.>

## Non-Functional Requirements
<Bulleted list, derived from observable signals only:
 - Performance hints from dep-grapher (e.g., uses async runtime, caching libs)
 - Security hints from auth schemes in wire-api, secret-management in ops report
 - Reliability hints from test posture (e.g., property tests present)
 - Observability from ops-detective
 If a category has no signal, write `(none observed)` rather than inventing one.>

## Dependencies

### Outbound
<From dep-grapher. List direct outbound (third-party) dependencies. If long,
group by purpose (HTTP, DB, async, logging, …). Flag fallback-grep results.>

### Inbound (workspace)
<From dep-grapher's "Inbound (workspace-internal)" section. List other modules
that depend on this one. If none, write `(none — leaf module)`.>

## API Surface

### Language-level
<From api-surface-extractor. Group by kind (types, functions, constants).
Show one-line signatures. If truncated, note the total count.>

### Wire / Network
<From wire-api-extractor. Group by protocol (HTTP/REST, gRPC, GraphQL, events).
Note the contract location verbatim from the report (spec file vs. code-only).>

## Architectural Deviations
<This section is for things that violate the module's stated design intent or
that an instructed AI would otherwise miss. Sources:
 - Code-only contracts where a spec was expected.
 - Direct calls into another module's internals (cross-module imports of
   non-public symbols, surfaced by api-surface + dep-grapher).
 - Test posture mismatches (e.g., critical module with no integration tests).
 - "Glue" code that bypasses the module's documented surface.

If this CODEBASE.md previously had hand-edited content under this heading,
PRESERVE IT — append your new findings under a `### From this run` subheading
rather than overwriting. See Step 4.>

## Testing
<From test-auditor. Pyramid shape (unit / integration / e2e file counts), the
collect-only count if available, coverage if surfaced. State the test runner
explicitly. Do not editorialise.>

## Operations
<From ops-detective. Module-local Dockerfile, scripts, .env.example variable
names, observability libraries the manifest depends on. If everything ops is
repo-level, write `(no module-local ops artifacts; see top-level operations.md)`.>

## Open Questions
<Preserve hand-edited content from prior runs. Append findings flagged by
subagents — e.g., grep-fallback warnings, manifest absences, missing coverage
artifact, contract drift signals — under a `### From this run` subheading.>
```

### Step 4: Preserve hand-edits

Before overwriting, scan the existing file for content under
`## Architectural Deviations` and `## Open Questions` that is **not** a TODO
placeholder and not under a `### From this run` subheading. Treat that
content as authored by a human — preserve it verbatim and place new findings
under a `### From this run (<YYYY-MM-DD>)` subheading.

For all other sections, the new run's content fully replaces the old. The
goal is idempotence on input but tolerance for human notes.

### Step 5: Update top-level survey status

If `CODEBASE.md` at the repo root has a "Survey Status" section with a
checklist of per-module surveys, flip this module's checkbox from `[ ]` to
`[x]`. Do not modify any other status lines.

### Step 6: Hand off

Report concisely:

- Path written.
- New `surveyed_sha`.
- A one-line note for each subagent that fell back to grep or skipped a tool,
  so the user knows the survey's accuracy ceiling.
- The next module to survey, if a top-level checklist exists and any are
  still `[ ]`. Otherwise suggest `/codebase-architecture-assessment`.

Do **not** commit.

## Operating Modes

This skill handles two modes implicitly:

- **First-time fill** (stub has TODOs): write all sections from subagent reports.
- **Refresh** (stub already has content): same write logic, but obey the
  hand-edit preservation in Step 4.

A third mode — **incremental update from a diff** — is the
`/codebase-survey-update` skill's job, not this one. If the user wants to
update only sections affected by a recent change, they should invoke that
skill instead.

## Important Principles

- **Parallelize subagents.** All five spawn in one message. The skill runs
  faster and the main session never sees raw `cargo tree` output — only the
  structured reports.
- **Tolerate subagent failures.** A missing `pip-deptree` is a footnote, not
  a fatal. The module survey is still useful.
- **Preserve human notes.** `Architectural Deviations` and `Open Questions`
  are the most likely targets of hand-edits. Never silently drop them.
- **Source-anchored, not opinionated.** Don't editorialise about quality.
  That is the architecture-assessment skill's job — it has the cross-module
  view this skill lacks.
- **Idempotent.** Re-running on an unchanged repo should produce a
  byte-identical file modulo `surveyed_sha`, `surveyed_at`, and
  `### From this run` timestamps.
