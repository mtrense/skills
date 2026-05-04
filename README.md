# Claude Code Skills

A collection of prompt-based skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that add structured workflows for software engineering and research.

Skills are markdown files with YAML frontmatter that Claude loads as playbooks. Each skill provides a `/slash-command` — you invoke it, and Claude follows the skill's instructions to guide you through a specific workflow phase.

## Installation

```bash
# Install all skills globally (~/.claude/skills/)
./install.sh

# Install to a specific project
./install.sh /path/to/project
```

The installer creates symlinks, so skills stay up to date as you pull changes.

## Skills

### Engineering Workflow

A phased cycle for building software, from idea through implementation to closeout. Each phase produces a specific artifact that feeds into the next.

| Phase | Command | What it does | Produces |
|-------|---------|-------------|----------|
| 0 | `/project-inception` | Socratic dialogue to discover project vision and goals | `README.md` |
| 1 | `/strategic-planning` | Sharpen ideas into well-defined, testable milestones | `ROADMAP.md` entries |
| 2 | `/milestone-breakdown` | Decompose a milestone into ordered, independently testable tasks | `PLAN.md` |
| 3 | `/task-implementation` | Implement one task using strict TDD (tests first, then code) | Passing code + tests |
| 3 | `/implementation-cycle` | Run task-implementation + commit in fresh subagents per task to keep the main session clean | Passing code + commits |
| 4 | `/milestone-closing` | Verify success criteria, document results, reset for next cycle | Updated `ROADMAP.md` |
| - | `/commit` | Craft a conventional commit from staged/unstaged changes | Git commit |

**Typical flow:** `inception` (once) -> `planning` -> `breakdown` -> `implementation` (repeat per task) -> `closing` -> back to `planning`.

The engineering workflow uses two bundled subagents: `milestone-scout` (delegated codebase reconnaissance for `milestone-breakdown`) and `task-worker` (per-task `task-implementation` + `commit` worker for `implementation-cycle`). Both live in `agents/` and are installed alongside skills.

### Research Workflow

A multi-phase system for building structured knowledge bases with source verification and quality auditing.

| Phase | Command | What it does |
|-------|---------|-------------|
| 1 | `/research-inception` | Create project structure: INDEX.md, DECISIONS.md, glossary, topic stubs |
| - | `/research-add-topic` | Add a new topic (directory + chapter stubs) to an existing project |
| - | `/research-add-chapter` | Add new chapter stubs to an existing topic directory |
| 2 | `/research-inquiry` | Add section outlines with RESEARCH directives to a chapter |
| 3 | `/research-investigation` | Write content for one section; delegates the search-fetch-verify loop to the `source-investigator` subagent |
| 4 | `/research-audit-consistency` | Check cross-topic contradictions; insert AUDIT directives |
| 4 | `/research-audit-coverage` | Check gaps relative to the research plan; insert AUDIT directives |
| 4 | `/research-audit-quality` | Check depth and sourcing adequacy; insert AUDIT directives. Fans out per-topic analysis to `quality-auditor` in parallel |
| 4 | `/research-audit-coherence` | Check narrative flow; insert AUDIT directives. Fans out per-topic analysis to `coherence-auditor` in parallel |
| 5 | `/research-refine` | Resolve audit findings (correct, expand, condense, restructure) |
| 6 | `/research-restructure` | Structural changes: split, merge, promote, or demote topics |
| 7 | `/research-glossary-sync` | Reconcile glossary against current topic content. Fans out per-topic candidate extraction to `term-extractor` in parallel |

Research skills track topic status through: `stub` -> `inquiry` -> `draft` -> `audited` -> `done`.

The research workflow uses five bundled subagents: `source-investigator` (web search-fetch-verify loop for `research-investigation`), `confidence-verifier` (CONFIDENCE-marker verifier shared by all four `research-audit-*` skills), `quality-auditor` (per-topic depth/sourcing audit, spawned in parallel by `research-audit-quality`), `coherence-auditor` (per-topic narrative-flow audit, spawned in parallel by `research-audit-coherence`), and `term-extractor` (per-topic glossary-candidate extraction, spawned in parallel by `research-glossary-sync`). All live in `agents/` and are installed alongside skills.

### Codebase Survey Workflow

A workflow for bootstrapping and maintaining an AI-consumable map of an existing codebase. Documentation is module-local so partial loading works: top-level `CODEBASE.md` plus `<module>/CODEBASE.md` per module, with derived `CLAUDE.md` files lifted from rule-tagged findings.

| Phase | Command | What it does |
|-------|---------|-------------|
| 1 | `/codebase-survey-init` | Bootstrap: discover structure, synthesize module map, write top-level `CODEBASE.md` + per-module stubs |
| 2 | `/codebase-survey-module <path>` | Deep-dive one module via parallel subagents (deps, API surface, wire API, tests, ops) |
| 3 | `/codebase-architecture-assessment` | Cross-cutting findings written to `docs/codebase/assessment.md`; tagged `kind: rule` or `kind: observation` |
| 4 | `/codebase-derive-instructions` | Lift `kind: rule` findings into `CLAUDE.md` (or `AGENTS.md`); source-anchored, verified for length and rule count |
| - | `/codebase-survey-update [range\|PR#]` | Incremental refresh driven by per-module `surveyed_sha`; only re-surveys modules whose code changed |

The workflow uses six bundled subagents (`structural-discovery`, `dep-grapher`, `api-surface-extractor`, `wire-api-extractor`, `test-auditor`, `ops-detective`) that live in `agents/` and are installed alongside skills.

### Utility

| Command | What it does |
|---------|-------------|
| `/deckset` | Generate [Deckset](https://www.deckset.com/) presentations from markdown content |
| `/audit-context` | Diagnose contradictions, ambiguities, and irrelevance in the current session context (or a given file list) |

## How Skills Work

Each skill lives in `skills/<name>/SKILL.md` and uses YAML frontmatter to configure behavior:

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

```
skills/
  audit-context/SKILL.md
  codebase-architecture-assessment/SKILL.md
  codebase-derive-instructions/SKILL.md
  codebase-survey-init/SKILL.md
  codebase-survey-module/SKILL.md
  codebase-survey-update/SKILL.md
  commit/SKILL.md
  deckset/SKILL.md
  implementation-cycle/SKILL.md
  milestone-breakdown/SKILL.md
  milestone-closing/SKILL.md
  project-inception/SKILL.md
  research-add-chapter/SKILL.md
  research-add-topic/SKILL.md
  research-audit-coherence/SKILL.md
  research-audit-consistency/SKILL.md
  research-audit-coverage/SKILL.md
  research-audit-quality/SKILL.md
  research-glossary-sync/SKILL.md
  research-inception/SKILL.md
  research-inquiry/SKILL.md
  research-investigation/SKILL.md
  research-refine/SKILL.md
  research-restructure/SKILL.md
  strategic-planning/SKILL.md
  task-implementation/SKILL.md
agents/
  api-surface-extractor.md
  coherence-auditor.md
  confidence-verifier.md
  dep-grapher.md
  milestone-scout.md
  ops-detective.md
  quality-auditor.md
  source-investigator.md
  structural-discovery.md
  task-worker.md
  term-extractor.md
  test-auditor.md
  wire-api-extractor.md
CODEBASE_SURVEY.md         # full codebase-survey workflow specification
RESEARCH.md                # full research workflow specification
documentation/
  anthropic/skills.md      # official Anthropic skills docs
install.sh                 # symlink installer (skills + agents)
```
