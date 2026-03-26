---
name: research-refine
description: "Refine a topic file by resolving AUDIT comments or applying content-level corrections. Arguments: topic file path, operation (correct|expand|condense|restructure|cross-reference|update|free-text), optional details."
argument-hint: "<topic-file> <operation> [\"details\"]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Edit, WebSearch, WebFetch
---

# Research Refine

You are refining content in a topic file — resolving audit findings, correcting errors, expanding or condensing sections, or applying other content-level changes.

**Arguments**: `$ARGUMENTS`
- First argument: topic file path relative to `research/content/`
- Second argument: operation — `correct`, `expand`, `condense`, `restructure`, `cross-reference`, `update`, or any free-text instruction
- Third argument (optional, quoted): details about what specifically to refine

## Prerequisites

1. Read `research/INDEX.md` and check the topic's status.
   - Status should be `draft` or `audit`. The refine skill can operate on either.
   - If `stub` or `inquiry`, abort: "Content has not been written yet. Run investigation first."
2. Read `research/CLAUDE.md` for conventions.
3. Read the target topic file.
4. Read `research/DECISIONS.md` for relevant prior decisions.
5. If the operation involves cross-references, read the referenced topics.

## Operations

### `correct` — Fix Inaccurate Information

- Identify the inaccurate claim (from details or AUDIT comments with `type: contradiction` or `type: weak-source`).
- Research the correct information using WebSearch and WebFetch.
- Replace the incorrect content with corrected content.
- Update or add references to support the correction.
- Remove the AUDIT comment if it prompted this correction.
- Add a DECISIONS.md entry if the correction changes a previous decision.

### `expand` — Add Depth to a Section

- Identify which section(s) need expansion (from details or AUDIT comments with `type: gap`).
- Research additional content using WebSearch and WebFetch.
- Add content following the project's tone and conventions.
- Add references for new claims.
- Remove related AUDIT comments.

### `condense` — Reduce Verbosity

- Identify which section(s) to condense.
- Tighten prose, remove redundancy, merge overlapping points.
- Preserve all referenced claims and their citations.
- Do NOT remove references.

### `restructure` — Reorganize Within the File

- Reorder sections, merge or split subsections within the topic.
- Update internal cross-references.
- Do NOT change the topic file name or move it — use `/research-restructure` for that.
- Remove related AUDIT comments with `type: flow`.

### `cross-reference` — Improve Links Between Topics

- Identify where cross-references should be added or updated.
- Add links using `[display text](relative-path.md#heading-slug)` format relative to `content/`.
- Verify target sections exist by reading the referenced files.
- Remove related AUDIT comments.

### `update` — Incorporate New Information

- The user provides new information that supersedes existing content.
- Replace outdated content with the new information.
- Add a DECISIONS.md entry explaining the update (this is a turning point).
- Update references — mark old ones and add new ones.
- Remove related AUDIT comments.

### Free-text operation

For any operation not listed above, interpret the user's instruction and apply it. The instruction is scoped to the single topic file. Follow the same patterns: research if needed, update references, resolve related AUDIT comments.

## After Refinement

1. **Update the topic file** with refined content.
2. **Remove resolved AUDIT comments** — only those directly addressed by this refinement.
3. **Check remaining AUDIT comments** in the file:
   - If **ALL** AUDIT comments are resolved AND the topic status is `audit`: advance status to `done` in INDEX.md.
   - If AUDIT comments remain: keep status as `audit`.
   - If status was `draft` (refining without a prior audit): keep as `draft`.
4. Update `updated` date in frontmatter.
5. Present a summary of changes to the user.

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(refine): <topic-name> <operation>`

## Rules

- Only modify ONE topic file per invocation (plus DECISIONS.md and INDEX.md as needed).
- Do NOT change topic structure (file names, directory layout) — use `/research-restructure` for that.
- Do NOT add new sections — only modify existing ones. If a new section is needed, note it as a suggestion.
- Preserve all existing references unless explicitly correcting them.
- When correcting, always explain the correction in DECISIONS.md if it reverses a prior stance.
