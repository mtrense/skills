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
| 4 | `/milestone-closing` | Verify success criteria, document results, reset for next cycle | Updated `ROADMAP.md` |
| - | `/commit` | Craft a conventional commit from staged/unstaged changes | Git commit |

**Typical flow:** `inception` (once) -> `planning` -> `breakdown` -> `implementation` (repeat per task) -> `closing` -> back to `planning.

### Research Workflow

A multi-phase system for building structured knowledge bases with source verification and quality auditing.

| Phase | Command | What it does |
|-------|---------|-------------|
| 1 | `/research-inception` | Create project structure: INDEX.md, DECISIONS.md, glossary, topic stubs |
| - | `/research-add-topic` | Add a new topic (directory + chapter stubs) to an existing project |
| - | `/research-add-chapter` | Add new chapter stubs to an existing topic directory |
| 2 | `/research-inquiry` | Add section outlines with RESEARCH directives to a chapter |
| 3 | `/research-investigation` | Research and write content for one section using web search |
| 4 | `/research-audit` | Check consistency, coverage, and quality; insert AUDIT directives |
| 5 | `/research-refine` | Resolve audit findings (correct, expand, condense, restructure) |
| 6 | `/research-restructure` | Structural changes: split, merge, promote, or demote topics |
| 7 | `/research-glossary-sync` | Reconcile glossary against current topic content |

Research skills track topic status through: `stub` -> `inquiry` -> `draft` -> `audit` -> `done`.

### Utility

| Command | What it does |
|---------|-------------|
| `/deckset` | Generate [Deckset](https://www.deckset.com/) presentations from markdown content |

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
  commit/SKILL.md
  deckset/SKILL.md
  milestone-breakdown/SKILL.md
  milestone-closing/SKILL.md
  project-inception/SKILL.md
  research-add-chapter/SKILL.md
  research-add-topic/SKILL.md
  research-audit/SKILL.md
  research-glossary-sync/SKILL.md
  research-inception/SKILL.md
  research-inquiry/SKILL.md
  research-investigation/SKILL.md
  research-refine/SKILL.md
  research-restructure/SKILL.md
  strategic-planning/SKILL.md
  task-implementation/SKILL.md
prompts/
  research.md              # full research workflow specification
documentation/
  anthropic/skills.md      # official Anthropic skills docs
install.sh                 # symlink installer
```
