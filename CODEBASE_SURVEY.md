# Skill Family: Codebase Survey

A family of skills for surveying and documenting an existing codebase, designed for both human and AI consumption. Delegates heavy work to subagents that prefer native project tooling (`cargo`, `npm`, `pytest`, etc.) for deterministic, token-efficient output. Documentation is placed module-locally so partial loading works.

## Skill Family

Five narrow skills (multiple narrow skills > one mega-skill). Only the entry points are user-only (`disable-model-invocation: true`); the workhorse skills stay model-invocable so an outer orchestrator (e.g., an `/implementation-cycle`-style loop) can drive them:

1. **`/codebase-survey-init`** — *user-only*. One-time bootstrap. Delegates raw discovery (build tools, languages, manifests, workspace declarations, top-level layout) to the **structural-discovery** subagent, then *the main session* synthesizes the module map from those signals — optionally with user confirmation — and writes the top-level `CODEBASE.md` plus per-module stubs. Boundary identification stays out of the subagent because it's a judgment call, not extraction.
2. **`/codebase-survey-module <path>`** — *model-invocable*. Deep-dive into one module. Spawns 2–3 specialized subagents (see below) in parallel, then assembles the module's `CODEBASE.md`. Idempotent — re-running rewrites the file. Model-invocable so a burndown orchestrator can iterate it across modules.
3. **`/codebase-architecture-assessment`** — *user-only*. Cross-cutting pass after modules are documented: domain-boundary leaks, coupling hotspots, deviations between stated and actual architecture. Writes to `docs/codebase/assessment.md`.
4. **`/codebase-survey-update [commit-range|PR#]`** — *model-invocable*. Incremental refresh. Argument is optional: with no argument, each module is diffed from its own recorded `surveyed_sha` (see below) to `HEAD`; with an argument, that range is used uniformly. Reads the diff, maps changed paths to affected module docs, dispatches narrowly-scoped subagents to only those modules, then bumps each touched module's `surveyed_sha`. Model-invocable so it can be wired to a post-merge hook later.
5. **`/codebase-derive-instructions`** — *user-only*. Reads the assembled docs and produces/updates `CLAUDE.md` (root + per-module if warranted) with conventions, gotchas, build/test commands actually used.

## Subagents (Delegation Layer)

Each subagent has a tight remit and is told which native tools to prefer. Returns a structured report, not free-form prose. Skips cleanly and reports when a tool is missing.

- **structural-discovery** — `find`/`fd` for manifests (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `pom.xml`, `*.csproj`, `Gemfile`, `mix.exs`, …), reads them, reports raw signals: manifest paths + key fields, workspace member declarations (Cargo `[workspace]`, pnpm `workspaces`, Go `go.work`), top-level `src/` layout, language mix. *Does not infer the module map* — leaves that synthesis to the orchestrating skill.
- **dep-grapher** — runs `cargo tree`, `npm ls --depth=0`, `pip-deptree`, `go mod graph`, `mvn dependency:tree`, etc. Produces inbound/outbound dependency lists per module.
- **api-surface-extractor** — language-aware: `cargo public-api`, `tsc --emitDeclarationOnly`, `pdoc`, `go doc ./...`. Falls back to grepping exported symbols when no tool is available.
- **test-auditor** — runs the project's test/coverage tooling (`pytest --collect-only`, `cargo test --list`, `vitest --reporter=json`, `nyc`, `go test -list`), counts unit vs integration vs e2e by directory convention, reports test-pyramid shape and coverage if available.
- **ops-detective** — scans `.github/workflows`, `.gitlab-ci.yml`, `Dockerfile*`, `docker-compose*`, `k8s/`, `helm/`, `terraform/`, `.env.example`, secret-management hints, observability configs (OTel, Sentry, Datadog), logging libs.

The orchestrating skill spawns these in parallel, collects their reports, and writes the final markdown — so the main session never sees raw `cargo tree` output.

## Documentation Structure

Module-local placement so partial loading works naturally:

```
<repo>/
├── CODEBASE.md                 # high-level: architecture, module map, tech stack, links
├── docs/codebase/
│   ├── architecture.md         # detailed system design + diagrams
│   ├── tech-stack.md           # language/framework/library/db rationale
│   ├── operations.md           # CI/CD, deploys, secrets, observability
│   └── assessment.md           # findings from architecture-assessment
└── <module>/
    └── CODEBASE.md             # module: features, NFRs, deps, API, tests, deviations, ops
```

Module file uses a fixed section template (so the update skill knows what to refresh):

```
---
surveyed_sha: <git SHA at last survey>
surveyed_at: <ISO date>
survey_schema: 1
---
# Purpose
# Functional Requirements
# Non-Functional Requirements
# Dependencies (Inbound / Outbound)
# API Surface
# Architectural Deviations
# Testing
# Operations
# Open Questions
```

The same front-matter keys appear on the top-level `CODEBASE.md` and `docs/codebase/*.md`. `survey_schema` lets a future update skill detect template drift and trigger a regeneration rather than a patch. `surveyed_sha` is per-file so update can compute path-scoped diffs (`git diff <module-sha>..HEAD -- <module-path>`) instead of one global range.

Filename `CODEBASE.md` (not `README.md`) so we don't fight existing human-facing READMEs. The name signals "AI-consumable codebase doc" without overloading conventions.

## Process

1. **Bootstrap** — `/codebase-survey-init` (once).
2. **Module burndown** — iterate `/codebase-survey-module <path>` per identified module. Can be parallelized via an `/implementation-cycle`-style outer loop.
3. **Cross-cut** — `/codebase-architecture-assessment`.
4. **Derive instructions** — `/codebase-derive-instructions` produces `CLAUDE.md`.
5. **Steady state** — `/codebase-survey-update <ref>` after notable merges; could be wired to a hook later if automation is wanted.

## Open Tradeoffs

- **Module-local vs. centralized docs.** Local matches Claude Code's CLAUDE.md loading model and keeps docs near code; centralized (mirror under `docs/codebase/<module>/`) is easier to read as one document.
- **`CODEBASE.md` filename.** Could be `ARCHITECTURE.md`, `.codebase.md`, or `docs/CODEBASE.md`. Pick early — the update skill greps for it.
- **Module identification heuristic.** Default: workspace members (Cargo/pnpm/yarn workspaces), top-level packages, or top-level directories with their own manifest. Monoliths without clear boundaries need a fallback (e.g., top-level dirs in `src/`). Could make module boundaries human-confirmed in `init` rather than auto-detected.
- **Scope of `derive-instructions`.** Overwrite existing `CLAUDE.md`, append, or produce a diff for review? Default proposed: write `CLAUDE.md.proposed` and let the user merge.
- **Five skills vs. fewer.** Could collapse `architecture-assessment` into `init` and `derive-instructions` into `update`, leaving three. The five-skill split mirrors research-workflow granularity — useful if assessments need to be re-run without redoing surveys.

## Suggested First Slice

`/codebase-survey-init` + the **structural-discovery** subagent — smallest viable slice that produces a usable artifact (root `CODEBASE.md` with module map and tech stack).
