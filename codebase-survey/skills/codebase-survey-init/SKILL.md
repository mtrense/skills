---
name: codebase-survey-init
description: >
  Bootstrap a codebase survey: delegate raw structural discovery to the
  structural-discovery subagent, synthesize the module map (judgment call —
  stays in the main session), then write the top-level CODEBASE.md plus per-module
  stub files. Run once per repository, before per-module deep-dives.
disable-model-invocation: true
argument-hint: "(no arguments)"
model: opus
allowed-tools: Read, Write, Glob, Grep, Edit, Agent, Bash(git rev-parse:*), Bash(git log:*)
---

# Codebase Survey — Init

You are bootstrapping a codebase survey for an existing repository. Your output
is a top-level `CODEBASE.md` plus a per-module `<module>/CODEBASE.md` stub for
every module identified. Detail goes into the modules in a later phase
(`/codebase-survey-module`).

This is a one-time bootstrap. If `CODEBASE.md` already exists at the repo root,
stop and ask the user before overwriting — re-running init throws away whatever
the prior survey produced.

## Phase Workflow

### Step 1: Sanity check

- Confirm you are inside a git repository. If not, ask the user — every survey
  artifact records a `surveyed_sha`, so a non-git repo is a soft block. The user
  may proceed (you'll record `(no git)` instead of a SHA), but flag it.
- Capture `git rev-parse HEAD` for the `surveyed_sha` front-matter.
- Capture today's date for `surveyed_at`.
- Check for an existing `CODEBASE.md`. If it exists with non-trivial content,
  ask the user whether to start fresh or abort.
- Check for an existing `docs/codebase/` directory; same handling.

### Step 2: Delegate raw discovery

Spawn the **structural-discovery** subagent. Use the `Agent` tool with
`subagent_type: structural-discovery`. Self-contained prompt:

```
You are running for the codebase-survey-init skill. Scan the repository at
<absolute repo path>. Follow your standard report format. Do not propose
modules or architecture — return only raw signals.
```

Wait for it. The subagent returns a `report` block with manifests, workspace
members, top-level layout, language mix, and tooling notes. Read the report
carefully — you will use *all* of it.

If the subagent fails (e.g., `find` unavailable, permission errors), surface
the failure to the user and stop — synthesizing modules without the structural
report is a guess.

### Step 3: Synthesize the module map (in the main session)

Module identification is a **judgment call** — keep it in the main session, do
not delegate. Apply this priority order:

1. **Explicit workspace declarations.** Cargo `[workspace].members`,
   `pnpm-workspace.yaml packages`, `package.json workspaces`, Go `go.work use`,
   Maven `<modules>`, Gradle `include(...)`, Mix umbrella `apps_path`. Each
   listed member becomes one module. This is the strongest signal — when it
   exists, prefer it over heuristics.

2. **Top-level packages with their own manifest.** A directory at the repo
   root that has its own `package.json` / `pyproject.toml` / `Cargo.toml`
   without a workspace declaration is a module by itself.

3. **Conventional sub-trees.** When neither workspace nor manifest signals
   exist (typical monolith), fall back to top-level directories under `src/`
   or root-level conventional dirs (`cmd/`, `pkg/`, `internal/`, `apps/`,
   `services/`, `lib/`). Each becomes a tentative module.

4. **Single-module repo.** If steps 1–3 produce zero or one candidate, treat
   the whole repo as one module — write only the top-level `CODEBASE.md` and
   skip per-module stubs. Note the choice in the file under "Modules".

For each candidate module, record: name (basename of the path), path
(relative to repo root), primary language (best guess from layout + language
mix), and a one-line purpose hint pulled from the manifest (`description`,
`name`, README) when present, otherwise `(unspecified — fill in via /codebase-survey-module)`.

### Step 4: Confirm with the user

Present the proposed module map as a short bulleted list — name, path, primary
language, one-line purpose hint. Ask:

> Does this module map look right? You can:
> - Accept as-is.
> - Add or remove specific modules.
> - Choose to treat this as a single-module repo.
> - Adjust naming.

Iterate until the user is satisfied. Do not write any files yet.

If the user does not want a confirmation step (e.g., they say "go ahead, no
need to check"), skip directly to Step 5 with the synthesized map.

### Step 5: Write the artifacts

Once the map is confirmed, write the files. Do this in a single batch — do not
ask between modules.

**Top-level `CODEBASE.md`** (repo root):

```markdown
---
surveyed_sha: <git SHA at init, or "(no git)">
surveyed_at: <YYYY-MM-DD>
survey_schema: 1
---

# <Repo Name> — Codebase Survey

> High-level entry point for the AI-consumable codebase survey. Detail lives
> in per-module `CODEBASE.md` files and in `docs/codebase/`.

## Project at a Glance
<2–4 sentences synthesised from the README excerpt and language mix. State the
artifact type (library / service / monorepo / CLI / web app) and primary
language.>

## Tech Stack
- **Languages:** <top 3 from language mix, with shares>
- **Build / package managers:** <derived from manifests, e.g., "Cargo, pnpm">
- **Notable frameworks:** <only if visible from manifests — leave a TODO if not>

## Module Map
| Module | Path | Primary Language | Purpose |
|---|---|---|---|
| <name> | `<path>` | <lang> | <one-line hint, or TODO> |
| ... | | | |

> Per-module detail: see each module's `CODEBASE.md`. Filled in via
> `/codebase-survey-module <path>`.

## Top-Level Layout
<bulleted list from the structural-discovery report's "Top-Level Layout"
section, lightly rephrased>

## Cross-Cutting Docs
- Architecture: `docs/codebase/architecture.md` — TODO, pending `/codebase-architecture-assessment`
- Tech-stack rationale: `docs/codebase/tech-stack.md` — TODO
- Operations: `docs/codebase/operations.md` — TODO
- Assessment: `docs/codebase/assessment.md` — TODO, pending `/codebase-architecture-assessment`

## Survey Status
- Init: complete (this file)
- Per-module surveys: <list with `[ ]` for each module — `[x]` only after `/codebase-survey-module`>
- Architecture assessment: `[ ]`
- Derived instructions (`CLAUDE.md`): `[ ]`
```

**Per-module `<path>/CODEBASE.md` stubs.** For each module in the map (skip if
single-module repo):

```markdown
---
surveyed_sha: <git SHA at init, or "(no git)">
surveyed_at: <YYYY-MM-DD>
survey_schema: 1
---

# <module name>

> Stub. Fill in via `/codebase-survey-module <path>`.

## Purpose
<one-line hint from the map; copy verbatim>

## Functional Requirements
TODO

## Non-Functional Requirements
TODO

## Dependencies
### Inbound
TODO
### Outbound
TODO

## API Surface
TODO

## Architectural Deviations
TODO

## Testing
TODO

## Operations
TODO

## Open Questions
TODO
```

Also create the `docs/codebase/` directory with empty stubs:

- `docs/codebase/architecture.md` — `# Architecture\n\nTODO. Populated by /codebase-architecture-assessment.`
- `docs/codebase/tech-stack.md` — `# Tech Stack\n\nTODO.`
- `docs/codebase/operations.md` — `# Operations\n\nTODO.`
- `docs/codebase/assessment.md` — `# Assessment\n\nTODO. Populated by /codebase-architecture-assessment.`

Each carries the same front-matter (`surveyed_sha`, `surveyed_at`, `survey_schema: 1`).

### Step 6: Hand off

Report:

- The list of module stubs created.
- The next step: run `/codebase-survey-module <path>` for each module to fill
  it in. (For a long module list, mention that an outer
  `/implementation-cycle`-style loop can drive the burndown if the user prefers.)
- Then `/codebase-architecture-assessment` (cross-cutting pass), then
  `/codebase-derive-instructions` to produce `CLAUDE.md`.

Do **not** commit. The user reviews and runs `/commit` when ready.

## Important Principles

- **Synthesis stays in the main session.** Module identification is a judgment
  call — workspace member ≠ semantic module 1:1, and only the orchestrator can
  reconcile structural signal with project context. Subagents return raw signals;
  you decide what counts as a module.
- **Idempotent only on a fresh repo.** This skill is a *bootstrap*. To refresh
  an existing survey, use `/codebase-survey-update` instead.
- **No deep reads.** Init does not open source files. It opens manifests and
  the README excerpt, period. The next phase (`/codebase-survey-module`) is
  where source-level detail comes in.
- **Confirm before writing.** A wrong module map at init wastes hours later.
  When in doubt, ask. Skip the confirmation only when the user explicitly opts out.
- **No commit.** This skill never invokes git outside `rev-parse` / `log`.
