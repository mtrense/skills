# Skill Family: Codebase Survey

A family of skills for surveying and documenting an existing codebase, designed for both human and AI consumption. Delegates heavy work to subagents that prefer native project tooling (`cargo`, `npm`, `pytest`, etc.) for deterministic, token-efficient output. Documentation is placed module-locally so partial loading works.

## Skill Family

Five narrow skills (multiple narrow skills > one mega-skill). Only the entry points are user-only (`disable-model-invocation: true`); the workhorse skills stay model-invocable so an outer orchestrator (e.g., an `/implementation-cycle`-style loop) can drive them:

1. **`/codebase-survey-init`** — *user-only*. One-time bootstrap. Delegates raw discovery (build tools, languages, manifests, workspace declarations, top-level layout) to the **structural-discovery** subagent, then *the main session* synthesizes the module map from those signals — optionally with user confirmation — and writes the top-level `CODEBASE.md` plus per-module stubs. Boundary identification stays out of the subagent because it's a judgment call, not extraction.
2. **`/codebase-survey-module <path>`** — *model-invocable*. Deep-dive into one module. Spawns 2–3 specialized subagents (see below) in parallel, then assembles the module's `CODEBASE.md`. Idempotent — re-running rewrites the file. Model-invocable so a burndown orchestrator can iterate it across modules.
3. **`/codebase-architecture-assessment`** — *user-only*. Cross-cutting pass after modules are documented: domain-boundary leaks, coupling hotspots, deviations between stated and actual architecture. Writes to `docs/codebase/assessment.md`.
4. **`/codebase-survey-update [commit-range|PR#]`** — *model-invocable*. Incremental refresh. Argument is optional: with no argument, each module is diffed from its own recorded `surveyed_sha` (see below) to `HEAD`; with an argument, that range is used uniformly. Reads the diff, maps changed paths to affected module docs, dispatches narrowly-scoped subagents to only those modules, then bumps each touched module's `surveyed_sha`. Model-invocable so it can be wired to a post-merge hook later.
5. **`/codebase-derive-instructions`** — *user-only*. Reads the assembled survey docs and writes/updates `CLAUDE.md` at the repo root and one per module (mirroring the `CODEBASE.md` placement). Lean, verifiable, source-anchored. See **Derive-Instructions Requirements** below.

## Subagents (Delegation Layer)

Each subagent has a tight remit and is told which native tools to prefer. Returns a structured report, not free-form prose. Skips cleanly and reports when a tool is missing.

- **structural-discovery** — `find`/`fd` for manifests (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `pom.xml`, `*.csproj`, `Gemfile`, `mix.exs`, …), reads them, reports raw signals: manifest paths + key fields, workspace member declarations (Cargo `[workspace]`, pnpm `workspaces`, Go `go.work`), top-level `src/` layout, language mix. *Does not infer the module map* — leaves that synthesis to the orchestrating skill.
- **dep-grapher** — runs `cargo tree`, `npm ls --depth=0`, `pip-deptree`, `go mod graph`, `mvn dependency:tree`, etc. Produces inbound/outbound dependency lists per module.
- **api-surface-extractor** — language-aware: `cargo public-api`, `tsc --emitDeclarationOnly`, `pdoc`, `go doc ./...`. Falls back to grepping exported symbols when no tool is available.
- **wire-api-extractor** — external/network API layers, distinct from the language-level surface above. Prefers spec artifacts and framework introspection: OpenAPI/Swagger (`/openapi.json` from FastAPI, NestJS, Spring; `swagger-cli bundle`), gRPC (`buf ls-files`, `.proto` service/method enumeration), GraphQL (`.graphql` schemas, introspection), AsyncAPI (`.asyncapi.yml`), message-broker topic/queue configs. Falls back to grepping route registrations (`@app.route`, `@RestController`, `app.get`, `http.HandleFunc`, `gin.GET`, etc.). Reports protocol, endpoint/topic list, auth scheme hints, and where the contract lives (generated vs. hand-written).
- **test-auditor** — runs the project's test/coverage tooling (`pytest --collect-only`, `cargo test --list`, `vitest --reporter=json`, `nyc`, `go test -list`), counts unit vs integration vs e2e by directory convention, reports test-pyramid shape and coverage if available.
- **ops-detective** — scans `.github/workflows`, `.gitlab-ci.yml`, `Dockerfile*`, `docker-compose*`, `k8s/`, `helm/`, `terraform/`, `.env.example`, secret-management hints, observability configs (OTel, Sentry, Datadog), logging libs.

The architecture-assessment skill must tag each finding it writes to `docs/codebase/assessment.md` with a `kind:` field — either `rule` (actionable always/never guidance) or `observation` (backlog, debt, "we should fix"). `derive-instructions` only lifts `kind: rule` findings into the root CLAUDE.md.

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

## Derive-Instructions Requirements

Grounded in Anthropic's official memory docs, HumanLayer's CLAUDE.md guidance, and GitHub's empirical study of 2,500+ AGENTS.md files. The skill consumes structured survey output, so it can be more mechanical and source-anchored than a hand-written CLAUDE.md.

### Output layout

- **Root** `./CLAUDE.md` — loaded at every session start.
- **Per-module** `<module>/CLAUDE.md` — mirrors `<module>/CODEBASE.md`. Loaded lazily by Claude Code when it reads files in that subtree.
- User-level (`~/.claude/CLAUDE.md`) is out of scope.
- If `AGENTS.md` exists at repo root, derive into `AGENTS.md` instead and write a thin `CLAUDE.md` that does `@AGENTS.md` plus a `## Claude Code` section for Claude-specific addenda. (Anthropic's documented interop pattern.)

### Length and budget

- Root CLAUDE.md: target **≤ 200 lines** (Anthropic's stated adherence threshold).
- Per-module CLAUDE.md: target **≤ 80 lines**.
- Total launch-context bytes (root + everything its `@imports` expand) must fit comfortably under ~10 KB.
- Total instruction count across all loaded files should stay well under ~150 (frontier-model adherence ceiling).

### Root CLAUDE.md template (fixed sections, fixed order)

1. **Project identity** — 1–2 lines, plus `@README.md` and `@CODEBASE.md` imports.
2. **Build & test commands** — verbatim, with HTML-comment source pointer per command.
3. **Where things live** — one-line module map; link to `@CODEBASE.md` for detail.
4. **Boundaries** — three subsections: `Always`, `Ask first`, `Never`. Sourced from `kind: rule` findings in `docs/codebase/assessment.md`. Findings tagged `kind: observation` are excluded.
5. **Git workflow** — only if non-default; otherwise omit.
6. **Pointers** — `@docs/codebase/architecture.md`, `@docs/codebase/operations.md`, etc., for on-demand reads.

### Per-module CLAUDE.md template

- Module-specific commands (if any beyond the root set).
- **Boundaries** — pulled verbatim from that module's `Architectural Deviations` section.
- Pointer to `@<module>/CODEBASE.md`.

### Content discipline

| Survey input | Derived? | Notes |
|---|---|---|
| Build/test commands (manifests, CI) | Yes, verbatim | Highest signal, universally applicable |
| Project map / module boundaries | Pointer only | Don't duplicate `CODEBASE.md` |
| Tech stack rationale | No | Lives in `docs/codebase/tech-stack.md` |
| Architectural Deviations (per-module) | Yes, as module Boundaries | Exactly the gotchas CLAUDE.md exists for |
| Assessment findings | Only `kind: rule` | `kind: observation` stays in assessment.md |
| Open Questions | No | Not yet decided → not a rule |
| Code style | No | Linter's job; point at lint config instead |
| API surface | No | Discoverable on demand |
| Operations / secrets | Only "always do X before commit" subset | Rest stays in `docs/codebase/operations.md` |

### Source anchoring

Every derived rule carries a block-level HTML comment naming its source and the surveyed SHA, e.g. `<!-- from: package.json scripts.test, surveyed_sha=abc123 -->`. Anthropic strips these before context injection (zero token cost) but the survey-update skill can grep them to detect when a derived rule's source has moved.

### Front-matter

Both root and per-module CLAUDE.md carry:

```
---
derived_from_survey_sha: <git SHA of CODEBASE.md sources at derivation>
derived_at: <ISO date>
derive_schema: 1
---
```

`/codebase-survey-update` uses these to detect when re-derivation is needed.

### Verification before write

- All `@imports` resolve to existing files.
- Total expanded launch-context size under threshold (warn otherwise).
- No rule textually duplicates content already in the corresponding `CODEBASE.md` (similarity check; warn).
- Code-style heuristic scan: matches against "spaces", "indentation", "camelCase", "naming convention", etc. → flag for human review (these usually shouldn't be in CLAUDE.md).

### Write strategy

In-place write to `CLAUDE.md` (and per-module files). Review happens via `git diff` / PR — the skill never produces `.proposed` sidecars. Idempotent: re-running with unchanged sources is a no-op (modulo `derived_at`).

### Lifecycle

Re-runs after every meaningful `/codebase-survey-update`. The `derived_from_survey_sha` front-matter lets the update skill detect drift between CLAUDE.md and the CODEBASE.md sources it was derived from.

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
- **Five skills vs. fewer.** Could collapse `architecture-assessment` into `init` and `derive-instructions` into `update`, leaving three. The five-skill split mirrors research-workflow granularity — useful if assessments need to be re-run without redoing surveys.

## Suggested First Slice

`/codebase-survey-init` + the **structural-discovery** subagent — smallest viable slice that produces a usable artifact (root `CODEBASE.md` with module map and tech stack).
