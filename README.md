# Claude Code Skills

A collection of prompt-based skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that add structured workflows for software engineering and research.

Skills are markdown files with YAML frontmatter that Claude loads as playbooks. Each skill provides a `/slash-command` — you invoke it, and Claude follows the skill's instructions to guide you through a specific workflow phase.

## Installation

This repo can be installed two ways: as a Claude Code **plugin marketplace** (recommended for end users) or via the legacy symlink installer (recommended for developing/iterating on the skills themselves).

### As a plugin marketplace

The repo root carries a `.claude-plugin/marketplace.json` catalog (`mtrense-skills`). Each workflow family is exposed as a separately-installable plugin with its own `<workflow>/.claude-plugin/plugin.json` manifest.

```shell
/plugin marketplace add mtrense/skills
/plugin install milestone-driven@mtrense-skills
/plugin install research@mtrense-skills
/plugin install codebase-survey@mtrense-skills
/plugin install synaptic-authoring@mtrense-skills
/plugin install common@mtrense-skills
```

Updates: `/plugin marketplace update`. No `version` field is pinned, so each commit on `main` is treated as a new version.

### Via the symlink installer

```bash
# Install every workflow globally (~/.claude/skills/ + ~/.claude/agents/)
./install.sh all

# Install just one workflow globally
./install.sh milestone-driven

# Install one workflow into a specific project
./install.sh research /path/to/project
```

The first argument is the workflow name (`codebase-survey`, `common`, `milestone-driven`, `research`, `synaptic-authoring`) or `all`. The optional second argument is the install target (defaults to `$HOME`). The installer creates symlinks, so skills stay up to date as you pull changes.

## Skills

### Milestone-Driven Workflow

A phased cycle for building software, from idea through implementation to closeout. Each phase produces a specific artifact that feeds into the next. See [`milestone-driven/README.md`](milestone-driven/README.md) for the roadmap file layout and migration instructions for existing projects.

| Phase | Command | What it does | Produces |
|-------|---------|-------------|----------|
| 0 | `/project-inception` | Socratic dialogue to discover project vision and goals | `README.md` |
| 1 | `/strategic-planning` | Sharpen ideas into well-defined, testable milestones | `roadmap/NNNN-slug.md` + `ROADMAP.md` index entry |
| 2 | `/milestone-breakdown` | Decompose a milestone into ordered, independently testable tasks | `PLAN.md` |
| 3 | `/task-implementation` | Implement one task using strict TDD (tests first, then code) | Passing code + tests |
| 3 | `/implementation-cycle` | Run task-implementation + commit in fresh subagents per task, then sync docs/examples to each commit, to keep the main session clean | Passing code + commits + doc commits |
| 3 | `/implementation-cycle-workflow` | **Experimental** workflow-backed twin of `/implementation-cycle` — delegates the per-task loop to the bundled `implementation-cycle` Workflow script so the two orchestration styles can be tested side by side | Passing code + commits + doc commits |
| 4 | `/milestone-closing` | Verify success criteria, document results, reset for next cycle | Updated `roadmap/NNNN-slug.md` + `ROADMAP.md` index |
| - | `/commit` | Craft a conventional commit from staged/unstaged changes | Git commit |

**Typical flow:** `inception` (once) -> `planning` -> `breakdown` -> `implementation` (repeat per task) -> `closing` -> back to `planning`.

The milestone-driven workflow uses four bundled subagents: `milestone-scout` (delegated codebase reconnaissance for `milestone-breakdown`), `task-worker` (per-task `task-implementation` + `commit` worker for `implementation-cycle`), `doc-updater` (per-task documentation/examples sync, spawned by `implementation-cycle` after each task commit — a no-op unless the change is user- or developer-visible), and `decision-lookup` (read-only librarian that returns a compact briefing of the Architecture Decision Records relevant to a topic, so planning/breakdown inherit prior decisions without loading the whole log). All live in `milestone-driven/agents/` and are installed alongside the workflow's skills.

**Decision records.** The decision-making phases record substantial *on-the-way* decisions — ones that split the architecture, commit to a goal, or foreclose an expensive-to-reverse alternative — as Architecture Decision Records under `docs/decisions/`: a full `NNNN-title.md` record (context, decision, rationale, alternatives, consequences) plus a one-sentence line in `docs/decisions/INDEX.md` for quick agent lookup. `project-inception` captures the foundational tech-shape decisions, `strategic-planning` the directional decisions a milestone commits to, and `milestone-breakdown` milestone-level architectural splits; `task-implementation` and `milestone-closing` read the log to stay consistent with it. `/spec-sharpener` runs pre-implementation and writes no ADRs — the sharpened spec is its record — but reads an existing log to avoid re-opening settled decisions.

### Research Workflow

A multi-phase system for building structured knowledge bases with source verification and quality auditing.

| Phase | Command | What it does |
|-------|---------|-------------|
| 1 | `/research-inception` | Create project structure: INDEX.md, DECISIONS.md, glossary, topic stubs |
| - | `/research-add-topic` | Add a new top-level topic (single chapter file or directory with chapter stubs) to an existing project |
| - | `/research-add-chapter` | Add new chapter stubs under any existing directory in the topic tree (any depth) |
| 2 | `/research-inquiry` | Add section outlines with RESEARCH directives to a chapter |
| 2 | `/research-inquiry-cycle` | Batch `research-inquiry-worker` subagents over all `stub` topics; fully parallel within a batch (one topic per worker) |
| 3 | `/research-investigation` | Write content for one section; runs as a forked `research-investigation-worker` subagent (`context: fork`) that drives the web search-fetch-verify loop inline |
| 3 | `/research-investigation-cycle` | Batch `Skill(research-investigation)` invocations over all pending RESEARCH directives; forks run in parallel across distinct topic files within a batch, serial within a topic |
| 4 | `/research-audit-consistency` | Check cross-topic contradictions; insert AUDIT directives |
| 4 | `/research-audit-coverage` | Check gaps relative to the research plan; insert AUDIT directives |
| 4 | `/research-audit-quality` | Check depth and sourcing adequacy; insert AUDIT directives. Fans out per-topic analysis to `quality-auditor` in parallel |
| 4 | `/research-audit-coherence` | Check narrative flow; insert AUDIT directives. Fans out per-topic analysis to `coherence-auditor` in parallel |
| 4 | `/research-audit-topic` | Audit **one topic across every lens** (consistency, coverage, quality, coherence, graphics) in one pass and advance it `draft → audited`; runs as a forked `research-audit-worker` subagent (`context: fork`) that inlines all lens analysis and CONFIDENCE verification |
| 4 | `/research-audit-cycle` | Batch `Skill(research-audit-topic)` invocations over all `draft` topics; forks run in parallel across distinct topics within a batch, lenses serial within a topic. Takes `[max-items][@workers]`; drives topics to `audited`; resumable/idempotent |
| - | `/research-ingest-source` | Ingest a specific source you already have (URL or file): vet it for legitimacy like investigation, then weave it into every existing section it corroborates or contradicts. Delegates the placement scan to `corpus-locator` |
| 5 | `/research-refine` | Resolve audit findings (correct, expand, condense, restructure) |
| 5 | `/research-refine-cycle` | Batch `research-refine-worker` subagents over the project's open AUDIT directives; one worker per topic file (each resolves that file's AUDITs serially via `research-refine`), parallel across distinct files/directories within a batch. Takes `<count\|all>@<workers>`; resumable/idempotent. Ships `list-open-audits.sh` to enumerate open AUDITs deterministically |
| 6 | `/research-restructure` | Structural changes at any depth: split, merge, promote, demote, nest, or flatten chapters |
| 7 | `/research-glossary-sync` | Reconcile glossary against current topic content. Fans out per-topic candidate extraction to `term-extractor` in parallel |

Research skills track topic status through: `stub` -> `inquiry` -> `draft` -> `audited` -> `done`.

The research workflow uses nine bundled subagents: `research-inquiry-worker` (per-topic inquiry worker spawned in parallel batches by `research-inquiry-cycle`), `research-refine-worker` (per-file refine worker that resolves one topic file's open AUDIT directives serially via `research-refine`, spawned in parallel batches — one worker per file — by `research-refine-cycle`), `research-investigation-worker` (execution environment for the forked `research-investigation` skill — `context: fork` — spawned in parallel batches by `research-investigation-cycle` and also by direct human invocations of `/research-investigation`; hosts the inline web search-fetch-verify loop), `research-audit-worker` (execution environment for the forked `research-audit-topic` skill — `context: fork` — spawned in parallel batches by `research-audit-cycle` and also by direct human invocations of `/research-audit-topic`; runs every audit lens plus CONFIDENCE verification inline on one topic), `confidence-verifier` (CONFIDENCE-marker verifier shared by the four standalone `research-audit-*` lens skills; the forked `research-audit-topic` resolves markers inline instead), `quality-auditor` (per-topic depth/sourcing audit, spawned in parallel by `research-audit-quality`), `coherence-auditor` (per-topic narrative-flow audit, spawned in parallel by `research-audit-coherence`), `term-extractor` (per-topic glossary-candidate extraction, spawned in parallel by `research-glossary-sync`), and `corpus-locator` (read-only placement scout that maps a new source's claims to the sections they belong in, spawned by `research-ingest-source`). All live in `research/agents/` and are installed alongside the workflow's skills.

### Codebase Survey Workflow

A workflow for bootstrapping and maintaining an AI-consumable map of an existing codebase. Documentation is module-local so partial loading works: top-level `CODEBASE.md` plus `<module>/CODEBASE.md` per module, with derived `CLAUDE.md` files lifted from rule-tagged findings.

| Phase | Command | What it does |
|-------|---------|-------------|
| 1 | `/codebase-survey-init` | Bootstrap: discover structure, synthesize module map, write top-level `CODEBASE.md` + per-module stubs |
| 2 | `/codebase-survey-module <path>` | Deep-dive one module via parallel subagents (deps, API surface, wire API, tests, ops) |
| 3 | `/codebase-architecture-assessment` | Cross-cutting findings (`assessment.md`, tagged `kind: rule` / `kind: observation`) plus synthesised `architecture.md`, `tech-stack.md`, and `operations.md` — all four `docs/codebase/*.md` files |
| 4 | `/codebase-derive-instructions` | Lift `kind: rule` findings into `CLAUDE.md` (or `AGENTS.md`); source-anchored, verified for length and rule count |
| - | `/codebase-survey-update [range/PR#]` | Incremental refresh driven by per-module `surveyed_sha`; only re-surveys modules whose code changed |

The workflow uses six bundled subagents (`structural-discovery`, `dep-grapher`, `api-surface-extractor`, `wire-api-extractor`, `test-auditor`, `ops-detective`) that live in `codebase-survey/agents/` and are installed alongside the workflow's skills.

### Synaptic Authoring Workflow

Skills for authoring content for **Synaptic**, an interactive online learning platform. A Synaptic *track* is a git directory of content files validated and snapshotted by the deterministic `synaptic` CLI; these skills draft that content against the CLI's file contract without ever adjudicating validity, minting ids, or hashing themselves. See [`synaptic-authoring/README.md`](synaptic-authoring/README.md) for the content-kind and grounding contract these skills target.

| Phase | Command | What it does |
|-------|---------|-------------|
| 1 | `/author-ingest` | Distil repo-local source material (a research KB or plain docs — never the web) into un-`id`'d `reference/` files tagged with resolvable grounding refs. Spawns `material-extractor` |
| 2 | `/author-structure` | Propose the track DAG (nodes, prerequisite edges, priority) from `reference/` + a track goal, then mint node ids via `synaptic scaffold` once the human approves. Spawns `concept-mapper` |
| 3 | `/author-snippet` | Draft the learner-facing body of a scaffolded node from `reference/` — playful low-stakes voice, always *why it matters* / *what it unlocks*, each claim grounded |
| 3 | `/author-questions` | Draft multiple-choice questions with tight reference lists honoring "assessment is feedback, never a gate", then mint question ids and write files. Spawns `question-smith` |
| 4 | `/author-gap-scan` | Audit an existing or proposed DAG for foundational gaps — concepts referenced but never taught, orphan roots, prerequisite leaps, redundant nodes. Spawns `concept-mapper` and `coverage-auditor` |
| 5 | `/author-selfcheck` | The standing hand-off gate: run `synaptic validate --json`, summarise findings, and refuse to present an integrity-breaking snapshot |

**Typical flow:** `ingest` -> `structure` -> `snippet` (per node) -> `questions` (per node) -> `gap-scan` -> `selfcheck` before hand-off.

The workflow uses four bundled read-only proposal subagents (`material-extractor`, `concept-mapper`, `question-smith`, `coverage-auditor`) that return structured reports and write no files — the orchestrating skill does the scaffolding and writing. All live in `synaptic-authoring/agents/` and are installed alongside the workflow's skills.

### Utility

| Command | What it does |
|---------|-------------|
| `/pr` | Create or update a GitHub pull request for the current branch via `gh` — synthesises a What/Why/How body from commits and diff, defaults to draft (override with `final`), auto-pushes the branch |
| `/version-bump` | Bump the project's version (detects `package.json`, `Cargo.toml`, `pyproject.toml`, and similar) from `major`/`minor`/`patch` or an explicit `x.y.z`, then cut an annotated git tag — gathers a changelog from the commits since the last tag and writes it to CHANGELOG.md, the tag message, and the chat; defers the commit to `/commit` |
| `/setup-github-workflow` | Analyze the project and propose GitHub Actions workflows for CI and releases tailored to its stack and goal — or refresh an existing set to the latest action/library versions; interviews you on the judgement calls (branching model, CI triggers, release cadence), pins every action to a commit SHA, has target versions security-vetted by the `action-security-auditor` subagent, confirms before writing, and never commits |
| `/deckset` | Generate [Deckset](https://www.deckset.com/) presentations from markdown content |
| `/adr` | Manually record one or more ADRs from the current conversation under `docs/decisions/` — the human override for when a decision worth preserving was made in-session but no skill recorded it |
| `/audit-context` | Diagnose contradictions, ambiguities, and irrelevance in the current session context (or a given file list) |
| `/spec-sharpener` | Harden a greenfield project's spec/docs into an implementation-ready state — interviews you one issue at a time and edits docs in place; the sharpened spec itself is the record (no ADRs — it runs pre-implementation) |

`/spec-sharpener` uses two bundled subagents in `common/agents/` to keep the main session lean: `spec-surveyor` (read-only — discovers the docs, reads the decision log, sweeps against the finding taxonomy, and returns a compact prioritized backlog; all the doc text stays inside the subagent) and `decision-encoder` (write-side — edits the affected docs for one resolved finding at a time; writes no ADRs). The main session holds only the compact backlog and runs the interview. Both are installed alongside the workflow's skills.

`/version-bump` uses a third bundled subagent in `common/agents/`: `changelog-gatherer` (read-only — runs `git log` over the range since the last tag, classifies commits into Keep-a-Changelog sections, filters noise, and returns one ready-to-use changelog block). The raw commit list stays inside the subagent; the block is written to CHANGELOG.md, the tag annotation, and the chat.

`/setup-github-workflow` uses a fourth bundled subagent in `common/agents/`: `action-security-auditor` (resolves each GitHub Action to its latest stable release, pins it to the exact commit SHA, and assesses that target version for security risk — known CVEs, compromised tags, maintainer/ownership changes, unpinned transitive references — returning per-action version + SHA + findings). The raw registry/git/web lookups stay inside the subagent; the skill surfaces every finding to the human and writes the pinned `owner/repo@<sha> # vX.Y.Z` references.

## How Skills Work

Each skill lives in `<workflow>/skills/<name>/SKILL.md` and uses YAML frontmatter to configure behavior:

```yaml
---
name: skill-name          # becomes the /slash-command
description: ...          # helps Claude decide when to auto-load
model: opus               # which model to use (opus for planning, sonnet for implementation)
allowed-tools:            # restrict which tools the skill can use
  - Read
  - Edit
disable-model-invocation: true  # require explicit /slash-command (no auto-triggering)
argument-hint: "topic"    # documents expected arguments
---
```

Some skills include reference files alongside their SKILL.md (e.g., `references/SAMPLE-PLAN.md`) that are loaded as additional context.

For the full specification of skill frontmatter and capabilities, see the [Anthropic skills documentation](https://docs.anthropic.com/en/docs/claude-code/skills).

## Repository Structure

Skills are grouped by workflow at the repo root. Each workflow directory has its own `skills/` and `agents/` subdirectories — `install.sh` reads from those and symlinks them flat into `<target>/.claude/skills/` and `<target>/.claude/agents/`.

```
codebase-survey/
  README.md                  # full codebase-survey workflow specification
  skills/
    codebase-architecture-assessment/SKILL.md
    codebase-derive-instructions/SKILL.md
    codebase-survey-init/SKILL.md
    codebase-survey-module/SKILL.md
    codebase-survey-update/SKILL.md
  agents/
    api-surface-extractor.md
    dep-grapher.md
    ops-detective.md
    structural-discovery.md
    test-auditor.md
    wire-api-extractor.md
common/
  skills/
    adr/SKILL.md
    audit-context/SKILL.md
    commit/SKILL.md
    deckset/SKILL.md
    pr/SKILL.md
    setup-github-workflow/SKILL.md
    spec-sharpener/SKILL.md
    version-bump/SKILL.md
  agents/
    action-security-auditor.md
    changelog-gatherer.md
    decision-encoder.md
    spec-surveyor.md
milestone-driven/
  skills/
    implementation-cycle/SKILL.md
    implementation-cycle-workflow/SKILL.md
    milestone-breakdown/SKILL.md
    milestone-closing/SKILL.md
    project-inception/SKILL.md
    strategic-planning/SKILL.md
    task-implementation/SKILL.md
  agents/
    milestone-scout.md
    task-worker.md
    doc-updater.md
    decision-lookup.md
  workflows/
    implementation-cycle.js       # Workflow script for /implementation-cycle-workflow
research/
  README.md                  # full research workflow specification
  skills/
    research-add-chapter/SKILL.md
    research-add-topic/SKILL.md
    research-audit-coherence/SKILL.md
    research-audit-consistency/SKILL.md
    research-audit-coverage/SKILL.md
    research-audit-graphics/SKILL.md
    research-audit-quality/SKILL.md
    research-audit-topic/SKILL.md
    research-audit-cycle/SKILL.md
    research-generate-graphics/SKILL.md
    research-glossary-sync/SKILL.md
    research-inception/SKILL.md
    research-ingest-source/SKILL.md
    research-inquiry/SKILL.md
    research-inquiry-cycle/SKILL.md
    research-investigation/SKILL.md
    research-investigation-cycle/SKILL.md
    research-refine/SKILL.md
    research-refine-cycle/SKILL.md
    research-restructure/SKILL.md
  agents/
    coherence-auditor.md
    confidence-verifier.md
    corpus-locator.md
    quality-auditor.md
    research-audit-worker.md
    research-inquiry-worker.md
    research-investigation-worker.md
    research-refine-worker.md
    term-extractor.md
synaptic-authoring/
  README.md                  # content-kind + grounding contract the skills target
  skills/
    author-gap-scan/SKILL.md
    author-ingest/SKILL.md
    author-questions/SKILL.md
    author-selfcheck/SKILL.md
    author-snippet/SKILL.md
    author-structure/SKILL.md
  agents/
    concept-mapper.md
    coverage-auditor.md
    material-extractor.md
    question-smith.md
documentation/
  anthropic/skills.md      # official Anthropic skills docs
install.sh                 # symlink installer (skills + agents) — takes <workflow|all> [target]
```
