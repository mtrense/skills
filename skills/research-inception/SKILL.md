---
name: research-inception
description: "Initialize a research project structure with CLAUDE.md, INDEX.md, DECISIONS.md, glossary.md, and topic stubs. Use when starting a new research effort from scratch."
disable-model-invocation: true
model: opus
allowed-tools: Read, Glob, Write, Edit
---

# Research Inception

You are initializing a new research project. This is an interactive, Socratic phase — guide the user through defining their research scope before generating any files.

## Phase 1: Discovery (Interactive)

Guide the user through a structured conversation. Do NOT dump all questions at once. Ask 2–3 at a time, grouped by theme, and adapt based on answers. Typically this takes 3–5 rounds.

**Important:** Users often arrive knowing *what domain they want to research* but not fully aware of *why the research matters* or *what decisions it will ultimately inform*. Research without a clear "so what?" tends to drift in scope and depth. Your job is to uncover the real motivation before shaping the knowledge base.

### Phase 1a: Understand the Motivation (before the structure)

Start here. Resist the urge to discuss topics or file structure until the purpose is clear.

**Need & Context**
- What's driving this research? Is there a decision, project, or problem it needs to inform?
- Who will use this knowledge base, and what will they do with it?
- What's the trigger — why now?

**Validation**
- If this knowledge base didn't exist, how would you (or your team) get the information you need? How well does that work?
- Have you seen existing resources on this domain? What's missing or wrong about them?

**Stakes & Scope Pressure**
- What happens if the research stays shallow or incomplete in the wrong areas?
- Are there time-sensitive decisions this needs to support?

### Phase 1b: Shape the Knowledge Base

Once you understand the motivation, explore what the research should cover.

1. **Research domain** — What broad area are we researching?
2. **Goals** — What practical outcomes should this knowledge base support? (Anchor these to the motivations discovered in Phase 1a.)
3. **Topics** — What specific topics should be covered? Help the user brainstorm and refine. For each topic, clarify:
   - Is it standalone or part of a group (directory)?
   - What's the expected scope (brief overview vs. deep dive)?
   - Are there known relationships to other topics?
4. **Conventions** — Ask about:
   - Preferred tone (technical, accessible, mixed)
   - Citation style preferences (inline links, reference sections, both)
   - Any domain-specific terminology conventions
   - Target audience beyond "humans and AI"
5. **Scope boundaries** — What is explicitly *out of scope*?

Build on the user's answers naturally, not as a checklist.

### Phase 1c: Convergence Checkpoint

Before moving on, synthesize and present two things separately:

1. **The research motivation** — the underlying need, independent of this knowledge base.
   Frame it as: "The core need is [X]. Today, people get this information by [Y], which
   falls short because [Z]."

2. **The knowledge base thesis** — how this research project addresses that need.
   Frame it as: "This knowledge base addresses that by [coverage/approach], for [audience],
   enabling [decisions/outcomes it supports]."

Ask: "Does this accurately capture why this research matters and what the knowledge base
needs to achieve?" If the user corrects or nuances either statement, iterate. Do not
proceed to file generation until both statements feel right to the user — you should be
confident you understand what they *actually* need to learn, not just the domain they
initially named.

## Phase 2: File Generation

Once the user confirms the research plan, generate the following files under `research/`:

### `research/CLAUDE.md`

This file guides all future research phases. Include:

- Research domain and goals (from discovery)
- Tone and writing conventions
- Citation style and reference format
- Section structure expectations
- Cross-reference conventions: use `[display text](relative-path.md#heading-slug)` relative to `content/`
- Any domain-specific rules discovered during the conversation

The reference format for all topic files is:

```
### References

- **title**: "Name of the resource"
  **url**: <link>
  **published**: <date>
  **last-checked**: <date>
  **verified**: true | false
  **takeaway**: "One-sentence conclusion relevant to this section"
```

### `research/INDEX.md`

Structure:

```markdown
# <Research Project Title>
<abstract — 2-3 sentences describing the research scope and goals>

## <directory-name>/
<abstract for this topic group>

### <directory-name>/<topic-file>.md
**Status**: stub

<1-2 sentence abstract>

## <standalone-topic>.md
**Status**: stub

<1-2 sentence abstract>
```

Rules:
- Directory entries (`##`) group child topics, no status field
- Leaf topic files (`###` under a directory, or `##` if standalone) carry `**Status**: stub`
- Use the relative path from `content/` as the heading identifier
- Order topics logically, not alphabetically

### `research/DECISIONS.md`

```markdown
# Decisions

This log records decisions made during research — source selection, scope exclusions, contradictions resolved, and turning points where conclusions changed.

| ID | Date | Topic | Decision | Rationale |
|----|------|-------|----------|-----------|

## Decision Details

<!-- Entries will be added as:

### DEC-001: <title>
**Date**: YYYY-MM-DD
**Topic**: <topic-file-path>
**Context**: <what prompted this decision>
**Decision**: <what was decided>
**Rationale**: <why>
**Alternatives considered**: <what else was weighed>

-->
```

### `research/glossary.md`

```markdown
---
title: "Glossary"
created: <today>
updated: <today>
---

# Glossary

<!-- Terms are organized by domain area. Each area is a heading.
     Format: **term**: definition
     Add a reference link if the definition comes from an authoritative source. -->
```

Leave the glossary empty — it will be populated during investigation and glossary-sync.

### Topic files in `research/content/`

For each topic identified during discovery, create a file with:

```markdown
---
title: "<Topic Title>"
created: <today>
updated: <today>
---

# <Topic Title>
```

Create directories as needed for grouped topics. The files are intentionally minimal stubs — the inquiry phase adds structure.

### `research/assets/`

Create this directory (add a `.gitkeep` if empty).

## Phase 3: Summary

After generating all files, present:
- A tree view of what was created
- The full INDEX.md content for review
- A reminder that the next step is `/research-inquiry <topic-file>` for each topic

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format for this phase is:
`research(inception): initialize project structure`

## Important Principles

- **Motivation before structure.** Users often arrive with a domain in mind but not a clear
  reason the research matters. Your first job is to understand the underlying need independently,
  then validate that the proposed knowledge base is the right response to it. This reframing
  frequently shifts scope, depth, or topic selection in ways the user finds valuable.
- **Scope, not sections.** This phase captures *what* to research and *why*, never *how* to
  structure individual topics. Section outlines and content planning belong in the inquiry phase.
- **Concise over comprehensive.** An INDEX.md that people actually read beats an exhaustive
  taxonomy that nobody navigates. Aim for the smallest set of topics that covers the real need.
- **Dual audience.** Every description should be clear to a human reader AND parseable by an
  AI agent building context about the research. Avoid ambiguity, jargon without definition,
  and vague hand-waving.
- **Socratic, not interrogative.** Frame questions as collaborative exploration. Explain *why*
  you're asking when it's not obvious. Offer your own hypotheses when the user seems stuck —
  "It sounds like this research is mainly to inform a build-vs-buy decision — is that right?"
- **Respect the human's expertise.** They know the domain. You're helping them articulate and
  structure what they already know, and occasionally surfacing blind spots in coverage.
- **No premature commitment.** If the user is unsure about a topic's scope or placement, mark
  it as provisional rather than forcing a decision. The inquiry and restructure phases exist
  precisely for refinement.

## Important Rules

- Do NOT create a root `CLAUDE.md` — that is out of scope for this skill.
- All paths are relative to the repository root unless stated otherwise.
- Topic filenames use lowercase with hyphens, no numeric prefixes.
- Today's date for frontmatter: use the current date in YYYY-MM-DD format.
