---
name: comparison-add-candidate
description: "Add a candidate stub to a Lineup comparison type: create data/<type>/<candidate>.json with empty values and register it in data/<type>/index.json. Use when declaring a new item to compare (e.g. adding PostgreSQL to databases) without researching its attribute values yet. Arguments: comparison type id (required), optional candidate id (auto-picked from RESEARCH.md when omitted), optional display name."
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Glob, Write, Edit, Bash
argument-hint: "<comparison-type> [candidate-id] [display-name]"
---

# Comparison: Add Candidate

You are adding a new candidate to an existing Lineup comparison type. This skill creates only the scaffold — attribute values are populated later via `/comparison-gather-data`. The separation keeps the commit boundary clean: declaring a candidate is a single small commit; researching its data is another.

## Argument Parsing

`$ARGUMENTS` format (positional, whitespace-delimited):

1. **comparison type id** — kebab-case, must match an existing `data/<type>/` directory.
2. **candidate id** (optional) — kebab-case file stem; becomes `<candidate>.json`. When omitted, auto-pick the next unscaffolded Tier entry from `RESEARCH.md` (see **Auto-Pick** below).
3. **display name** (optional, remainder of the line) — if omitted, infer or ask. Ignored under auto-pick (the display name comes from RESEARCH.md).

If the comparison type id is missing, ask for it before proceeding. If only the comparison type is provided, run auto-pick.

## Prerequisites

1. Read the project root `CLAUDE.md` to confirm this is a Lineup project.
2. Confirm `data/<type>/` exists. If not, abort and suggest `/comparison-new-type`.
3. Read `data/<type>/RESEARCH.md` — in particular the **Scope** and **Initial Candidates** sections (needed for auto-pick AND for scope-fit checks under explicit mode).
4. Read `data/<type>/attributes.json` — you need the full attribute id list for the scaffold.
5. Read `data/<type>/index.json` — needed to detect already-scaffolded candidates.
6. Under explicit mode only: confirm `data/<type>/<candidate>.json` does NOT already exist. If it does, abort and suggest `/comparison-gather-data <type> <candidate>` for a refresh instead.

## Auto-Pick (when candidate id is omitted)

Scan `RESEARCH.md`'s `### Tier N` lists for the first `- [ ] <Name> — …` entry whose derived candidate id is NOT already present in `data/<type>/index.json` and has no `data/<type>/<id>.json` file. Priority order: Tier 1 → Tier 2 → Tier 3, preserving in-tier order.

- **Deriving the candidate id**: kebab-case of the display name — lowercase, ASCII, spaces and punctuation → hyphens, collapse runs, trim leading/trailing hyphens. `PostgreSQL` → `postgresql`; `Amazon RDS` → `amazon-rds`; `MySQL / MariaDB` → choose ONE and surface the ambiguity to the user.
- **Presenting the pick**: show the Tier, display name, derived id, and the line's rationale. Then ask the user to confirm (or override the id). Do not proceed without confirmation — the id becomes the filename and is expensive to change later.
- **Nothing to pick**: if every Tier entry in RESEARCH.md is already scaffolded (or the Tier lists are empty), report the state and stop. Suggest the user either add a new Tier entry to RESEARCH.md or pass an explicit candidate id.

Once the user confirms the pick, continue as if it had been passed explicitly. Skip scope-fit confirmation in Phase 1 (the Tier listing already asserts scope fit).

## Phase 1: Quick Scoping (Interactive, Minimal)

Do NOT run a full Socratic dialogue — the comparison scope is already defined. Only ask when genuinely needed.

1. **Scope fit** — If the candidate is not obviously in-scope per RESEARCH.md's Included/Excluded lists, surface the ambiguity and confirm with the user before adding.
2. **Metadata** — Gather or confirm:
   - **Display name** — Official product/project name (e.g. `PostgreSQL`, not `postgres`).
   - **One-sentence description** — What is this thing? Used as the `description` field and often as a values entry later.
   - **URL** — Official website or primary repository.
   - **Icon** — Optional. Either an existing icon id used elsewhere in the project, a Font Awesome name, or omit.
   - **Shown by default?** — Default `true`. Set `false` for niche entries that shouldn't clutter the initial view.
3. **Tier assignment** (explicit mode only, and only when the candidate is NOT already listed in RESEARCH.md) — Propose a tier (1/2/3) and ask the user to confirm. Default to Tier 3 (Nice to Have) unless the candidate is clearly a reference point (→ Tier 1) or a well-known contender (→ Tier 2). Under auto-pick, skip this step — the candidate's tier comes from its existing RESEARCH.md entry.

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

### Update RESEARCH.md

- **If the candidate is already listed** under any `### Tier N` list (e.g. `- [ ] PostgreSQL — reference open-source RDBMS`): leave the line untouched. The checkbox stays `- [ ]` — it gets ticked by `/comparison-gather-data` when data is actually gathered, not here.
- **If the candidate is NOT listed** (explicit mode, scope-fit confirmed, tier assigned in Phase 1): append a new entry to the end of the selected `### Tier N` list using the format:

  ```
  - [ ] <Display Name> — <one-sentence description> (added <YYYY-MM-DD>)
  ```

  Fetch today's date via Bash (`date +%Y-%m-%d`) — do not hand-type it. The `(added <date>)` suffix records the post-scoping addition so future audits can distinguish these from candidates that came out of the initial scoping dialogue.

## Phase 3: Summary

Present:
- Path of the scaffold file created.
- The new entry added to `data/<type>/index.json`.
- RESEARCH.md status: either "already listed under Tier N (untouched)" or "appended to Tier N with `(added <date>)` suffix".
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
- Do NOT modify `attributes.json`.
- Do NOT tick an existing RESEARCH.md checkbox (`- [ ]` → `- [x]`); that's `/comparison-gather-data`'s job. The only RESEARCH.md edit this skill performs is appending a new `- [ ]` line for candidates not yet listed.
- Filenames: lowercase, hyphens, no spaces, no underscores, no numeric prefixes.
- If the JSON you write would break the project's build, abort and report which file is malformed before overwriting anything.
