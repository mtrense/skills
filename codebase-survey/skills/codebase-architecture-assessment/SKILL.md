---
name: codebase-architecture-assessment
description: >
  Cross-cutting architecture pass after per-module surveys are complete. Reads
  every <module>/CODEBASE.md and the top-level CODEBASE.md, looks for domain-
  boundary leaks, coupling hotspots, deviations between stated and actual
  architecture, and stack inconsistencies. Writes findings to
  docs/codebase/assessment.md with each finding tagged kind:rule or
  kind:observation, and synthesises docs/codebase/architecture.md,
  tech-stack.md, and operations.md from the same inputs. Run after the module
  burndown, before /codebase-derive-instructions.
disable-model-invocation: true
argument-hint: "(no arguments)"
model: opus
allowed-tools: Read, Write, Glob, Grep, Edit, Agent, Bash(git rev-parse:*), Bash(git log:*)
---

# Codebase Architecture Assessment

You are doing a cross-cutting architecture pass over a surveyed codebase.
Per-module surveys are local; this skill produces the **global** view they
cannot: where modules leak into each other, where the stated architecture
and the actual code diverge, and where coupling concentrates.

This skill writes **all four** files in `docs/codebase/`:

- `assessment.md` — the cross-cutting findings (rules + observations).
- `architecture.md` — narrative system description synthesised from the surveys.
- `tech-stack.md` — languages / frameworks / libraries / DBs roll-up.
- `operations.md` — repo-level CI/CD, deploy, secrets, observability.

Every finding in `assessment.md` is tagged `kind: rule` or `kind: observation`.
The distinction matters because `/codebase-derive-instructions` only lifts
`kind: rule` findings into `CLAUDE.md`. Observations stay in this file.

The other three files (`architecture.md`, `tech-stack.md`, `operations.md`)
are descriptive, not normative — they exist to be `@import`-ed on demand by
the lean root `CLAUDE.md`.

## Authorship marker (`generated_by`)

Each of the four files carries front-matter. To distinguish agent-written
content from human-authored "stated architecture", every file written or
overwritten by this skill includes:

```yaml
generated_by: codebase-architecture-assessment
```

Files written by `/codebase-survey-init` carry
`generated_by: codebase-survey-init (stub)`. Files **without** any
`generated_by` field are treated as human-authored stated architecture and
must not be silently overwritten — see Step 1.

## Prerequisites

1. Top-level `CODEBASE.md` exists.
2. At least one module has been surveyed via `/codebase-survey-module` —
   ideally most or all listed in the module map.
3. `docs/codebase/assessment.md` either does not exist or is the stub
   created by `/codebase-survey-init`.

If many modules are still `[ ]` in the top-level survey status, ask the user
whether to proceed (assessment quality scales with survey coverage) or wait.

## Phase Workflow

### Step 1: Gather inputs and classify the four target files

- Read `CODEBASE.md` (top-level) — the module map and tech stack.
- Read every `<module>/CODEBASE.md` listed in the map. Build a mental index:
  what each module's purpose is, its outbound deps, its API surface, its
  declared deviations.
- Read any project README, `ARCHITECTURE.md`, or similar at the repo root.
  These are the project's own claims about itself.
- Capture `git rev-parse HEAD` for the front-matter.

For each of `docs/codebase/{architecture,tech-stack,operations,assessment}.md`,
inspect its front-matter and body and assign one of three states:

| State | Detection | This skill's behaviour |
|---|---|---|
| **stub** | front-matter has `generated_by: codebase-survey-init (stub)`, OR body is a single `# Heading\n\nTODO…` placeholder | overwrite freely |
| **prior agent output** | front-matter has `generated_by: codebase-architecture-assessment` | overwrite freely (this is a re-run) |
| **human-authored stated content** | non-trivial body **without** any `generated_by` field | **do not overwrite**; treat the body as the project's stated architecture and source claims from it for the *stated-vs-actual* findings (§ 2c) |

If the file exists in some other shape (e.g. front-matter present but body
is empty, or `generated_by` value is unrecognised), surface to the user and
ask before overwriting.

Record this classification per file — you will reuse it in Steps 5–8 to
decide which files to write.

### Step 2: Look for the right kinds of findings

Run several focused passes. Each pass has a different attention mode.

#### 2a. Domain-boundary leaks
Compare the inbound/outbound dependency lists across modules. A leak looks
like:

- A high-level module depending on what should be a leaf utility (inverted
  dependency — find via dep-grapher's directionality).
- Two modules that the map presents as siblings but that import each other's
  internals (cross-module imports of non-public symbols — surface from each
  module's `Architectural Deviations`).
- A module's outbound list naming a peer module that the peer's inbound
  list doesn't acknowledge — i.e., one module knows about another, the other
  doesn't expect to be known.

#### 2b. Coupling hotspots
Identify modules with disproportionate inbound or outbound counts. A module
imported by every other module is either an obvious shared core (legitimate)
or an over-broad dumping ground (problematic). The numbers alone don't
distinguish them — read the module's purpose and judge.

#### 2c. Stated-vs-actual deviations
For every claim made in the README or any `docs/codebase/*` file
classified as **human-authored stated content** in Step 1, check whether
the per-module surveys agree:

- "We follow hexagonal architecture" but no module surfaces a port/adapter
  distinction.
- "All HTTP traffic goes through the gateway" but two modules expose their
  own HTTP listeners (per wire-api reports).
- "We use OpenAPI for all REST" but one module's wire-api report says
  `code-only`.
- "Strict TDD" but the module test pyramid is mostly e2e.

These divergences are the single most useful output of this skill.

Do **not** mine claims from files classified as **stub** or **prior agent
output** — the former has none, the latter would compare the assessment
against its own previous output.

#### 2d. Tech-stack inconsistencies
- Multiple JSON parsers, HTTP clients, logging libraries, ORMs across
  modules where one would do.
- Two modules in the same language using different test runners without a
  documented reason.
- Modules expressing the same external dependency at incompatible versions.

#### 2e. Test-pyramid asymmetries
- A critical module (high inbound count) with no integration tests.
- A leaf module with extensive e2e tests but no unit tests.
- Coverage gaps reported by `test-auditor` on modules whose deviations call
  for more rigour.

#### 2f. Operational inconsistencies
- Some modules ship with Dockerfiles, others don't, with no apparent
  rationale.
- Observability (logging libs, error trackers) mixed across modules.
- Health endpoints on some HTTP modules, not on others.

### Step 3: Run ops-detective at repo level

Spawn the **ops-detective** subagent on the repo root via the `Agent` tool.
This is mandatory — it produces the input for `operations.md` (Step 8) and
also feeds the operational-inconsistency findings (§ 2f). Self-contained
prompt:

```
You are running for the codebase-architecture-assessment skill. Inventory
the operational machinery for the repository at <absolute repo path>:
CI/CD, container builds, deploy manifests, secrets handling, observability
hooks, logging libraries. Follow your standard report format. Do not run
or deploy anything — read only.
```

If `operations.md` was classified as **human-authored stated content** in
Step 1, you still run ops-detective (you need its output for findings) but
skip the `operations.md` write in Step 8.

### Step 4: Tag every finding

For each finding you write, decide:

- **`kind: rule`** — actionable always/never guidance. Phrased as imperative
  ("Always X", "Never Y", "Ask before Z"). Source-anchorable to a specific
  module, file, or pattern. Likely to apply on every future task that
  touches the area. Examples: "Never call `internal/db.RawQuery` directly
  from feature modules — go through `repo.*`."; "Always emit traces with
  the `tenant_id` baggage when crossing the gateway."

- **`kind: observation`** — a finding that's interesting but not a rule for
  a future agent to follow. Backlog material. Phrased as a description, not
  an imperative. Examples: "The `payments` module has 4× the average
  outbound count, suggesting it's outgrowing its remit."; "Two modules
  parse YAML with different libraries (`yaml` and `js-yaml`) — worth
  unifying."

If a finding could be either, prefer `observation` — `derive-instructions`
will only lift `rule` findings into `CLAUDE.md`, and a permissive rule
threshold inflates the prompt without payoff.

### Step 5: Write `assessment.md`

Replace the file's body with:

```markdown
---
surveyed_sha: <SHA>
surveyed_at: <YYYY-MM-DD>
survey_schema: 1
generated_by: codebase-architecture-assessment
---

# Architecture Assessment

> Cross-cutting findings from a pass over `CODEBASE.md` files.
> Each finding is tagged `kind: rule` (lifts into `CLAUDE.md`) or
> `kind: observation` (stays here).

## Summary
- Modules read: <N>
- Findings (rule): <count>
- Findings (observation): <count>
- Most-affected module: <module path with highest finding count, or "(spread evenly)">

## Findings

### F-001: <short title>
- **kind**: rule | observation
- **scope**: repo | module:<path> | <module-a>↔<module-b>
- **evidence**: <verbatim or near-verbatim quote / numbers from the source
  surveys, with paths so a reader can verify>
- **finding**: <one or two sentences. For rules, phrase as imperative.>
- **suggested-action**: <optional — what to do about it. For observations,
  this is "consider"-grade. For rules, restate in the imperative.>

### F-002: ...

(Continue numbering. Group by scope if useful — ungrouped is fine for ≤ 20
findings.)

## Coverage Notes
- Modules surveyed: <list>
- Modules **not** surveyed (assessment may be incomplete): <list, or "(none)">
- Subagent fallbacks reported in surveys: <count, with module paths if ≤ 5>

## Method
This assessment was produced by `/codebase-architecture-assessment` on
<date>. Re-run after significant module changes; `/codebase-survey-update`
will flag when a module's `CODEBASE.md` falls out of sync with this file.
```

Skip this write only if the user explicitly opted out — `assessment.md` is
this skill's primary artifact.

### Step 6: Write `architecture.md`

Skip this step if `architecture.md` was classified **human-authored stated
content** in Step 1; otherwise replace the body with the template below.
Synthesise content from the per-module Purpose / Dependencies / API Surface
sections plus the cross-cutting findings just produced — you already have
all of this in context.

```markdown
---
surveyed_sha: <SHA>
surveyed_at: <YYYY-MM-DD>
survey_schema: 1
generated_by: codebase-architecture-assessment
---

# Architecture

> Synthesised narrative description of the system. Drawn from per-module
> `CODEBASE.md` files and the cross-cutting findings in `assessment.md`.
> Source of truth for individual module specifics is each
> `<module>/CODEBASE.md`; this file is the connective tissue.

## System Overview
<2–4 paragraphs: kind of system (service / library / monorepo / CLI / web
app), overall topology, primary data-flow / request-flow paths, the chief
external integrations. Drawn from each module's Purpose + the top-level
CODEBASE.md Project at a Glance.>

## Module Topology
<One short paragraph per module — what it does, what it depends on, what
depends on it. Reference back to the module map in CODEBASE.md rather than
duplicating it. Group modules by layer/role when one is evident (e.g.,
"Edge layer", "Domain layer", "Persistence").>

## Cross-Cutting Patterns
<Recurring patterns across modules: e.g. middleware chains, error-handling
conventions, persistence access patterns, message-passing conventions.
Drawn from coupling-hotspot and tech-stack findings.>

## Notable Divergences
<Stated-vs-actual deviations, summarised in one line each with a pointer
back to the corresponding F-### finding in `assessment.md` for evidence.
Skip this section entirely if the project has no stated architecture
document and § 2c produced no findings.>
```

### Step 7: Write `tech-stack.md`

Skip this step if `tech-stack.md` was classified **human-authored stated
content** in Step 1; otherwise replace the body with the template below.
Synthesise content from each module's Outbound Dependencies and the
top-level CODEBASE.md Tech Stack section.

```markdown
---
surveyed_sha: <SHA>
surveyed_at: <YYYY-MM-DD>
survey_schema: 1
generated_by: codebase-architecture-assessment
---

# Tech Stack

> Languages, frameworks, libraries, datastores, and tooling used by this
> codebase, and where each shows up. Inferred from per-module outbound
> dependency lists; rationale is *not* always recoverable without project
> history.

## Languages
| Language | Primary modules | Share (from CODEBASE.md) |
|---|---|---|
| <language> | <module list> | <%> |

## Frameworks & Major Libraries
| Library / framework | Used by | Role |
|---|---|---|
| <name> | <module list> | <e.g., HTTP server, ORM, validation> |

## Persistence & Data Stores
<DBs, caches, search engines; ORMs / query builders; which modules use
which.>

## External Services
<Third-party APIs the code calls — service name + which module owns the
client. Pulled from outbound dependency lists and wire-api reports.>

## Build & Tooling
<Package managers, build tools, test runners, linters, formatters. One
line each. Pulled from manifests via the structural-discovery report and
each module's CODEBASE.md.>

## Notable Inconsistencies
<Tech-stack-related findings from `assessment.md` (§ 2d), one line each
with a pointer to the F-### finding for evidence. Omit this section if
none.>
```

### Step 8: Write `operations.md`

Skip this step if `operations.md` was classified **human-authored stated
content** in Step 1; otherwise replace the body with the template below.
Use the **ops-detective** report from Step 3 as the source for the
repo-level sections, and roll up each module's Operations section under
"Per-Module Operations".

```markdown
---
surveyed_sha: <SHA>
surveyed_at: <YYYY-MM-DD>
survey_schema: 1
generated_by: codebase-architecture-assessment
---

# Operations

> CI/CD, container builds, deploy manifests, secrets handling, and
> observability — at the repo level, plus per-module roll-ups.
> Inventory only; no maturity judgment.

## CI / CD
<from ops-detective; one bullet per pipeline file with system, triggers,
job names, deploy hints>

## Containers & Build
<Dockerfiles + base images, compose services, top-level Make/Just/Task
targets>

## Deploy Manifests
<Kubernetes / Helm / Terraform / Pulumi / Serverless / SAM / etc., with
counts and locations>

## Configuration & Secrets
<.env.example variable names; presence of real .env files; secret-management
tools detected; CI secret references>

## Observability
<Tracing / metrics / errors / APM / logging libraries / health endpoints —
each line names the tool and where it's wired in>

## Per-Module Operations
| Module | Notable ops content from `<module>/CODEBASE.md` Operations |
|---|---|
| <module> | <one-line summary or "(none)"> |
```

### Step 9: Refresh the top-level status

Update `CODEBASE.md`'s `Cross-Cutting Docs` and `Survey Status` sections:

- Replace each `TODO, pending /codebase-architecture-assessment` line in
  `Cross-Cutting Docs` with the actual status — "populated" if the file
  was written this run, "(human-authored, preserved)" if it was skipped
  per Step 1's classification.
- Tick `Architecture assessment: [x]` in `Survey Status`.

Do not modify other lines.

### Step 10: Hand off

Report:

- The four file paths and what happened to each: `written` / `skipped
  (human-authored)` / `skipped (user opted out)`.
- For `assessment.md`: counts (rule vs observation).
- The two or three most consequential findings, in one line each — enough
  for the user to decide whether to act on them now or defer.
- The next step: `/codebase-derive-instructions` to lift `kind: rule`
  findings into `CLAUDE.md`.

Do **not** commit.

## Important Principles

- **Cross-cutting only in `assessment.md`.** If a finding belongs in a
  single module's `Architectural Deviations`, it's not for this file —
  it's already in the module survey.
- **Numbers matter.** Coupling and pyramid claims must be backed by counts
  from the per-module surveys, not impressions. The reader will trust the
  finding if they can re-derive it.
- **Bias toward observations.** Rules pollute `CLAUDE.md`. Tag `rule` only
  when an instructed AI would behave wrong without it. When in doubt, tag
  `observation`.
- **Source-anchor everything.** Every finding should cite either a module
  path, a `CODEBASE.md` section, or a file/line. Findings without anchors
  are unverifiable and decay fast.
- **Honest coverage.** If only half the modules are surveyed, say so in
  Coverage Notes — partial assessments are still valuable, but their gaps
  must be visible.
- **Do not overwrite human content.** Files that lack a `generated_by`
  field but contain real prose are stated architecture written by a
  human. Read them as input; do not rewrite them.
- **Re-runs are safe.** All four files carry
  `generated_by: codebase-architecture-assessment` after a write, so the
  next run recognises them as prior agent output and overwrites cleanly.
