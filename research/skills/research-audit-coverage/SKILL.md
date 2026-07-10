---
name: research-audit-coverage
description: "Audit research topics for gaps relative to the research plan. Produces AUDIT directive comments for the refine phase. Arguments: optional topic path."
argument-hint: "[topic-path]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Bash(grep *), Bash(bash */skills/research-status/research-status.sh *), Edit, Agent, WebFetch
---

# Research Audit — Coverage

You are auditing research content for gaps relative to the research plan. You produce structured AUDIT comments that the refine phase will resolve.

**Arguments**: `$ARGUMENTS`
- First argument (optional): topic path relative to `research/content/` — a file or directory. Omit to audit all topics.

## Prerequisites

1. Derive each topic's status to identify which topics are in scope. Run `bash <skills-root>/research-status/research-status.sh research` for the whole project (or `--path <target>` when a topic is targeted) and read the first whitespace-delimited field of each line. (`<skills-root>` is the `.claude/skills/` directory the research skills are installed in — `~/.claude/skills` for a global install, `<project>/.claude/skills` for a project install.)
   - Topics with derived status `stub` or `inquiry` are skipped (not yet ready for audit).
   - Topics with derived status `draft`, `audited`, or `done` are eligible.
   - If a specific file is targeted and its derived status is `stub` or `inquiry`, abort with an error.
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

If the list is empty, skip to the gap audit.

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

## Audit Operation: Gaps Relative to Research Plan

Compare content against the research plan in INDEX.md:
- Are all planned topics addressed?
- Are there obvious subtopics missing that related topics reference?
- Do cross-references point to sections that don't exist or are stubs?
- Are there areas mentioned in content but not tracked in INDEX.md?

For each finding:
```html
<!-- AUDIT:
  type: gap
  severity: minor | major
  detail: "Section references 'caching strategies' but no topic covers this"
  ref: "<relevant-index-entry-or-topic>"
-->
```

## Output

1. **Insert AUDIT comments** directly into the topic files at the relevant locations (immediately after the problematic content).
2. **Remove resolved CONFIDENCE markers** (those that were verified).
3. Update the `updated` date in frontmatter for each modified file.
4. **Track audit progress in frontmatter**: add or update an `audit` field in each audited file's YAML frontmatter listing completed audit types — e.g. `audit: [coverage]`. If the field already exists, append `coverage` to the list (avoid duplicates). Appending this lens is what advances the topic's derived status: once the `audit` field holds all four core types (`consistency`, `coverage`, `quality`, `coherence`), the derivation reports `audited` on its own — there is no status to write anywhere.
5. **Present a summary** to the user:
   - Number of findings by type and severity
   - List of major findings requiring attention
   - Which topics' derived status advanced (to `audited`)
   - Any CONFIDENCE markers that could not be resolved

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(audit): <scope> coverage`

## Rules

- Do NOT modify content — only insert/remove comments and update status/dates.
- Do NOT resolve AUDIT findings — that is the refine phase's job.
- Severity guide: `major` = missing critical content, broken cross-references. `minor` = minor gaps, areas mentioned but not central.
- If an AUDIT comment already exists at a location, do not duplicate it. Update the existing one if new information changes the assessment.
- A topic's derived status only reaches `audited` when its frontmatter `audit` field contains all four core types: `consistency`, `coverage`, `quality`, `coherence`.
