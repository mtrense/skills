---
name: research-add-topic
description: "Add a new topic (directory + chapter stubs) to an existing research project. Use when the project already exists and you want to introduce a new top-level topic area. Arguments: topic name (required), optional summary to seed scoping."
argument-hint: "<topic-name> [summary of the topic]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Glob, Write, Edit
---

# Research Add Topic

You are adding a new topic to an existing research project. A topic is a directory under `research/content/` containing chapter files (`.md` stubs). This skill bridges the gap between project inception and chapter-level inquiry.

## Argument Parsing

`$ARGUMENTS` contains the topic name as the first word, and an optional free-text summary after it.

- **Topic name**: the first whitespace-delimited token (becomes the directory name under `research/content/`)
- **Topic summary** (optional): everything after the first token — a brief description of what the topic should cover

If a summary is provided, use it as the starting point for scoping: propose chapters, boundaries, and relationships that align with the summary rather than asking open-ended questions. The Socratic exchange then refines and validates your proposal instead of starting from scratch.

## Prerequisites

1. Read `research/CLAUDE.md` for project conventions, tone, scope, and goals.
2. Read `research/INDEX.md` to understand existing topics and their relationships.
3. Confirm the topic directory does not already exist under `research/content/`.
   - If it exists, abort and explain. The user may want `/research-inquiry` (to outline a chapter) or `/research-restructure` (to reorganize).

## Phase 1: Scoping (Interactive)

This is a brief Socratic exchange — typically 2-3 rounds, not a full inception. The project's motivation and conventions are already established; you're scoping one new topic within that frame.

### If a summary was provided

Use the summary as a seed: read it alongside the existing INDEX.md, then **lead with a concrete proposal** covering all four scoping dimensions below. Frame it as "Here's what I'd suggest based on your summary — let's refine." This collapses the exchange from exploratory to confirmatory, often converging in 1-2 rounds.

### If no summary was provided

Explore openly with the user across the same dimensions.

### Scoping dimensions

1. **Purpose** — Why does this topic belong in the knowledge base? What gap does it fill relative to existing topics?
2. **Chapters** — What chapters (markdown files) should this topic contain? For each chapter:
   - A working title
   - 1-2 sentence abstract (what it covers)
   - Expected scope: brief overview vs. deep dive
3. **Relationships** — How does this topic relate to existing topics? Are there cross-references that will be needed? Is there overlap to watch out for?
4. **Boundaries** — What is explicitly out of scope for this topic?

Guide the user, don't interrogate. Offer hypotheses when helpful — "Based on the existing topics, it seems like this would naturally cover X and Y — does that match your thinking?"

### Convergence

Before generating files, present a summary:
- Topic name and 1-2 sentence abstract
- List of chapters with titles and abstracts
- Noted relationships to existing topics

Ask for confirmation before proceeding.

## Phase 2: File Generation

### Topic directory

Create `research/content/<topic-name>/` with one stub file per chapter:

```markdown
---
title: "<Chapter Title>"
created: <today>
updated: <today>
---

# <Chapter Title>
```

Filenames use lowercase with hyphens, no numeric prefixes (consistent with project conventions).

### INDEX.md update

Add the new topic to `research/INDEX.md` in a logically appropriate position (not necessarily at the end). Follow the existing format:

```markdown
## <topic-name>/
<abstract for this topic>

### <topic-name>/<chapter-file>.md
**Status**: stub

<1-2 sentence abstract>
```

Preserve the existing content and structure — only add the new entries.

## Phase 3: Summary

Present:
- A tree view of the created files
- The new INDEX.md entries for review
- A reminder that the next step is `/research-inquiry <topic-name>/<chapter>.md` for each chapter

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(add-topic): <topic-name>`

## Rules

- Do NOT create content — only directory, stub files, and INDEX.md entries.
- Do NOT modify existing topic files or other INDEX.md entries.
- Do NOT modify `research/CLAUDE.md`, `DECISIONS.md`, or `glossary.md`.
- Filenames use lowercase with hyphens, no numeric prefixes.
- Today's date for frontmatter: use the current date in YYYY-MM-DD format.
- Chapter stubs are intentionally minimal — the inquiry phase adds section structure.
