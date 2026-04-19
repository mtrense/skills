---
name: comparison-add-candidate
description: "Add a candidate stub to a Lineup comparison type: create data/<type>/<candidate>.json with empty values and register it in data/<type>/index.json. Use when declaring a new item to compare (e.g. adding PostgreSQL to databases) without researching its attribute values yet. Arguments: comparison type id, candidate id, optional display name."
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Glob, Write, Edit
argument-hint: "<comparison-type> <candidate-id> [display-name]"
---

# Comparison: Add Candidate

You are adding a new candidate to an existing Lineup comparison type. This skill creates only the scaffold — attribute values are populated later via `/comparison-gather-data`. The separation keeps the commit boundary clean: declaring a candidate is a single small commit; researching its data is another.

## Argument Parsing

`$ARGUMENTS` format (positional, whitespace-delimited):

1. **comparison type id** — kebab-case, must match an existing `data/<type>/` directory.
2. **candidate id** — kebab-case file stem; becomes `<candidate>.json`.
3. **display name** (optional, remainder of the line) — if omitted, infer or ask.

If fewer than two tokens are provided, ask the user for what's missing before proceeding.

## Prerequisites

1. Read the project root `CLAUDE.md` to confirm this is a Lineup project.
2. Confirm `data/<type>/` exists. If not, abort and suggest `/comparison-new-type`.
3. Read `data/<type>/RESEARCH.md` — in particular the **Scope** and **Initial Candidates** sections.
4. Read `data/<type>/attributes.json` — you need the full attribute id list for the scaffold.
5. Confirm `data/<type>/<candidate>.json` does NOT already exist. If it does, abort and suggest `/comparison-gather-data <type> <candidate>` for a refresh instead.
6. Read `data/<type>/index.json` to confirm the candidate id is not already registered.

## Phase 1: Quick Scoping (Interactive, Minimal)

Do NOT run a full Socratic dialogue — the comparison scope is already defined. Only ask when genuinely needed.

1. **Scope fit** — If the candidate is not obviously in-scope per RESEARCH.md's Included/Excluded lists, surface the ambiguity and confirm with the user before adding.
2. **Metadata** — Gather or confirm:
   - **Display name** — Official product/project name (e.g. `PostgreSQL`, not `postgres`).
   - **One-sentence description** — What is this thing? Used as the `description` field and often as a values entry later.
   - **URL** — Official website or primary repository.
   - **Icon** — Optional. Either an existing icon id used elsewhere in the project, a Font Awesome name, or omit.
   - **Shown by default?** — Default `true`. Set `false` for niche entries that shouldn't clutter the initial view.

If the user provided enough via `$ARGUMENTS` and RESEARCH.md mentions the candidate by name, propose all of the above in one shot and ask for confirmation — don't drag out the exchange.

## Phase 2: File Generation

### `data/<type>/<candidate>.json`

Create the scaffold:

```json
{
  "name": "<Display Name>",
  "description": "<one-sentence description>",
  "icon": "<icon or omit>",
  "url": "<official url or omit>",
  "values": {}
}
```

- `values` is intentionally empty. `/comparison-gather-data` fills it.
- Omit `icon` and `url` entirely (don't include as empty strings) if not provided.
- Filename MUST match the candidate id exactly: `<candidate-id>.json`, lowercase, hyphens only.

### Update `data/<type>/index.json`

Append a new candidate entry at the end of the `candidates` array, preserving existing order and whitespace:

```json
{ "id": "<candidate-id>", "shownByDefault": true }
```

Do NOT reorder existing entries.

### Optional: RESEARCH.md checkbox

If the candidate appears in `data/<type>/RESEARCH.md` under any `### Tier N` list (e.g. `- [ ] PostgreSQL — reference open-source RDBMS`), leave the checkbox as `- [ ]`. It gets ticked by `/comparison-gather-data` when data is actually gathered, not here.

If the candidate is *not* listed in RESEARCH.md but the user is adding it anyway, do NOT silently modify RESEARCH.md. Mention this in the summary so the user can decide whether to update RESEARCH.md separately.

## Phase 3: Summary

Present:
- Path of the scaffold file created.
- The new entry added to `data/<type>/index.json`.
- Whether the candidate was already listed in RESEARCH.md (and which tier).
- **Next step**: `/comparison-gather-data <type> <candidate-id>` to research and fill in attribute values.

No commit is created by this skill. Suggest the commit pattern the user should run after gathering data, so that declaration and initial research land in one commit:

```bash
# After running /comparison-gather-data, commit with:
data(<type>): CANDIDATE initial <YYYY-MM-DD HH:MM>
```

If the user wants to commit the scaffold alone (rare), they can still use the same format.

## Git

Do NOT commit.

## Rules

- Do NOT populate any `values` — that's `/comparison-gather-data`.
- Do NOT reorder entries in `data/<type>/index.json`; append only.
- Do NOT modify `attributes.json` or `RESEARCH.md` except for the explicit RESEARCH.md checkbox case noted above (and that is reserved for `/comparison-gather-data`).
- Filenames: lowercase, hyphens, no spaces, no underscores, no numeric prefixes.
- If the JSON you write would break the project's build, abort and report which file is malformed before overwriting anything.
