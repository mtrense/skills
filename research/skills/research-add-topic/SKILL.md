---
name: research-add-topic
description: "Add a new topic (directory + chapter stubs) to an existing research project. Use when the project already exists and you want to introduce a new top-level topic area. Arguments: topic name (required), optional summary to seed scoping."
argument-hint: "<topic-name> [summary of the topic]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Glob, Write, Edit
---

# Research Add Topic

You are adding a new top-level topic to an existing research project. A topic lives directly under `research/content/` and is either a single chapter file (shallow subject) or a directory containing chapter files — possibly with further nested sub-chapter groups (broader subject). This skill bridges the gap between project inception and chapter-level inquiry.

## Argument Parsing

`$ARGUMENTS` contains the topic name as the first word, and an optional free-text summary after it.

- **Topic name**: the first whitespace-delimited token (becomes the directory name under `research/content/`)
- **Topic summary** (optional): everything after the first token — a brief description of what the topic should cover

If a summary is provided, use it as the starting point for scoping: propose chapters, boundaries, and relationships that align with the summary rather than asking open-ended questions. The Socratic exchange then refines and validates your proposal instead of starting from scratch.

## Prerequisites

1. Read `research/CLAUDE.md` for project conventions, tone, scope, and goals.
2. Read `research/INDEX.md` to understand existing topics and their relationships.
3. Confirm neither the topic directory nor a single-file topic of the same name already exists under `research/content/` (`<topic-name>/` or `<topic-name>.md`).
   - If either exists, abort and explain. The user may want `/research-add-chapter` (to add chapters under an existing topic directory), `/research-inquiry` (to outline a chapter), or `/research-restructure` (to reorganize).

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
   If only one chapter is needed, the topic becomes a single `.md` file directly under `content/` rather than a directory. Don't force multiplicity for symmetry. If a chapter is itself broad enough to warrant sub-chapters, note that — sub-directories can be created up front.
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

### Topic files

If the topic has a single chapter, create one file at `research/content/<topic-name>.md`. Otherwise, create the directory `research/content/<topic-name>/` and one stub file per chapter inside it. If the discussion identified sub-chapter groups, create the sub-directories and place their chapter stubs accordingly.

Every chapter stub uses the same shape:

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

Add the new topic to `research/INDEX.md` in a logically appropriate position (not necessarily at the end). Heading level matches depth: top-level entries are `##`, chapters inside a directory topic are `###`, sub-chapters under a sub-directory are `####`, etc. Every leaf chapter heading is a markdown link — link text is the path relative to `content/`, link target is that path prefixed with `content/`. Directory entries stay plain-text path headings (no file to point at).

For a single-chapter topic:

```markdown
## [<topic-name>.md](content/<topic-name>.md)
<1-2 sentence abstract>
```

For a multi-chapter topic, possibly with nested sub-chapter groups:

```markdown
## <topic-name>/
<abstract for this topic>

### [<topic-name>/<chapter-file>.md](content/<topic-name>/<chapter-file>.md)
<1-2 sentence abstract>

### <topic-name>/<sub-group>/
<abstract for this sub-chapter group>

#### [<topic-name>/<sub-group>/<chapter-file>.md](content/<topic-name>/<sub-group>/<chapter-file>.md)
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
