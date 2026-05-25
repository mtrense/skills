---
name: research-add-chapter
description: "Add new chapter stubs to an existing directory in the topic tree. Works at any depth — a top-level topic directory or a nested sub-directory. Argument: parent directory path (relative to research/content/)."
argument-hint: "<parent-directory>"
disable-model-invocation: true
model: opus
allowed-tools: Read, Glob, Write, Edit
---

# Research Add Chapter

You are adding one or more new chapters (markdown stub files) under an existing directory in the topic tree. A chapter is a `.md` file at any depth under `research/content/`. This skill bridges the gap between topic creation and chapter-level inquiry, and works equally for adding a sibling chapter to a top-level topic or to a deeply nested sub-chapter group.

**Parent directory**: `research/content/$ARGUMENTS`

## Prerequisites

1. Read `research/CLAUDE.md` for project conventions, tone, scope, and goals.
2. Read `research/INDEX.md` to understand existing topics, chapters, and their depth.
3. Resolve the target path under `research/content/`:
   - If the directory exists, proceed.
   - If the path does not exist at all, abort and explain. The user may want `/research-add-topic` (for a brand-new top-level topic) or `/research-restructure nest` (to relocate an existing chapter).
   - If the path points to a single `.md` chapter file rather than a directory, do not silently fail. Tell the user that the target needs to become a directory first via `/research-restructure promote <path>`, and offer to walk them through it. Do not call the other skill yourself — abort here and let the user run it.
4. Compute the target's depth (count `/` separators in the relative path under `content/`). The new chapter entries will be inserted at depth + 1, so their `INDEX.md` heading level will be `##` + (target_depth) `#` characters — e.g. a chapter added under a top-level topic dir is `###`; under a sub-chapter dir is `####`.
5. List existing chapter files in the target directory (top-level only — sub-directories belong to their own scopes) to understand what's already covered.

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

Create one stub file per new chapter in the target directory (`research/content/<parent-directory>/`):

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

Add the new chapter entries to `research/INDEX.md` under the existing directory section, using the heading level computed in step 4 of Prerequisites. Follow the existing format — for a new chapter under `data-pipelines/` (depth 1):

```markdown
### data-pipelines/<chapter-file>.md
**Status**: stub

<1-2 sentence abstract>
```

Or for a new chapter under `api-design/rest/` (depth 2):

```markdown
#### api-design/rest/<chapter-file>.md
**Status**: stub

<1-2 sentence abstract>
```

Insert new entries in a logically appropriate position within the parent's section (not necessarily at the end). Preserve all existing content and structure — only add the new entries.

## Phase 3: Summary

Present:
- A tree view of the created files (alongside existing files for context)
- The new INDEX.md entries for review, with their heading levels
- A reminder that the next step is `/research-inquiry <parent>/<chapter>.md` for each new chapter

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(add-chapter): <parent>/<chapter-names>`

## Rules

- Do NOT create content — only stub files and INDEX.md entries.
- Do NOT modify existing chapter files or other branches of INDEX.md.
- Do NOT modify `research/CLAUDE.md`, `DECISIONS.md`, or `glossary.md`.
- Do NOT create or modify the parent directory's own entry in INDEX.md — only add child chapter entries under it.
- INDEX.md heading level MUST match the new chapter's path depth. Recompute don't assume.
- Filenames use lowercase with hyphens, no numeric prefixes.
- Today's date for frontmatter: use the current date in YYYY-MM-DD format.
- Chapter stubs are intentionally minimal — the inquiry phase adds section structure.
