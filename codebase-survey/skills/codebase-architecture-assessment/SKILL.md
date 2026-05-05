---
name: codebase-architecture-assessment
description: >
  Cross-cutting architecture pass after per-module surveys are complete. Reads
  every <module>/CODEBASE.md and the top-level CODEBASE.md, looks for domain-
  boundary leaks, coupling hotspots, deviations between stated and actual
  architecture, and stack inconsistencies. Writes findings to
  docs/codebase/assessment.md with each finding tagged kind:rule or
  kind:observation. Run after the module burndown, before
  /codebase-derive-instructions.
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

You write to `docs/codebase/assessment.md`. Every finding is tagged
`kind: rule` or `kind: observation`. The distinction matters because
`/codebase-derive-instructions` only lifts `kind: rule` findings into
`CLAUDE.md`. Observations stay in this file.

## Prerequisites

1. Top-level `CODEBASE.md` exists.
2. At least one module has been surveyed via `/codebase-survey-module` —
   ideally most or all listed in the module map.
3. `docs/codebase/assessment.md` either does not exist or is the stub
   created by `/codebase-survey-init`.

If many modules are still `[ ]` in the top-level survey status, ask the user
whether to proceed (assessment quality scales with survey coverage) or wait.

## Phase Workflow

### Step 1: Gather inputs

- Read `CODEBASE.md` (top-level) — the module map and tech stack.
- Read every `<module>/CODEBASE.md` listed in the map. Build a mental index:
  what each module's purpose is, its outbound deps, its API surface, its
  declared deviations.
- Read `docs/codebase/architecture.md`, `docs/codebase/tech-stack.md`,
  `docs/codebase/operations.md`. These may be stubs — that's fine, but if
  they have content, treat it as the *stated* architecture.
- Read any project README, ARCHITECTURE.md, or similar at the repo root.
  These are the project's own claims about itself.
- Capture `git rev-parse HEAD` for the front-matter.

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
For every claim made in the README or `docs/codebase/*` about how the system
is structured, check whether the per-module surveys agree:

- "We follow hexagonal architecture" but no module surfaces a port/adapter
  distinction.
- "All HTTP traffic goes through the gateway" but two modules expose their
  own HTTP listeners (per wire-api reports).
- "We use OpenAPI for all REST" but one module's wire-api report says
  `code-only`.
- "Strict TDD" but the module test pyramid is mostly e2e.

These divergences are the single most useful output of this skill.

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

### Step 3: Optionally rerun ops-detective at repo level

If `docs/codebase/operations.md` is still a stub and you want global ops
findings, spawn the **ops-detective** subagent on the repo root via the
`Agent` tool. Feed its output into the relevant findings *and* into a
populated `docs/codebase/operations.md` (replace its TODO body with the
report's structured sections). This step is optional — skip when ops is
already documented.

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

### Step 5: Write assessment.md

Replace the file's body with:

```markdown
---
surveyed_sha: <SHA>
surveyed_at: <YYYY-MM-DD>
survey_schema: 1
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

### Step 6: Refresh the top-level status

Update `CODEBASE.md`'s Survey Status checklist: tick `Architecture
assessment`. Do not modify other lines.

### Step 7: Hand off

Report:

- Path: `docs/codebase/assessment.md`.
- Counts (rule vs observation).
- The two or three most consequential findings, in one line each — enough for
  the user to decide whether to act on them now or defer.
- The next step: `/codebase-derive-instructions` to lift `kind: rule`
  findings into `CLAUDE.md`.

Do **not** commit.

## Important Principles

- **Cross-cutting only.** If a finding belongs in a single module's
  `Architectural Deviations`, it's not for this file — it's already in the
  module survey.
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
