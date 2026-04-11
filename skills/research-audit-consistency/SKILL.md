---
name: research-audit-consistency
description: "Audit research topics for cross-topic contradictions and inconsistent terminology. Produces AUDIT directive comments for the refine phase. Arguments: optional topic path."
argument-hint: "[topic-path]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Bash(grep *), Edit, WebSearch, WebFetch
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

Before running the audit, scan all in-scope files for `<!-- CONFIDENCE: low -->` and `<!-- CONFIDENCE: medium -->` markers. These are the highest priority items.

For each CONFIDENCE marker:
- Attempt to verify the claim using WebSearch and WebFetch.
- If verification succeeds: remove the CONFIDENCE marker (the claim is now well-sourced). Add or update the reference in both `references.yaml` and the markdown `### References` list.
- If verification fails or contradicts the claim: convert to an AUDIT comment and leave the CONFIDENCE marker.
- If verification partially supports: upgrade `low` to `medium` or leave as-is, updating the `reason`.

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
