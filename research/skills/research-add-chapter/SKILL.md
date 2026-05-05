---
name: research-add-chapter
description: "Add new chapter stubs to an existing topic directory in a research project. Use when a topic already exists as a directory and you want to introduce additional chapters. Argument: topic directory name (relative to research/content/)."
argument-hint: "<topic-directory>"
disable-model-invocation: true
model: opus
allowed-tools: Read, Glob, Write, Edit
---

# Research Add Chapter

You are adding one or more new chapters (markdown stub files) to an existing topic directory. A chapter is a `.md` file under `research/content/<topic>/`. This skill bridges the gap between topic creation and chapter-level inquiry.

**Topic directory**: `research/content/$ARGUMENTS`

## Prerequisites

1. Read `research/CLAUDE.md` for project conventions, tone, scope, and goals.
2. Read `research/INDEX.md` to understand existing topics and their chapters.
3. Confirm the topic directory exists under `research/content/`.
   - If it does not exist, abort and explain. The user may want `/research-add-topic` (to create the topic first).
   - If the path points to a standalone file rather than a directory, abort and explain. The user may want `/research-restructure promote` first.
4. List existing chapter files in the topic directory to understand what's already covered.

## Phase 1: Scoping (Interactive)

This is a brief Socratic exchange — typically 2-3 rounds. The topic's purpose is already established; you're scoping new chapters within it.

Explore with the user:

1. **Gap** — What's missing from the current chapter set? What prompted the need for new chapters?
2. **Chapters** — What new chapters should be added? For each chapter:
   - A working title
   - 1-2 sentence abstract (what it covers)
   - Expected scope: brief overview vs. deep dive
3. **Relationships** — How do the new chapters relate to existing chapters in this topic and to other topics? Are there cross-references that will be needed?
4. **Boundaries** — What is explicitly out of scope for these new chapters? Is there overlap with existing chapters to watch out for?

Guide the user, don't interrogate. Offer hypotheses when helpful — "Looking at the existing chapters, it seems like a chapter on X would naturally complement Y — does that match your thinking?"

### Convergence

Before generating files, present a summary:
- Topic name (for context)
- List of new chapters with titles and abstracts
- Noted relationships to existing chapters and other topics

Ask for confirmation before proceeding.

## Phase 2: File Generation

### Chapter stubs

Create one stub file per new chapter in `research/content/<topic>/`:

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

Add the new chapter entries to `research/INDEX.md` under the existing topic section. Follow the existing format:

```markdown
### <topic>/<chapter-file>.md
**Status**: stub

<1-2 sentence abstract>
```

Insert new entries in a logically appropriate position within the topic's section (not necessarily at the end). Preserve all existing content and structure — only add the new entries.

## Phase 3: Summary

Present:
- A tree view of the created files (alongside existing files for context)
- The new INDEX.md entries for review
- A reminder that the next step is `/research-inquiry <topic>/<chapter>.md` for each new chapter

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(add-chapter): <topic>/<chapter-names>`

## Rules

- Do NOT create content — only stub files and INDEX.md entries.
- Do NOT modify existing chapter files or other topics' INDEX.md entries.
- Do NOT modify `research/CLAUDE.md`, `DECISIONS.md`, or `glossary.md`.
- Do NOT create or modify the topic-level entry in INDEX.md — only add chapter entries under it.
- Filenames use lowercase with hyphens, no numeric prefixes.
- Today's date for frontmatter: use the current date in YYYY-MM-DD format.
- Chapter stubs are intentionally minimal — the inquiry phase adds section structure.
