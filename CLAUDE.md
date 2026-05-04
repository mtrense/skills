# Claude Code Skills

## What This Repo Is

A test-bed for developing, improving, and deploying Claude Code skills. Skills are prompt-based plugins — markdown files with YAML frontmatter that Claude loads and follows as playbooks. Each skill lives in `skills/<skill-name>/SKILL.md`.

When working in this repo, the goal is typically to iterate on skill prompts, test them against real usage, and prepare them for deployment to other projects via `install.sh` (symlinks) or manual copy.

## Installation

```bash
# Install all skills globally (symlinks to ~/.claude/skills/)
./install.sh

# Install to a specific project
./install.sh /path/to/project
```

`install.sh` installs all skills from `skills/` via symlinks.

## Skill Architecture

### Workflow Families

**Engineering workflow** — a four-phase cycle for building software:
1. `/project-inception` → Socratic dialogue producing README.md (one-time, precedes the cycle)
2. `/strategic-planning` → Socratic dialogue adding milestones to ROADMAP.md
3. `/milestone-breakdown` → Decomposes a milestone into ordered tasks in PLAN.md
4. `/task-implementation` → Strict TDD: one task per invocation, tests first
5. `/implementation-cycle` → Sequentially runs task-implementation + commit in fresh subagents (one per task) to keep the main session clean
6. `/milestone-closing` → Verifies criteria, documents results, resets PLAN.md

**Research workflow** — a multi-phase system for building knowledge bases:
1. `/research-inception` → Creates project structure (INDEX.md, DECISIONS.md, glossary.md, topic stubs)
2. `/research-add-topic` → Adds a new topic (directory + chapter stubs) to an existing project
3. `/research-add-chapter` → Adds new chapter stubs to an existing topic directory
4. `/research-inquiry` → Adds RESEARCH directives (section outlines) to a chapter stub
5. `/research-investigation` → Writes content for one section using web search, marks confidence levels
6. `/research-audit-consistency` → Checks cross-topic contradictions; inserts AUDIT directives
7. `/research-audit-coverage` → Checks gaps relative to the research plan; inserts AUDIT directives
8. `/research-audit-quality` → Checks depth and sourcing adequacy; inserts AUDIT directives
9. `/research-audit-coherence` → Checks narrative flow; inserts AUDIT directives
10. `/research-refine` → Resolves AUDIT findings (correct, expand, condense, restructure, etc.)
11. `/research-restructure` → Structural changes (split, merge, promote, demote) with cross-reference rewriting
12. `/research-glossary-sync` → Reconciles glossary.md against topic content

The full research specification is in `prompts/research.md`.

**Codebase-survey workflow** — bootstraps and maintains an AI-consumable map of an existing codebase, with detail co-located alongside code:
1. `/codebase-survey-init` → Bootstrap; delegates raw discovery to the structural-discovery subagent, synthesizes the module map in the main session, writes top-level `CODEBASE.md` plus per-module stubs
2. `/codebase-survey-module <path>` → Per-module deep-dive; spawns five subagents (dep-grapher, api-surface-extractor, wire-api-extractor, test-auditor, ops-detective) in parallel and assembles `<path>/CODEBASE.md`
3. `/codebase-architecture-assessment` → Cross-cutting pass; writes `docs/codebase/assessment.md` with each finding tagged `kind: rule` or `kind: observation`
4. `/codebase-survey-update [commit-range|PR#]` → Incremental refresh driven by per-module `surveyed_sha` deltas; flags `CLAUDE.md` drift but does not rewrite
5. `/codebase-derive-instructions` → Lifts `kind: rule` findings into `CLAUDE.md` (or `AGENTS.md` if present) with source-anchor comments; verifies length, imports, and rule count before writing

The subagents live in `agents/` and are installed alongside skills by `install.sh`.

**Common skills** — used across multiple workflow families:
- `/commit` → Crafts a conventional commit from staged/unstaged changes; the single commit point for all workflows (engineering, research, codebase-survey) — no other skill commits directly

**Utility skills** — standalone tools that don't belong to a workflow family:
- `/audit-context` → Diagnoses contradictions, ambiguities, and irrelevance in the current session context (or a given file list); read-only, produces a line-cited severity-ranked report

### Skill File Conventions

Each `SKILL.md` has YAML frontmatter controlling behavior:
- `name` — becomes the `/slash-command`
- `description` — helps Claude decide when to auto-load the skill
- `model` — which Claude model to use (opus for planning/research, sonnet for implementation/commit)
- `disable-model-invocation: true` — user-only invocation (all research skills use this)
- `argument-hint` — documents expected arguments

Reference files (like `skills/milestone-breakdown/references/SAMPLE-PLAN.md`) sit alongside SKILL.md and are loaded as context.

### When Adding a New Skill

After creating a new skill under `skills/<skill-name>/`, register it in both:
- `CLAUDE.md` — add it to the appropriate workflow family list under "Workflow Families" (or create a new family if it doesn't fit)
- `README.md` — add it to the user-facing skill listing

Keep the one-line description consistent across both files.

### Subagents

Custom subagents live in `agents/<name>.md` (a single file per agent, not a directory) and are installed via symlink to `~/.claude/agents/` (or `<project>/.claude/agents/` for project installs) by the same `install.sh`. Skills invoke them via the `Agent` tool with `subagent_type: <name>`. Use a custom subagent when a skill needs to delegate a deterministic, structured task (e.g., extracting an API surface, running a dependency grapher) so the orchestrating skill never sees raw tool output.

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
