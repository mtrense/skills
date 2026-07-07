# Claude Code Skills

## What This Repo Is

A test-bed for developing, improving, and deploying Claude Code skills. Skills are prompt-based plugins — markdown files with YAML frontmatter that Claude loads and follows as playbooks. Skills are grouped by workflow family at the repo root: each top-level directory (`milestone-driven/`, `research/`, `codebase-survey/`, `common/`) contains its own `skills/` and `agents/` subdirectories. A skill therefore lives at `<workflow>/skills/<skill-name>/SKILL.md` and a custom subagent at `<workflow>/agents/<name>.md`.

When working in this repo, the goal is typically to iterate on skill prompts, test them against real usage, and prepare them for deployment to other projects via `install.sh` (symlinks) or manual copy.

**Where testing happens:** This repo only contains skill and agent source — there are no skill executions, test runs, or generated artifacts here. When debugging or analyzing a skill or agent's behavior, the actual invocations (logs, outputs, generated files) live in a separate project where the skill was installed and run. Don't search this repo for test results, example outputs, or runtime traces; ask the user which project to look in instead.

## Installation

```bash
# Install every workflow globally (~/.claude/skills/ + ~/.claude/agents/)
./install.sh all

# Install one workflow globally
./install.sh milestone-driven

# Install one workflow into a specific project
./install.sh research /path/to/project
```

`install.sh` takes the workflow name (or `all`) as the first argument and an optional target directory as the second. All selected skills are symlinked into `<target>/.claude/skills/` and agents into `<target>/.claude/agents/` — the flat layout Claude Code expects — so workflow grouping exists only at the source. Two workflows that ship a skill or agent with the same filename will shadow each other when installed together; this is intentional, so a workflow can re-define a skill by name when installed alone.

## Skill Architecture

### Workflow Families

**Milestone-driven workflow** — a four-phase cycle for building software:
1. `/project-inception` → Socratic dialogue producing README.md (one-time, precedes the cycle)
2. `/strategic-planning` → Socratic dialogue adding milestones (each as `roadmap/NNNN-slug.md`, indexed by one line in ROADMAP.md)
3. `/milestone-breakdown` → Decomposes a milestone into ordered tasks in PLAN.md; delegates codebase reconnaissance to the `milestone-scout` subagent
4. `/task-implementation` → Strict TDD: one task per invocation, tests first
5. `/implementation-cycle` → Sequentially spawns one `task-worker` subagent per task (which invokes task-implementation + commit) to keep the main session clean; after each task lands, spawns a `doc-updater` subagent to sync reference docs and examples to that one commit (no-op unless the change is surface-visible)
6. `/milestone-closing` → Verifies criteria, documents results (holistic README narrative pass), resets PLAN.md

The milestone-driven workflow ships four custom subagents (`milestone-scout`, `task-worker`, `doc-updater`, `decision-lookup`) under `milestone-driven/agents/`, installed alongside skills by `install.sh`. `doc-updater` runs per task inside `/implementation-cycle`, keeping reference docs and examples in sync incrementally; `/milestone-closing` then handles the holistic README narrative at the end of the milestone. `decision-lookup` is a read-only librarian for the project's Architecture Decision Records (see "Decision records" below): given a topic, it reads `docs/decisions/INDEX.md`, pulls only the relevant records, and returns a compact briefing — spawned by `/strategic-planning` and `/milestone-breakdown` so those opus sessions inherit prior decisions without paging the whole log into context.

**Decision records (ADRs).** The decision-making skills record substantial *on-the-way* decisions — ones that split the architecture, commit to a goal, or foreclose an expensive-to-reverse alternative — as ADRs under `docs/decisions/`. Each decision is a full record at `docs/decisions/NNNN-kebab-title.md` (context, decision, rationale, alternatives, consequences) plus a one-sentence entry in `docs/decisions/INDEX.md` (the abbreviated form agents read to know a decision exists without loading its rationale). `/project-inception` records the foundational tech-shape/distribution decisions, `/strategic-planning` records directional decisions a milestone commits to, and `/milestone-breakdown` records milestone-level architectural splits. Recording is done inline by each skill from the bundled `references/decision-record.md`; *querying* is delegated to the `decision-lookup` subagent for context housekeeping. `/task-implementation` and `/milestone-closing` consume the log directly (reading the specific referenced records / `INDEX.md`) rather than via the subagent — the former because it may run inside a worker subagent that cannot spawn one, the latter because it only needs the index. `spec-sharpener` (in `common/`) runs pre-implementation and therefore writes **no** ADRs — the sharpened spec text is the record; it treats an existing decision log as read-only input (its surveyor drops findings already settled by `Accepted` decisions). `/adr` (in `common/`) is the manual entry point to the same log: the user invokes it to record a decision from the current conversation that no skill captured on its own. (The research workflow's `research/DECISIONS.md` is a separate, content-level log and is intentionally *not* part of this ADR convention.)

**Research workflow** — a multi-phase system for building knowledge bases:
1. `/research-inception` → Creates project structure (INDEX.md, DECISIONS.md, glossary.md, topic stubs)
2. `/research-add-topic` → Adds a new topic (directory + chapter stubs) to an existing project
3. `/research-add-chapter` → Adds new chapter stubs to an existing topic directory
4. `/research-inquiry` → Adds RESEARCH directives (section outlines) to a chapter stub
5. `/research-inquiry-cycle` → Sequentially batches `research-inquiry-worker` subagents over all `stub` topics; workers run fully in parallel within a batch (one topic each)
6. `/research-investigation` → Writes content for one section, marks confidence levels; runs as a forked `research-investigation-worker` subagent (`context: fork`) that drives the web search-fetch-verify loop inline
7. `/research-investigation-cycle` → Sequentially batches `Skill(research-investigation)` invocations over all pending RESEARCH directives; forks run in parallel across distinct topic files within a batch, serial within a topic
8. `/research-audit-consistency` → Checks cross-topic contradictions; inserts AUDIT directives. Delegates CONFIDENCE-marker verification to the `confidence-verifier` subagent.
9. `/research-audit-coverage` → Checks gaps relative to the research plan; inserts AUDIT directives. Delegates CONFIDENCE-marker verification to the `confidence-verifier` subagent.
10. `/research-audit-quality` → Checks depth and sourcing adequacy; inserts AUDIT directives. Delegates CONFIDENCE-marker verification to `confidence-verifier`, and fans out per-topic depth/sourcing analysis to `quality-auditor` subagents in parallel.
11. `/research-audit-coherence` → Checks narrative flow; inserts AUDIT directives. Delegates CONFIDENCE-marker verification to `confidence-verifier`, and fans out per-topic flow analysis to `coherence-auditor` subagents in parallel.
12. `/research-refine` → Resolves AUDIT findings (correct, expand, condense, restructure, etc.)
13. `/research-restructure` → Structural changes (split, merge, promote, demote, nest, flatten) at any depth in the topic tree, with cross-reference rewriting
14. `/research-glossary-sync` → Reconciles glossary.md against topic content. Fans out per-topic candidate extraction to `term-extractor` subagents in parallel.
15. `/research-ingest-source` → Out-of-band author entry point (user-invoked, not part of the phase cycle): given one specific source the author already has (URL or local file), vets it for legitimacy with the same levers as investigation (URL verification, primary-vs-secondary, independence, per-claim confidence), then weaves it into every existing section it corroborates/extends/contradicts across the topic tree — reusing the reference, CONFIDENCE, contradiction (both-positions + DEC + AUDIT), and gap-AUDIT conventions. This is the source-first counterpart to `/research-investigation` (which is directive-first and discovers its own sources). Delegates the read-heavy placement scan to the `corpus-locator` subagent and confirms the placement plan before editing.

The research workflow ships seven custom subagents under `research/agents/`, installed alongside skills by `install.sh`:
- `research-inquiry-worker` — per-topic inquiry worker (invokes `research-inquiry`) spawned in parallel batches by `research-inquiry-cycle`.
- `research-investigation-worker` — execution environment for the forked `research-investigation` skill (`context: fork`). Hosts one directive per fork, including the inline web search-fetch-verify loop. Spawned in parallel batches by `research-investigation-cycle` and also used by direct human invocations of `/research-investigation`.
- `confidence-verifier` — shared CONFIDENCE-marker verifier for all four `research-audit-*` skills.
- `quality-auditor` — per-topic depth/sourcing auditor spawned in parallel by `research-audit-quality`.
- `coherence-auditor` — per-topic narrative-flow auditor spawned in parallel by `research-audit-coherence`.
- `term-extractor` — per-topic glossary-candidate extractor spawned in parallel by `research-glossary-sync`.
- `corpus-locator` — read-only placement scout spawned by `research-ingest-source`. Given a new source's extracted claims, scans the topic tree and returns, per claim, the sections that corroborate/extend/contradict it (plus uncovered claims). Does not fetch the web or edit files.

The full research specification is in `research/README.md`.

**Codebase-survey workflow** — bootstraps and maintains an AI-consumable map of an existing codebase, with detail co-located alongside code:
1. `/codebase-survey-init` → Bootstrap; delegates raw discovery to the structural-discovery subagent, synthesizes the module map in the main session, writes top-level `CODEBASE.md` plus per-module stubs
2. `/codebase-survey-module <path>` → Per-module deep-dive; spawns five subagents (dep-grapher, api-surface-extractor, wire-api-extractor, test-auditor, ops-detective) in parallel and assembles `<path>/CODEBASE.md`
3. `/codebase-architecture-assessment` → Cross-cutting pass; writes all four `docs/codebase/*.md` files — `assessment.md` (findings tagged `kind: rule` or `kind: observation`), plus synthesised `architecture.md`, `tech-stack.md`, and `operations.md`. Files that lack the `generated_by` marker are treated as human-authored stated architecture and not overwritten.
4. `/codebase-survey-update [commit-range|PR#]` → Incremental refresh driven by per-module `surveyed_sha` deltas; flags `CLAUDE.md` drift but does not rewrite
5. `/codebase-derive-instructions` → Lifts `kind: rule` findings into `CLAUDE.md` (or `AGENTS.md` if present) with source-anchor comments; verifies length, imports, and rule count before writing

The subagents live in `codebase-survey/agents/` and are installed alongside skills by `install.sh`.

**Common workflow** — skills and agents that aren't owned by any single workflow live under `common/`. This currently houses two kinds of skill:

Cross-workflow tools (used by, or invoked from, multiple workflow families):
- `/commit` → Crafts a conventional commit from staged/unstaged changes; the single commit point for all workflows (milestone-driven, research, codebase-survey) — no other skill commits directly
- `/pr` → Creates or updates a GitHub pull request for the current branch via `gh`. Synthesises a What/Why/How body from commits and diff, defaults to draft (override with `final`), auto-pushes the branch, and refuses on a dirty tree (defers to `/commit`)

Standalone utilities (don't belong to any workflow):
- `/adr` → Manually records one or more ADRs from the current conversation under `docs/decisions/` (shared `NNNN-title.md` + `INDEX.md` convention — see "Decision records" above). The human override for when a decision worth preserving was made in-session but no skill recorded it; user-invoked only, treats the invocation itself as the worth-recording call, grounds every section in what was actually discussed (never fabricates alternatives), and confirms the decision list before writing
- `/audit-context` → Diagnoses contradictions, ambiguities, and irrelevance in the current session context (or a given file list); read-only, produces a line-cited severity-ranked report
- `/deckset` → Generates Deckset (macOS) presentations from existing markdown content
- `/spec-sharpener` → Hardens a greenfield project's spec/docs into an implementation-ready state; interviews the user one issue at a time (ambiguities, contradictions, gaps) and edits the docs in place — the sharpened spec itself is the record. Runs pre-implementation, so it writes no ADRs; an existing decision log is read-only input for deduplication (see "Decision records" above). Keeps the main session lean by delegating both the doc-heavy sweep and the file-writing to subagents (see below) — the main session holds only the compact backlog and runs the interview

The common workflow ships two custom subagents under `common/agents/`, installed alongside skills by `install.sh`. Both are used by `/spec-sharpener`:
- `spec-surveyor` — read-only reconnaissance worker. Discovers the docs, reads the decision log, builds a system model, sweeps against the finding taxonomy, drops findings already settled by `Accepted` decisions, and returns a compact prioritized backlog (each finding carrying a quoted anchor, the problem, why-it-matters, and 2–4 concrete options). All the doc text and the taxonomy stay inside the subagent and are discarded.
- `decision-encoder` — write-side worker. Given one resolved finding plus the agreed resolution, makes the minimal edits to the affected docs so they state the resolution unambiguously; writes no ADR or index entry. Returns a one-line confirmation. Runs one at a time (never in parallel) since successive resolutions may touch the same document.

### Skill File Conventions

Each `SKILL.md` has YAML frontmatter controlling behavior:
- `name` — becomes the `/slash-command`
- `description` — helps Claude decide when to auto-load the skill
- `model` — which Claude model to use (opus for planning/research, sonnet for implementation/commit)
- `disable-model-invocation: true` — user-only invocation (all research skills use this)
- `argument-hint` — documents expected arguments

Reference files (like `milestone-driven/skills/milestone-breakdown/references/SAMPLE-PLAN.md`) sit alongside SKILL.md and are loaded as context.

### When Adding a New Skill

After creating a new skill under `<workflow>/skills/<skill-name>/`, register it in both:
- `CLAUDE.md` — add it to the appropriate workflow family list under "Workflow Families" (or create a new family if it doesn't fit)
- `README.md` — add it to the user-facing skill listing

If the skill doesn't belong to any existing workflow, place it under `common/skills/` and consider whether a new workflow directory is warranted.

Keep the one-line description consistent across both files.

If a **new workflow directory** is added (not just a new skill in an existing one), also update the marketplace metadata:
- Create `<workflow>/.claude-plugin/plugin.json` (name, description, author, homepage, repository, keywords) — copy the shape from an existing workflow's manifest.
- Add a new plugin entry to `.claude-plugin/marketplace.json` (`name`, `source: "./<workflow>"`, `description`, `category`).
- Keep the plugin `description` in sync with the workflow's one-line summary in CLAUDE.md and README.md.

Adding a skill *within* an existing workflow does not require touching `.claude-plugin/` — the workflow plugin already picks up everything under its `skills/` directory.

### Subagents

Custom subagents live in `<workflow>/agents/<name>.md` (a single file per agent, not a directory) and are installed via symlink to `~/.claude/agents/` (or `<project>/.claude/agents/` for project installs) by the same `install.sh`. Skills invoke them via the `Agent` tool with `subagent_type: <name>`. Use a custom subagent when a skill needs to delegate a deterministic, structured task (e.g., extracting an API surface, running a dependency grapher) so the orchestrating skill never sees raw tool output.

### Key Documents Referenced by Skills

Skills expect these files to exist in target projects:
- `README.md` — project identity (created by project-inception)
- `ROADMAP.md` — milestone **index**: one line per milestone (`NNNN-slug.md — [status] summary`), kept lean so it stays cheap to load. Full milestone content (value, outcome, success criteria, notes, closing notes) lives in `roadmap/NNNN-slug.md`. Managed by strategic-planning, read by milestone-breakdown/closing (which open only the specific milestone file they need)
- `PLAN.md` — task list for current milestone (managed by milestone-breakdown, consumed by task-implementation)
- `docs/decisions/NNNN-kebab-title.md` + `docs/decisions/INDEX.md` — Architecture Decision Records (written by project-inception, strategic-planning, and milestone-breakdown; read via the `decision-lookup` subagent by strategic-planning/milestone-breakdown, directly by task-implementation/milestone-closing, and as read-only dedup input by spec-sharpener's surveyor)

Research skills expect an `research/` directory with `INDEX.md`, `DECISIONS.md`, `glossary.md`, and `content/` subdirectory.

Codebase-survey skills produce and consume:
- `CODEBASE.md` at the repo root (top-level survey, module map, tech stack)
- `<module>/CODEBASE.md` per module (purpose, FRs/NFRs, deps, API, tests, deviations, ops)
- `docs/codebase/architecture.md`, `tech-stack.md`, `operations.md`, `assessment.md`
- All survey files carry front-matter: `surveyed_sha`, `surveyed_at`, `survey_schema`. Derived `CLAUDE.md` carries `derived_from_survey_sha`, `derived_at`, `derive_schema`.

## Reference Documentation

- `claude-skills.md` — official Anthropic documentation on the skills system (frontmatter options, invocation control, `$ARGUMENTS` syntax, `context: fork`, dynamic context with `!` commands)
- `documentation/anthropic/skills.md` — additional official docs on skill creation and distribution
