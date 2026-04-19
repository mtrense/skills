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
5. `/milestone-closing` → Verifies criteria, documents results, resets PLAN.md
6. `/commit` → The single commit point; no other skill commits directly

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

**Comparison workflow** — builds side-by-side comparison datasets for Lineup projects:
1. `/comparison-new-type` → Socratic scoping; produces `data/<type>/RESEARCH.md` (scope, attributes, sources, initial candidates)
2. `/comparison-scaffold-type` → Derives `data/<type>/attributes.json`, empty `index.json`, and registers the type in top-level `data/index.json`
3. `/comparison-add-candidate` → Adds a candidate stub (`data/<type>/<candidate>.json`) with empty values
4. `/comparison-gather-data` → Researches and populates attribute values for a candidate using web search; records `{value, source, comment}` per attribute

Comparison projects expect a `data/` directory with a top-level `index.json` registering each comparison type.

### Skill File Conventions

Each `SKILL.md` has YAML frontmatter controlling behavior:
- `name` — becomes the `/slash-command`
- `description` — helps Claude decide when to auto-load the skill
- `model` — which Claude model to use (opus for planning/research, sonnet for implementation/commit)
- `disable-model-invocation: true` — user-only invocation (all research skills use this)
- `argument-hint` — documents expected arguments

Reference files (like `skills/milestone-breakdown/references/SAMPLE-PLAN.md`) sit alongside SKILL.md and are loaded as context.

### Key Documents Referenced by Skills

Skills expect these files to exist in target projects:
- `README.md` — project identity (created by project-inception)
- `ROADMAP.md` — milestones (managed by strategic-planning, read by milestone-breakdown/closing)
- `PLAN.md` — task list for current milestone (managed by milestone-breakdown, consumed by task-implementation)

Research skills expect an `research/` directory with `INDEX.md`, `DECISIONS.md`, `glossary.md`, and `content/` subdirectory.

## Reference Documentation

- `claude-skills.md` — official Anthropic documentation on the skills system (frontmatter options, invocation control, `$ARGUMENTS` syntax, `context: fork`, dynamic context with `!` commands)
- `documentation/anthropic/skills.md` — additional official docs on skill creation and distribution
