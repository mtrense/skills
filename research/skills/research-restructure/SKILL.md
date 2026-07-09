---
name: research-restructure
description: "Perform structural changes to the research project layout: split, merge, promote, demote, nest, or flatten chapters. Operates at any depth in the topic tree. Arguments: operation, chapter path, optional target path."
argument-hint: "<operation> <chapter-path> [target-path]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Edit, Write
---

# Research Restructure

You are performing structural changes to the research project layout — splitting, merging, promoting, demoting, nesting, or flattening chapters. All operations work at any depth in the topic tree (top-level topics, chapters, sub-chapters, sub-sub-chapters).

**Arguments**: `$ARGUMENTS`
- First argument: operation — `split`, `merge`, `promote`, `demote`, `nest`, `flatten`
- Second argument: chapter path relative to `research/content/` (file or directory, depending on op)
- Third argument: target path — required for `merge` and `nest`, optional for others

**Terminology recap** — a *topic* is a top-level node under `content/`; a *chapter* is any `.md` file at any depth within a topic. `promote` turns a chapter file into a directory; `demote` is the inverse. `nest`/`flatten` move a chapter deeper or shallower within the tree without changing its file vs. directory status.

## Prerequisites

1. Read `research/INDEX.md` to understand the current structure and depth of the affected paths.
2. Read all chapter files (and `_references.yaml` siblings) involved in the operation.
3. Read `research/CLAUDE.md` for conventions.
4. Identify ALL cross-references pointing to the files being restructured by grepping every file under `research/content/`, plus `INDEX.md`, `DECISIONS.md`, and `glossary.md`.

## Operations

All operations preserve depth conventions: heading level in `INDEX.md` matches path depth (`##` for top-level, `###` for one level in, `####` for two levels in, etc.). After any move, recompute heading levels for every affected entry. Every leaf chapter entry is a markdown link — `### [<path>](content/<path>)` where `<path>` is relative to `content/` — so when a chapter's path changes, update **both** the link text and the link target. Directory group entries stay plain-text path headings with no link.

### `split` — Split a Large Chapter

A single chapter has grown too large and needs to become multiple chapters.

1. Read the chapter and identify natural splitting points (major `##` sections).
2. Present the proposed split to the user and get confirmation. State explicitly whether the split keeps the new chapters as siblings at the same depth, or creates a new sub-directory to group them (effectively `split` + `promote` in one step).
3. For each new chapter:
   - Create the file with proper frontmatter (`created` = today, `updated` = today).
   - Move the relevant content.
   - Preserve all references and AUDIT/CONFIDENCE markers. Move relevant entries from the original `_references.yaml` to each new chapter's `_references.yaml`.
   - Maintain the same status as the original chapter.
4. If the split creates a new sub-directory, create the directory and place files inside it.
5. Delete the original chapter file and its `_references.yaml`.
6. Update `INDEX.md`:
   - Remove the original entry.
   - Add entries for each new chapter at the correct heading level for their depth.
   - If a directory was created, add a directory entry (at the matching heading level) with an abstract.
7. Rewrite ALL cross-references across the entire research project that pointed to the original path.

### `merge` — Merge Overlapping Chapters

Two chapters overlap too much and should become one. They need not be siblings; this op also handles "fold this nested chapter back into its parent."

1. Read both chapters.
2. Present the proposed merged structure to the user and get confirmation, including which path will survive.
3. Create the merged chapter:
   - Combine content, eliminating duplication.
   - Use the first chapter's path as the destination (or a new path if appropriate).
   - Merge frontmatter: use earliest `created`, today for `updated`.
   - Combine references, deduplicate. Merge both `_references.yaml` files and consolidate the markdown `### References` lists.
   - Keep the most advanced status of the two chapters.
   - Preserve all AUDIT/CONFIDENCE markers.
4. Delete the second chapter and its `_references.yaml`.
5. If merging empties a directory, remove the empty directory and its `INDEX.md` directory entry.
6. Update `INDEX.md`: remove the second entry, update the first; recompute heading levels for any entries whose depth changed.
7. Rewrite ALL cross-references that pointed to the deleted path.

### `promote` — Convert Chapter File to Directory

A chapter at any depth needs to become a directory with child chapters. Works the same whether the chapter is a top-level topic file or already nested several levels deep.

1. Read the chapter and identify the logical child documents.
2. Present the proposed directory structure to the user and get confirmation.
3. Create the directory at the chapter's current path (without `.md`). If a `_references.yaml` exists, keep it at the parent — rename to live alongside the directory (`<dir>/<dir>_references.yaml` is acceptable; children can also have their own).
4. Create child chapter files inside the directory, distributing content.
5. Delete the original chapter file.
6. Update `INDEX.md`:
   - Convert the chapter entry to a directory entry at the same heading level (no status field).
   - Add child entries one level deeper.
7. Rewrite ALL cross-references. Old references to `<path>/<name>.md#section` become `<path>/<name>/<child>.md#section`.

### `demote` — Collapse Directory to a Single Chapter

A directory is too granular and should become a single chapter file at the same depth. Allowed at any depth, not just top-level.

1. Read all chapters in the directory (recursively, if it contains sub-directories — in that case, warn the user and ask for explicit confirmation that nesting will be lost).
2. Present the proposed single-chapter structure to the user and get confirmation.
3. Create the merged chapter file at the directory's parent (`<parent>/<directory-name>.md`).
4. Combine all content in logical order; collapse child chapter `#` headings into `##`/`###` sections as appropriate.
5. Merge all child `_references.yaml` files into one at the new chapter's location.
6. Delete the directory and all its contents.
7. Update `INDEX.md`:
   - Remove all child entries (at every depth under the directory).
   - Convert the directory entry to a chapter entry at the same heading level, with the merged content's status.
8. Rewrite ALL cross-references. Old references to `<path>/<name>/<child>.md#section` become `<path>/<name>.md#<rehomed-anchor>` — pick the best matching anchor in the new combined file.

### `nest` — Move a Chapter Under Another Chapter

A chapter belongs conceptually under a sibling (or any other chapter) and should live as its child.

1. Resolve the target: if `<target-path>` is a directory, the chapter moves into it. If it is a `.md` chapter file, run an implicit `promote` on the target first (with user confirmation), then move the source into the resulting directory.
2. Confirm the move with the user, showing the before/after path.
3. Move the chapter file and its `_references.yaml` and `_assets/` sibling, if any, into the target directory. Keep the chapter's filename.
4. Update `INDEX.md`:
   - Remove the chapter's old entry.
   - Insert a new entry under the target directory, at the heading level matching the new depth.
   - If the target was promoted, also add a directory entry for it.
5. Rewrite ALL cross-references with the new path.

### `flatten` — Move a Chapter Up One Level

A chapter is nested too deep and should sit at its grandparent level.

1. Confirm with the user that the chapter's current parent directory will remain (unless empty, in which case offer to remove it).
2. Move the chapter file and its `_references.yaml` / `_assets/` siblings to the grandparent directory. If a name collision exists, abort and ask the user to rename first.
3. If the parent directory is now empty, remove it and its `INDEX.md` directory entry.
4. Update `INDEX.md`:
   - Remove the chapter's old entry.
   - Re-insert it at the grandparent level, with the heading level matching the new depth.
5. Rewrite ALL cross-references with the new path.

## Cross-Reference Rewriting

This is critical. After any restructure:

1. Use Grep to search ALL files in `research/content/` (including `_references.yaml` files) for references to the old path(s).
2. Also search `research/INDEX.md`, `research/DECISIONS.md`, and `research/glossary.md`.
3. Update every reference to use the new path.
4. Rename `_references.yaml` files to match their new topic filenames.
4. Verify no broken references remain.

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(restructure): <operation> <chapter-path>`

## Rules

- ALWAYS present the plan and get user confirmation before making changes.
- NEVER lose content — every paragraph, reference (both `references.yaml` entries and markdown citations), and comment must survive the restructure.
- NEVER change content during restructure — only move it. Content changes belong in `/research-refine`.
- Update `updated` dates in all affected files.
- After any move, every affected `INDEX.md` heading must match its path depth (`##` = top-level, `###` = depth 2, `####` = depth 3, …). Recompute don't assume.
- If a restructure would create conflicts with existing files/directories, abort and explain.
