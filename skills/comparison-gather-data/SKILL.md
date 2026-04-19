---
name: comparison-gather-data
description: "Research and populate attribute values for a Lineup candidate using the comparison type's RESEARCH.md as the guide. Actively searches the web for authoritative sources and records {value, source, comment} per attribute. Use for initial research or to refresh stale values. Arguments: comparison type, candidate id, optional attribute id or group id to scope the work."
disable-model-invocation: true
model: opus
allowed-tools: Read, Glob, Grep, Write, Edit, WebSearch, WebFetch, Bash
argument-hint: "<comparison-type> <candidate> [attribute-id-or-group]"
---

# Comparison: Gather Data

You are researching attribute values for a single Lineup candidate and writing them into `data/<type>/<candidate>.json`. The authoritative guide for *what* to research and *how* to assess it is the comparison type's `RESEARCH.md`; your job is to follow it, cite sources, and be honest about uncertainty.

## Argument Parsing

`$ARGUMENTS` (positional):

1. **comparison type id** — must match an existing `data/<type>/` directory.
2. **candidate id** — must match an existing `data/<type>/<candidate>.json` file.
3. **scope filter** (optional) — either an attribute id (`license`, `horizontal-scaling`) or a group id (`general`, `performance`). When omitted, research every attribute defined in `attributes.json`.

If the first two tokens are missing, ask the user. If the scope filter doesn't match any known attribute or group, list the valid options and ask.

## Prerequisites

1. Read the project root `CLAUDE.md` (commit format, shell rules).
2. Read `data/<type>/RESEARCH.md` — focus on:
   - **Attribute Groups** tables (the Research Notes column is your playbook per attribute)
   - **Research Sources** (Primary > Secondary — prioritize accordingly)
   - **Assessment Guidelines** (thresholds, when to use `null`)
3. Read `data/<type>/attributes.json` — authoritative for attribute ids, types, and tag sets.
4. Read `data/<type>/<candidate>.json` — existing metadata and any previously gathered values.
5. Determine **mode**:
   - `initial` — if `values` is empty or missing most attributes.
   - `refresh` — if the file already contains substantive values. In refresh mode, prefer updating values with newer sources and explicitly note in a `comment` when a value changed significantly.

## Phase 1: Plan the Research Pass

Before any web search, build a mental (or written-to-user) list of attributes in scope:

- If no scope filter: list every attribute from `attributes.json`, grouped as in RESEARCH.md.
- If scope is a group id: list attributes in that group only.
- If scope is a single attribute id: that one attribute.

Briefly announce the plan to the user ("Researching 14 attributes across 3 groups for `postgresql` in `databases`, initial mode.") so they can interrupt if the scope is wrong. Then proceed without further Socratic exchange.

## Phase 2: Research Loop

For each in-scope attribute, in the order declared by `attributes.json`:

1. **Consult RESEARCH.md's Research Notes** for that attribute — this often dictates which source type to hit first.
2. **Search primary sources first.** Use `WebSearch` for discovery and `WebFetch` to verify specific claims. Favor: official website, official docs, official repository, official release notes. Fall back to secondary sources (Wikipedia, rankings sites, community wikis) when primary sources are silent.
3. **Match the attribute's `valueType`** when writing the value (see cheatsheet below).
4. **Record `{value, source, comment}`**:
   - `value` — typed per `valueType`. Use `null` when genuinely indeterminate or not applicable (per RESEARCH.md's Assessment Guidelines).
   - `source` — array of fetched URLs that back the value. Include the most authoritative 1–3, not a dump.
   - `comment` — short free-text. Add when: the value is `null` (explain why), the value needed interpretation (cite the specific guideline), the value is contested, or the value is time-sensitive (include the date you checked).
5. **Be honest about uncertainty.** If a reasonable researcher would disagree, pick the most defensible value and note the ambiguity in `comment`. Do NOT invent sources. Do NOT cite URLs you haven't fetched.
6. **Dates**: for `date` valueType with `format: "year"`, write `"2024"`. For `month-year`, `"2024-01"`. For `full`, `"2024-01-15"`. Store ISO 8601 strings.
7. **Tags**: the `value` is a `string[]` of tag ids already defined in `attributes.json`. If the right tag is missing, prefer using an existing tag and noting the nuance in `comment` over editing `attributes.json` mid-research. If a tag is clearly needed and genuinely generic, flag it to the user before editing `attributes.json`.
8. **Booleans**: apply the threshold from RESEARCH.md's Assessment Guidelines (e.g. "ACID compliant only if full ACID by default"). Borderline cases → `comment` with the reasoning.

### ValueType → `value` cheatsheet

| `valueType`                 | `value` shape                          | Example                                                 |
|-----------------------------|----------------------------------------|---------------------------------------------------------|
| `"text"` / `"link"` / icon  | string                                 | `"PostgreSQL"` / `"https://example.com"`                |
| `"boolean"`                 | boolean                                | `true`                                                  |
| `integer` / `decimal` / `percentage` / `filesize` / `duration` | number | `15000` / `3.14` / `99.95`                              |
| `date` / `datetime`         | ISO 8601 string (see Phase 2.6)        | `"1996"` / `"2024-01"` / `"2024-01-15T14:30:00"`        |
| `rating`                    | number within `[lower, upper]`         | `4.5`                                                   |
| `tags`                      | array of tag ids from `attributes.json`| `["mit", "apache2"]`                                    |
| indeterminate / N/A         | `null` + `comment`                     | `{ "value": null, "comment": "closed-source" }`         |

## Phase 3: Write the Candidate File

Write the full updated `data/<type>/<candidate>.json`:

- Preserve top-level metadata (`name`, `description`, `icon`, `url`) unchanged unless the user explicitly asked for a refresh of those too.
- Order entries inside `values` to match the attribute order in `attributes.json` (improves diffs and readability).
- Keep JSON strictly valid: double quotes, no trailing commas, no comments.

### RESEARCH.md checkbox (initial mode only)

If the candidate appears in any `### Tier N` list in `RESEARCH.md` with an unchecked box (`- [ ] <Name>` or `- [ ] <candidate-id>`), switch it to `- [x]` now that real data exists. Match on the display name OR the candidate id; do not touch unrelated lines.

## Phase 4: Summary

Present to the user:

- Mode used (`initial` / `refresh`).
- Count of attributes populated vs. set to `null` (with a short rationale for each `null`).
- Any `comment`s worth the user's attention (contested values, tag gaps, time-sensitive notes).
- The exact commit command, using the project's multi-`-m` format (per CLAUDE.md) and Lineup's candidate commit convention:

```bash
git add data/<type>/<candidate>.json data/<type>/RESEARCH.md
git commit -m "data(<type>): CANDIDATE <initial|refresh> <YYYY-MM-DD HH:MM>" \
  -m "<summary of findings and notable comments>" \
  -m "🤖 Generated with [Claude Code](https://claude.com/claude-code)" \
  -m "Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

Use `date +"%Y-%m-%d %H:%M"` via Bash to fetch the current timestamp at summary time, then substitute it into the command you print.

If you also modified `data/<type>/index.json` (rare — only happens when the candidate's `shownByDefault` flag needs flipping as part of the research outcome), include it in `git add`.

## Git

Do NOT commit. The user will review and run the commit command.

## Rules

- Do NOT fabricate sources. Every URL in `source` must have been fetched successfully by `WebFetch`.
- Do NOT set `source: []` silently. If a value has no source (e.g. derived trivially from the candidate's own name), say so in `comment`.
- Do NOT invent attribute ids. Every key in `values` MUST match an `attribute.id` in `attributes.json`.
- Do NOT change the candidate's `name`, `description`, `icon`, or `url` unless explicitly asked.
- Do NOT edit `attributes.json` in the middle of a research pass. If a tag set or attribute definition is clearly wrong, flag it to the user and stop; the user can fix it and restart.
- Respect RESEARCH.md's Assessment Guidelines literally. When a guideline says "mark `true` only if X", do not round up.
- When refreshing, never silently drop a previously-recorded value. If you can't verify it, keep it and add a `comment` noting the verification failure, or replace with the new value and note the change.
- Stop and ask if a Primary Source contradicts itself or another Primary Source — surface it to the user instead of picking a side arbitrarily.
