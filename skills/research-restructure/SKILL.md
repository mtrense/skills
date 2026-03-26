---
name: research-restructure
description: "Perform structural changes to the research project layout: split, merge, promote, or demote topic files. Arguments: operation (split|merge|promote|demote), topic path, optional target path."
argument-hint: "<operation> <topic-path> [target-path]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Edit, Write
---

# Research Restructure

You are performing structural changes to the research project layout — splitting, merging, promoting, or demoting topic files.

**Arguments**: `$ARGUMENTS`
- First argument: operation — `split`, `merge`, `promote`, `demote`
- Second argument: topic path relative to `research/content/`
- Third argument (optional): target path (required for `merge`)

## Prerequisites

1. Read `research/INDEX.md` to understand the current structure.
2. Read all topic files involved in the operation.
3. Read `research/CLAUDE.md` for conventions.
4. Identify ALL cross-references pointing to the files being restructured by searching all topic files.

## Operations

### `split` — Split a Large Topic File

A single topic file has grown too large and needs to become multiple files.

1. Read the file and identify natural splitting points (major `##` sections).
2. Present the proposed split to the user and get confirmation before proceeding.
3. For each new file:
   - Create the file with proper frontmatter (`created` = today, `updated` = today).
   - Move the relevant content.
   - Preserve all references and AUDIT/CONFIDENCE markers.
   - Maintain the same status as the original file.
4. If the split creates a group, create a directory and place files inside it.
5. Delete the original file.
6. Update INDEX.md:
   - Remove the original entry.
   - Add entries for each new file (with same status).
   - If a directory was created, add a `##` directory entry with an abstract.
7. Rewrite ALL cross-references across the entire research project that pointed to the original file.

### `merge` — Merge Overlapping Topics

Two topics overlap too much and should become one.

1. Read both files.
2. Present the proposed merged structure to the user and get confirmation.
3. Create the merged file:
   - Combine content, eliminating duplication.
   - Use the first file's path as the destination (or a new path if appropriate).
   - Merge frontmatter: use earliest `created`, today for `updated`.
   - Combine references, deduplicate.
   - Keep the most advanced status of the two files.
   - Preserve all AUDIT/CONFIDENCE markers.
4. Delete the second file.
5. If merging empties a directory, remove the directory.
6. Update INDEX.md: remove the second entry, update the first.
7. Rewrite ALL cross-references that pointed to the deleted file.

### `promote` — Convert File to Directory

A standalone file needs to become a directory with child files.

1. Read the file and identify the logical child documents.
2. Present the proposed directory structure to the user and get confirmation.
3. Create the directory named after the file (without `.md`).
4. Create child files inside the directory, distributing content.
5. Delete the original file.
6. Update INDEX.md:
   - Replace the `##` file entry with a `##` directory entry.
   - Add `###` entries for each child file.
7. Rewrite ALL cross-references. Old references to `topic.md#section` become `topic/child.md#section`.

### `demote` — Collapse Directory to File

A directory is too granular and should become a single file.

1. Read all files in the directory.
2. Present the proposed single-file structure to the user and get confirmation.
3. Create the merged file at the parent level (`directory-name.md`).
4. Combine all content in logical order.
5. Delete the directory and all its files.
6. Update INDEX.md:
   - Remove all `###` child entries.
   - Replace the `##` directory entry with a `##` file entry.
7. Rewrite ALL cross-references. Old references to `dir/child.md#section` become `dir.md#section`.

## Cross-Reference Rewriting

This is critical. After any restructure:

1. Use Grep to search ALL files in `research/content/` for references to the old path(s).
2. Also search `research/INDEX.md`, `research/DECISIONS.md`, and `research/glossary.md`.
3. Update every reference to use the new path.
4. Verify no broken references remain.

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(restructure): <operation> <topic-path>`

## Rules

- ALWAYS present the plan and get user confirmation before making changes.
- NEVER lose content — every paragraph, reference, and comment must survive the restructure.
- NEVER change content during restructure — only move it. Content changes belong in `/research-refine`.
- Update `updated` dates in all affected files.
- If a restructure would create conflicts with existing files/directories, abort and explain.
