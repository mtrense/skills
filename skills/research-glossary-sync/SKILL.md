---
name: research-glossary-sync
description: "Reconcile glossary.md against current topic content — add new terms, update changed definitions, remove unused terms. Run after any content-changing phase. Fans out per-topic candidate extraction to `term-extractor` subagents in parallel."
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Edit, Write, Agent
---

# Research Glossary Sync

You are synchronising `research/glossary.md` with the current state of all topic content. You orchestrate one `term-extractor` subagent per topic file in parallel, then merge the candidate lists into the project glossary.

**No arguments required** — this skill scans all topic files.

## Process

### Step 1: Orient

1. Read `research/glossary.md` (if it exists; otherwise note absence and create later).
2. Read `research/CLAUDE.md` for conventions.
3. Read `research/INDEX.md` to enumerate topic files in scope and understand the topic structure.
4. Use Glob to enumerate all `.md` files under `research/content/` (excluding `_references.yaml`).

You do NOT need to read the topic files themselves — the per-topic `term-extractor` subagents do that.

### Step 2: Fan out per topic

Spawn one `term-extractor` subagent per topic file via the `Agent` tool. Send the spawns **in a single message** so they run concurrently. For very large projects (>15 topic files), batch into groups of ~10 spawns per message.

Each spawn's prompt contains:
- The absolute path to the topic file.
- The path to `research/CLAUDE.md`.
- The full text (or path, if reasonable) of the existing `research/glossary.md` if it exists, so the subagent can flag refinements vs. matches vs. new candidates.

If a subagent returns `Candidates: (skipped — no investigated content)`, exclude that file from the merge.

### Step 3: Merge candidate lists

Walk the union of all subagent reports' `Candidates` sections.

For each distinct term (case-folded, hyphenation-normalised):

- **New** (`glossary-status: not-in-glossary` from every reporting topic) → add to glossary, using the highest-confidence subagent's `derived-definition` as the seed. Synthesise across reporters when their definitions agree.
- **Matches** (every reporter says `matches`, no `refinement`) → keep existing glossary entry as-is.
- **Refinement** (any reporter flagged `refinement`) → reconcile. If reporters agree on the refinement, update the glossary entry. If reporters disagree, prefer the definition that is **most consistent with how the term is actually used across topics**, and consider adding a parenthetical note ("usage varies; see <topic>"). When in doubt, keep existing and surface the conflict in the user-facing summary as a judgment call.
- **Illustrates only** (no refinement, just usage examples) → keep existing entry; consider adding a `See [topic](path.md#section)` cross-reference if no link exists yet.

Filter out candidates with `confidence: low` unless multiple topics independently surfaced the same term. A term flagged `low` by one topic and `high` by another is still a candidate — the orchestrator's union of confidence levels matters more than any single report.

### Step 4: Resolve unused terms

For each existing glossary term:
- It is **truly unused** when **every** subagent report listed it under `Unused-In-This-Topic Glossary Terms` AND no candidate in any report names it (under any kind). Remove these.
- It is **used** when at least one report names it as a candidate or fails to list it under unused. Keep these.

When in doubt, keep — losing a definition is more costly than carrying a dead one.

### Step 5: Update Glossary

The glossary is organised by domain area using headings:

```markdown
---
title: "Glossary"
created: <original-date>
updated: <today>
---

# Glossary

## <Domain Area 1>

**term-a**: Definition of term A.

**term-b**: Definition of term B. See [relevant topic](content-path.md#section).

## <Domain Area 2>

**term-c**: Definition of term C.
```

Rules:
- Group terms under domain-area headings (e.g., "## Authentication", "## Data Pipelines"). Use the section/heading where each term most prominently appears (the subagent reports include `section`) as a hint for grouping.
- Within each group, sort terms alphabetically.
- Definitions should be concise (1-2 sentences).
- Include a reference link if the definition comes from or is best explained in a specific topic section. Use the strongest-evidence section reported by the subagent.
- Use `**term**:` format (bold term, colon, space, definition).
- If a term spans multiple domains, place it in the most primary one and cross-reference.

### Step 6: Summary

Present to the user:
- Terms added (with their definitions, and which topic(s) surfaced them)
- Terms updated (with old vs. new, and which topic(s) prompted the refinement)
- Terms removed (with reason — typically "no topic references this term")
- Judgment calls: terms where reporters disagreed on the definition, with the resolution chosen
- Any subagent that returned `(skipped — no investigated content)` so the user knows which topics were excluded

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(glossary): sync after <phase/topic>`

## Rules

- Do NOT modify any topic files — only `research/glossary.md`.
- Do NOT invent definitions. Every definition must trace to at least one subagent report's `derived-definition`.
- Do NOT call WebSearch or WebFetch. Glossary derivation is purely from project text.
- Update the `updated` date in glossary frontmatter.
- If the glossary file doesn't exist yet, create it with proper frontmatter.
- Tolerate subagent failures — if one spawn errored, proceed with the remaining reports and note the missing topic in the summary.
