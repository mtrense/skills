---
name: comparison-new-type
description: "Create a new Lineup comparison type: generate data/<type>/RESEARCH.md, attributes.json, and update data/index.json. Use when adding a new side-by-side comparison (databases, hosting providers, etc.) to a Lineup project. Arguments: comparison type id (kebab-case, required), optional free-text seed."
disable-model-invocation: true
model: opus
allowed-tools: Read, Glob, Write, Edit
argument-hint: "<comparison-type-id> [free-text seed]"
---

# Comparison: New Type

You are creating a new comparison type in a Lineup project. A comparison type lives under `data/<type>/` and consists of:

- `RESEARCH.md` — authoritative research guide (scope, attributes, sources, assessment, initial candidates)
- `attributes.json` — schema derived from RESEARCH.md
- `index.json` — (empty) candidate list, created by this skill
- plus an entry in the top-level `data/index.json`

This skill covers only the *type* — candidates are added later via `/comparison-add-candidate` and researched via `/comparison-gather-data`.

## Argument Parsing

`$ARGUMENTS` format:
- First whitespace-delimited token: **comparison type id** (kebab-case, e.g. `rust-embedded-databases`). Used as the directory name.
- Optional remainder: free-text seed describing what the comparison should cover.

If the id is missing or not kebab-case, ask the user to provide one before proceeding.

## Prerequisites

1. Read `CLAUDE.md` at the project root to confirm this is a Lineup project and to pick up local conventions (commit format, etc.).
2. Read `data/index.json` to see existing comparison types and their shapes.
3. Confirm `data/<type>/` does NOT already exist — if it does, abort and point the user to `/comparison-add-candidate` or direct editing.
4. Skim 1–2 existing `data/*/RESEARCH.md` and `data/*/attributes.json` files to internalize the in-project tone and depth before generating new ones.

## Phase 1: Socratic Scoping (Interactive)

Guide a focused conversation — typically 2–4 rounds, not an interrogation. If a seed was provided, lead with a concrete proposal and ask the user to confirm or redirect ("Here's what I'd suggest based on your seed — let's refine.").

Cover these dimensions:

1. **Purpose** — What decision or question does this comparison help the user make? Who is the intended audience?
2. **Scope** — What items are *included*? What is explicitly *excluded*? (A sharp exclusion list prevents scope creep later.)
3. **Attribute groups** — What thematic clusters of attributes matter? (e.g. "General Information", "Performance", "Ecosystem".) For each group propose 3–8 attributes with:
   - attribute name
   - value type (text / boolean / integer / decimal / date / datetime / filesize / duration / percentage / rating / tags / icon / link)
   - for ranked types: direction (ascending = higher is better, descending = lower is better, neutral = no ranking)
   - for tag types: expected tag set
   - a one-line research note: how to find this value
4. **Initial candidates** — Propose a seed list organized into tiers:
   - **Tier 1 (Must Have)** — undisputed leaders / reference points
   - **Tier 2 (Should Have)** — important contenders
   - **Tier 3 (Nice to Have)** — niche or emerging

Refer to `/Users/mx/projects/lineup/CLAUDE.md` (or the project's own CLAUDE.md) for the exact `ValueType` schema; the cheatsheet below summarizes the common cases.

### Attribute ValueType Cheatsheet

| Human label                 | `valueType` in `attributes.json`                                                                         |
|-----------------------------|----------------------------------------------------------------------------------------------------------|
| Freeform text               | `"text"`                                                                                                 |
| Yes/no                      | `"boolean"`                                                                                              |
| Clickable URL               | `"link"`                                                                                                 |
| Count of things             | `{ "type": "integer", "direction": "ascending" \| "descending" \| "neutral" }`                           |
| Decimal measure             | `{ "type": "decimal", "direction": "ascending" \| "descending" \| "neutral" }`                           |
| Percentage (0–100 or 0–1)   | `{ "type": "percentage", "direction": "ascending" \| "descending" }`                                     |
| File size                   | `{ "type": "filesize", "direction": "ascending" \| "descending" }`                                       |
| Time duration (ms)          | `{ "type": "duration", "direction": "ascending" \| "descending" }`                                       |
| Release year                | `{ "type": "date", "direction": "ascending", "format": "year" }`                                         |
| Release month+year          | `{ "type": "date", "direction": "ascending", "format": "month-year" }`                                   |
| Full date                   | `{ "type": "date", "direction": "ascending", "format": "full" }`                                         |
| Date + time                 | `{ "type": "datetime", "direction": "ascending" }`                                                       |
| Star rating (1–5)           | `{ "lower": 1, "upper": 5, "direction": "ascending", "symbols": { "empty": "☆", "full": "★" } }`         |
| Tag set (license, category) | `{ "type": "tags", "defaultColor": "gray", "tags": [{ "id": "...", "value": "...", "color": "..." }] }` |
| Font Awesome icon           | `{ "type": "icon-fontawesome", "name": "..." }`                                                          |

Rating `symbols.half` is optional for half-stars. Tag IDs are kebab-case; the `value` is the display label.

### Convergence Checkpoint

Before generating files, present a compact summary:
- Comparison type id + display name + one-line description
- Attribute groups with attributes and value types (bulleted, not the full table)
- Initial candidates by tier

Ask: "Ready to generate the files?" Only proceed on explicit confirmation.

## Phase 2: File Generation

### `data/<type>/RESEARCH.md`

Include ALL seven required sections:

1. **Overview** — one paragraph: purpose and what users learn.
2. **Scope** — `**Included:**` and `**Excluded:**` bullet lists. Be specific.
3. **Attribute Groups** — one `### <N>. Group Name` per group, each followed by a markdown table with columns `Attribute | Type | Research Notes`. Type column uses human labels (`text`, `boolean`, `rating (1–5)`, `tags`, etc.) — the machine-readable form goes in `attributes.json`.
4. **Research Sources** — two subsections: `### Primary Sources (Preferred)` and `### Secondary Sources`. Numbered lists, each entry naming the source and what it's useful for.
5. **Assessment Guidelines** — bullet list, one per ambiguous attribute or threshold (`**Attribute Name**: specific criteria`). Explicitly state when `null` is preferable to a guessed value.
6. **Initial Candidates** — `### Tier 1 (Must Have)`, `### Tier 2 (Should Have)`, `### Tier 3 (Nice to Have)`. Each candidate as `- [ ] <Name> — <reason for inclusion>`. Checkboxes get ticked later when data is gathered.
7. **Notes for Researchers** — numbered list of general principles: verify sources, cite with URLs, use `null` with comment when uncertain, note version/date of time-sensitive facts.

Match the tone and depth of existing `data/*/RESEARCH.md` files in the project.

### `data/<type>/attributes.json`

Derive directly from the attribute tables in RESEARCH.md. Structure:

```json
{
  "name": "<Display Name>",
  "description": "<one-sentence what this comparison covers>",
  "groups": [
    {
      "id": "<group-id>",
      "name": "<Group Display Name>",
      "description": "<optional>",
      "expandedByDefault": true,
      "attributes": [
        { "id": "<attr-id>", "name": "<Display>", "valueType": "text", "description": "<optional tooltip>" }
      ]
    }
  ]
}
```

- `id` fields are kebab-case.
- First 1–2 groups should have `expandedByDefault: true`; deeper groups can default to `false`.
- For tag attributes, seed a sensible initial tag list derived from the RESEARCH.md notes; users can add more later.
- Every attribute needs a `valueType`. Every ranked type needs a `direction`.

### `data/<type>/index.json`

Create as:

```json
{
  "candidates": []
}
```

Empty — candidates are added via `/comparison-add-candidate`.

### Update `data/index.json`

Append a single entry at the end of the `comparisons` (or top-level) array, preserving all existing entries and whitespace:

```json
{
  "id": "<type>",
  "name": "<Display Name>",
  "description": "<one-sentence description>"
}
```

## Phase 3: Summary

Present:
- Tree of created files under `data/<type>/`.
- Confirmation that `data/index.json` was updated.
- The expected commit command, multi-`-m` format (per the project's CLAUDE.md):

```bash
git add data/index.json data/<type>/
git commit -m "data(<type>): RESEARCH" \
  -m "<1–2 sentence summary of the comparison and its intended audience>" \
  -m "🤖 Generated with [Claude Code](https://claude.com/claude-code)" \
  -m "Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

Remind the user that the next step is `/comparison-add-candidate <type> <candidate-id>` for each initial candidate they want to track.

## Git

Do NOT commit. Print the exact command the user can run (or they can use the project's `/commit` skill if one is installed).

## Rules

- Do NOT create candidate JSON files — that's `/comparison-add-candidate`.
- Do NOT invent candidates the user didn't discuss; keep the initial list aligned with Phase 1.
- JSON output MUST be valid: ASCII quotes, no trailing commas, no comments inside `.json` files.
- kebab-case for all `id` fields (comparison type, group, attribute, tag).
- Match existing project style: indentation, attribute ordering within groups (generic → specific), tone in RESEARCH.md.
- If a required file or directory is missing (no `data/`, no `CLAUDE.md`), abort and explain rather than improvising.
