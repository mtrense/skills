---
name: research-audit-consistency
description: "Audit research topics for cross-topic contradictions and inconsistent terminology. Produces AUDIT directive comments for the refine phase. Arguments: optional topic path."
argument-hint: "[topic-path]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Bash(grep *), Edit, Agent, WebFetch
---

# Research Audit — Consistency

You are auditing research content for cross-topic contradictions. You produce structured AUDIT comments that the refine phase will resolve.

**Arguments**: `$ARGUMENTS`
- First argument (optional): topic path relative to `research/content/` — a file or directory. Omit to audit all topics.

## Prerequisites

1. Read `research/INDEX.md` to identify which topics are in scope.
   - Topics with status `stub` or `inquiry` are skipped (not yet ready for audit).
   - Topics with status `draft`, `audited`, or `done` are eligible.
   - If a specific file is targeted and its status is `stub` or `inquiry`, abort with an error.
2. Read `research/CLAUDE.md` for project conventions.
3. Read all in-scope topic files.
4. Read `research/DECISIONS.md` for prior decisions.
5. Read `research/glossary.md` for term definitions.

## Priority: CONFIDENCE Markers

Before running the audit, resolve outstanding `<!-- CONFIDENCE: low -->` and `<!-- CONFIDENCE: medium -->` markers in the in-scope files. These are the highest priority items.

### Step P1 — collect markers

Scan the in-scope files (use Grep for `<!-- CONFIDENCE:`) and build a marker list. For each match capture:
- `file`, `line`, `level` (`low`/`medium`), and the marker's existing `reason:` text.
- The 1–3 sentences of `claim` text the marker qualifies (typically the lines immediately above the marker, within the same paragraph).
- Any `[citation-key]` slugs already cited in that claim, plus the matching entries from the relevant `<topic>_references.yaml` (URL, title, authors, published, `verified`).

If the list is empty, skip to the cross-topic audit.

### Step P2 — delegate verification

Spawn the `confidence-verifier` subagent via the `Agent` tool with the marker list as input. Pass it the `research/CLAUDE.md` path and the relevant `<topic>_references.yaml` paths so it can reuse existing citation keys.

For very large batches (>30 markers spread across many topics), split by topic file and spawn multiple `confidence-verifier` subagents in parallel — one per topic, each receiving only that file's markers.

### Step P3 — apply decisions

Apply the subagent's `recommended-action` per marker:
- `remove marker; set verified: true on <key>` — delete the marker; update `references.yaml` (`verified: true`, `last-checked: <today>`); ensure the key is in the section's `### References` list.
- `remove marker; add new citation <key> + section reference` — delete the marker; add the new entry to `references.yaml`; add the in-text `[citation-key]` and the `### References` line.
- `keep marker; downgrade low→medium` or `update reason:` — edit the marker in place.
- `convert marker to AUDIT type: contradiction; ref: <URL>` — leave the CONFIDENCE marker; insert an AUDIT comment immediately after the claim. Severity is the audit skill's call (see this skill's severity guide).
- `convert marker to AUDIT type: weak-source` — leave the CONFIDENCE marker; insert an AUDIT comment.
- `skipped` — leave as-is and note in the user-facing summary.

Spot-check with WebFetch only when a `recommended-action` carries unusually high weight (e.g., a contradiction that would force a DECISIONS.md entry).

## Audit Operation: Cross-topic Contradictions

Compare claims across all in-scope topics. Look for:
- Direct contradictions (Topic A says X, Topic B says not-X)
- Inconsistent terminology (same concept, different names)
- Conflicting recommendations or best practices
- Inconsistent use of glossary terms

For each finding:
```html
<!-- AUDIT:
  type: contradiction
  severity: minor | major
  detail: "This section claims X, but <other-topic>#<section> states Y"
  ref: "<other-topic-path>#<section-slug>"
-->
```

## Output

1. **Insert AUDIT comments** directly into the topic files at the relevant locations (immediately after the problematic content).
2. **Remove resolved CONFIDENCE markers** (those that were verified).
3. **Update `research/INDEX.md`**: change status to `audited` only if the file's `audit` frontmatter field now contains all four types (`consistency`, `coverage`, `quality`, `coherence`). Otherwise leave the status unchanged.
4. Update the `updated` date in frontmatter for each modified file.
5. **Track audit progress in frontmatter**: add or update an `audit` field in each audited file's YAML frontmatter listing completed audit types — e.g. `audit: [consistency]`. If the field already exists, append `consistency` to the list (avoid duplicates).
6. **Present a summary** to the user:
   - Number of findings by type and severity
   - List of major findings requiring attention
   - Which topics had their status advanced
   - Any CONFIDENCE markers that could not be resolved

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(audit): <scope> consistency`

## Rules

- Do NOT modify content — only insert/remove comments and update status/dates.
- Do NOT resolve AUDIT findings — that is the refine phase's job.
- Severity guide: `major` = factual errors, direct contradictions. `minor` = inconsistent terminology, style issues.
- If an AUDIT comment already exists at a location, do not duplicate it. Update the existing one if new information changes the assessment.
- A topic can only reach `audited` status in INDEX.md when its frontmatter `audit` field contains all four types: `consistency`, `coverage`, `quality`, `coherence`.
