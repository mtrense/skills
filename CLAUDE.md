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
2. `/strategic-planning` → Socratic dialogue adding milestones to ROADMAP.md
3. `/milestone-breakdown` → Decomposes a milestone into ordered tasks in PLAN.md; delegates codebase reconnaissance to the `milestone-scout` subagent
4. `/task-implementation` → Strict TDD: one task per invocation, tests first
5. `/implementation-cycle` → Sequentially spawns one `task-worker` subagent per task (which invokes task-implementation + commit) to keep the main session clean
6. `/milestone-closing` → Verifies criteria, documents results, resets PLAN.md

The milestone-driven workflow ships two custom subagents (`milestone-scout`, `task-worker`) under `milestone-driven/agents/`, installed alongside skills by `install.sh`.

**Research workflow** — a multi-phase system for building knowledge bases:
1. `/research-inception` → Creates project structure (INDEX.md, DECISIONS.md, glossary.md, topic stubs)
2. `/research-add-topic` → Adds a new topic (directory + chapter stubs) to an existing project
3. `/research-add-chapter` → Adds new chapter stubs to an existing topic directory
4. `/research-inquiry` → Adds RESEARCH directives (section outlines) to a chapter stub
5. `/research-investigation` → Writes content for one section, marks confidence levels; delegates the search-fetch-verify loop to the `source-investigator` subagent (one or several in parallel for `sources: any`)
6. `/research-audit-consistency` → Checks cross-topic contradictions; inserts AUDIT directives. Delegates CONFIDENCE-marker verification to the `confidence-verifier` subagent.
7. `/research-audit-coverage` → Checks gaps relative to the research plan; inserts AUDIT directives. Delegates CONFIDENCE-marker verification to the `confidence-verifier` subagent.
8. `/research-audit-quality` → Checks depth and sourcing adequacy; inserts AUDIT directives. Delegates CONFIDENCE-marker verification to `confidence-verifier`, and fans out per-topic depth/sourcing analysis to `quality-auditor` subagents in parallel.
9. `/research-audit-coherence` → Checks narrative flow; inserts AUDIT directives. Delegates CONFIDENCE-marker verification to `confidence-verifier`, and fans out per-topic flow analysis to `coherence-auditor` subagents in parallel.
10. `/research-refine` → Resolves AUDIT findings (correct, expand, condense, restructure, etc.)
11. `/research-restructure` → Structural changes (split, merge, promote, demote) with cross-reference rewriting
12. `/research-glossary-sync` → Reconciles glossary.md against topic content. Fans out per-topic candidate extraction to `term-extractor` subagents in parallel.

The research workflow ships five custom subagents under `research/agents/`, installed alongside skills by `install.sh`:
- `source-investigator` — search-fetch-verify worker for `research-investigation`.
- `confidence-verifier` — shared CONFIDENCE-marker verifier for all four `research-audit-*` skills.
- `quality-auditor` — per-topic depth/sourcing auditor spawned in parallel by `research-audit-quality`.
- `coherence-auditor` — per-topic narrative-flow auditor spawned in parallel by `research-audit-coherence`.
- `term-extractor` — per-topic glossary-candidate extractor spawned in parallel by `research-glossary-sync`.

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
- `/audit-context` → Diagnoses contradictions, ambiguities, and irrelevance in the current session context (or a given file list); read-only, produces a line-cited severity-ranked report
- `/deckset` → Generates Deckset (macOS) presentations from existing markdown content

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
- `ROADMAP.md` — milestones (managed by strategic-planning, read by milestone-breakdown/closing)
- `PLAN.md` — task list for current milestone (managed by milestone-breakdown, consumed by task-implementation)

Research skills expect an `research/` directory with `INDEX.md`, `DECISIONS.md`, `glossary.md`, and `content/` subdirectory.

Codebase-survey skills produce and consume:
- `CODEBASE.md` at the repo root (top-level survey, module map, tech stack)
- `<module>/CODEBASE.md` per module (purpose, FRs/NFRs, deps, API, tests, deviations, ops)
- `docs/codebase/architecture.md`, `tech-stack.md`, `operations.md`, `assessment.md`
- All survey files carry front-matter: `surveyed_sha`, `surveyed_at`, `survey_schema`. Derived `CLAUDE.md` carries `derived_from_survey_sha`, `derived_at`, `derive_schema`.

## Reference Documentation

- `claude-skills.md` — official Anthropic documentation on the skills system (frontmatter options, invocation control, `$ARGUMENTS` syntax, `context: fork`, dynamic context with `!` commands)
- `documentation/anthropic/skills.md` — additional official docs on skill creation and distribution
