---
name: research-audit-coverage
description: "Audit research topics for gaps relative to the research plan. Produces AUDIT directive comments for the refine phase. Arguments: optional topic path."
argument-hint: "[topic-path]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Bash(grep *), Edit, WebSearch, WebFetch
---

# Research Audit — Coverage

You are auditing research content for gaps relative to the research plan. You produce structured AUDIT comments that the refine phase will resolve.

**Arguments**: `$ARGUMENTS`
- First argument (optional): topic path relative to `research/content/` — a file or directory. Omit to audit all topics.

## Prerequisites

1. Read `research/INDEX.md` to identify which topics are in scope.
   - Topics with status `stub` or `inquiry` are skipped (not yet ready for audit).
   - Topics with status `draft`, `audit`, or `done` are eligible.
   - If a specific file is targeted and its status is `stub` or `inquiry`, abort with an error.
2. Read `research/CLAUDE.md` for project conventions.
3. Read all in-scope topic files.
4. Read `research/DECISIONS.md` for prior decisions.
5. Read `research/glossary.md` for term definitions.

## Priority: CONFIDENCE Markers

Before running the audit, scan all in-scope files for `<!-- CONFIDENCE: low -->` and `<!-- CONFIDENCE: medium -->` markers. These are the highest priority items.

For each CONFIDENCE marker:
- Attempt to verify the claim using WebSearch and WebFetch.
- If verification succeeds: remove the CONFIDENCE marker (the claim is now well-sourced). Add or update the reference in both `references.yaml` and the markdown `### References` list.
- If verification fails or contradicts the claim: convert to an AUDIT comment and leave the CONFIDENCE marker.
- If verification partially supports: upgrade `low` to `medium` or leave as-is, updating the `reason`.

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
3. **Update `research/INDEX.md`**: change status to `audit` for each fully audited topic file (all sections reviewed).
4. Update the `updated` date in frontmatter for each modified file.
5. **Track audit progress in frontmatter**: add or update an `audit` field in each audited file's YAML frontmatter listing completed audit types — e.g. `audit: [coverage]`. If the field already exists, append `coverage` to the list (avoid duplicates).
6. **Present a summary** to the user:
   - Number of findings by type and severity
   - List of major findings requiring attention
   - Which topics had their status advanced
   - Any CONFIDENCE markers that could not be resolved

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(audit): <scope> coverage`

## Rules

- Do NOT modify content — only insert/remove comments and update status/dates.
- Do NOT resolve AUDIT findings — that is the refine phase's job.
- Severity guide: `major` = missing critical content, broken cross-references. `minor` = minor gaps, areas mentioned but not central.
- If an AUDIT comment already exists at a location, do not duplicate it. Update the existing one if new information changes the assessment.
- A topic can only reach `audit` status when ALL its sections have been reviewed in this invocation.
