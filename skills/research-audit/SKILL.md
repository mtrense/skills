---
name: research-audit
description: "Audit research topics for consistency, coverage, quality, and coherence. Produces AUDIT directive comments for the refine phase. Arguments: optional topic path, optional operation (consistency|coverage|quality|coherence)."
argument-hint: "[topic-path] [operation]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Bash(Grep *), Edit, WebSearch, WebFetch
---

# Research Audit

You are auditing research content for quality and correctness. You produce structured AUDIT comments that the refine phase will resolve.

**Arguments**: `$ARGUMENTS`
- First argument (optional): topic path relative to `research/content/` — a file or directory. Omit to audit all topics.
- Second argument (optional): operation — `consistency`, `coverage`, `quality`, `coherence`. Omit to run all checks.

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

Before running the selected audit operations, scan all in-scope files for `<!-- CONFIDENCE: low -->` and `<!-- CONFIDENCE: medium -->` markers. These are the highest priority items.

For each CONFIDENCE marker:
- Attempt to verify the claim using WebSearch and WebFetch.
- If verification succeeds: remove the CONFIDENCE marker (the claim is now well-sourced). Add or update the reference in both `references.yaml` and the markdown `### References` list.
- If verification fails or contradicts the claim: convert to an AUDIT comment and leave the CONFIDENCE marker.
- If verification partially supports: upgrade `low` to `medium` or leave as-is, updating the `reason`.

## Audit Operations

### `consistency` — Cross-topic Contradictions

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

### `coverage` — Gaps Relative to Research Plan

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

### `quality` — Depth and Sourcing Adequacy

For each section, assess:
- Does the depth match the RESEARCH directive's original `scale`? (Read git history or infer from content)
- Are claims properly sourced with references? Check both in-text `[citation-key]` citations and the `### References` list.
- Are references verified (`verified: true` in `references.yaml`)? Flag unverified references.
- Are examples concrete and relevant?
- Is the content accurate based on your knowledge?

For each finding:
```html
<!-- AUDIT:
  type: weak-source
  severity: minor | major
  detail: "Claim about X has no supporting reference"
  ref: ""
-->
```

### `coherence` — Narrative Flow

Assess within each topic file:
- Do sections follow a logical progression?
- Are transitions between sections smooth?
- Is the abstraction level consistent?
- Does the introduction set up what follows?
- Does the content deliver on what the section heading promises?

For each finding:
```html
<!-- AUDIT:
  type: flow
  severity: minor | major
  detail: "Section jumps from theoretical foundations to implementation without bridging"
  ref: ""
-->
```

## Output

1. **Insert AUDIT comments** directly into the topic files at the relevant locations (immediately after the problematic content).
2. **Remove resolved CONFIDENCE markers** (those that were verified).
3. **Update `research/INDEX.md`**: change status to `audit` for each fully audited topic file (all sections reviewed).
4. Update the `updated` date in frontmatter for each modified file.
5. **Present a summary** to the user:
   - Number of findings by type and severity
   - List of major findings requiring attention
   - Which topics had their status advanced
   - Any CONFIDENCE markers that could not be resolved

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(audit): <scope> <operation>`

## Rules

- Do NOT modify content — only insert/remove comments and update status/dates.
- Do NOT resolve AUDIT findings — that is the refine phase's job.
- Severity guide: `major` = factual errors, missing critical content, direct contradictions. `minor` = style issues, weak but not wrong sourcing, minor gaps.
- If an AUDIT comment already exists at a location, do not duplicate it. Update the existing one if new information changes the assessment.
- A topic can only reach `audit` status when ALL its sections have been reviewed in this invocation.
