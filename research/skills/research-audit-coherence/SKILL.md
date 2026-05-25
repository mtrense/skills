---
name: research-audit-coherence
description: "Audit research topics for narrative flow and coherence. Produces AUDIT directive comments for the refine phase. Arguments: optional topic path."
argument-hint: "[topic-path]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Bash(grep *), Edit, Agent, WebFetch
---

# Research Audit — Coherence

You are auditing research content for narrative flow and coherence. You produce structured AUDIT comments that the refine phase will resolve.

**Arguments**: `$ARGUMENTS`
- First argument (optional): topic path relative to `research/content/` — a file or directory. Omit to audit all topics.

## Prerequisites

1. Read `research/INDEX.md` to identify which topics are in scope.
   - Topics with status `stub` or `inquiry` are skipped (not yet ready for audit).
   - Topics with status `draft`, `audited`, or `done` are eligible.
   - If a specific file is targeted and its status is `stub` or `inquiry`, abort with an error.
2. Read `research/CLAUDE.md` for project conventions.
3. Read `research/DECISIONS.md` for prior decisions.
4. Read `research/glossary.md` for term definitions.

You do not need to read the in-scope topic files yourself — the per-topic `coherence-auditor` subagents (Step C1 below) read them. The exception is Step P1, which uses Grep for marker discovery.

## Priority: CONFIDENCE Markers

Before running the audit, resolve outstanding `<!-- CONFIDENCE: low -->` and `<!-- CONFIDENCE: medium -->` markers in the in-scope files. These are the highest priority items.

### Step P1 — collect markers

Scan the in-scope files (use Grep for `<!-- CONFIDENCE:`) and build a marker list. For each match capture:
- `file`, `line`, `level` (`low`/`medium`), and the marker's existing `reason:` text.
- The 1–3 sentences of `claim` text the marker qualifies (typically the lines immediately above the marker, within the same paragraph).
- Any `[citation-key]` slugs already cited in that claim, plus the matching entries from the relevant `<topic>_references.yaml` (URL, title, authors, published, `verified`).

If the list is empty, skip to the narrative-flow audit.

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

## Audit Operation: Narrative Flow

The narrative-flow analysis itself is delegated to the per-topic `coherence-auditor` subagent. You orchestrate, then translate its findings into AUDIT comments.

### Step C1 — fan out per topic

Spawn one `coherence-auditor` subagent per in-scope topic file via the `Agent` tool. Send the spawns **in a single message** so they run concurrently. For very large projects (>15 in-scope files), batch into groups of ~10 spawns per message to avoid overwhelming the agent harness.

Each spawn's prompt contains:
- The absolute path to the topic file.
- The path to `research/CLAUDE.md`.
- The relevant snippet of `research/INDEX.md` for this topic (so the subagent doesn't re-read the whole index).

If a subagent returns `Findings: (skipped — no investigated content)`, skip to the next topic.

### Step C2 — translate findings to AUDIT comments

For each finding in a subagent's report:

- The subagent always reports `type: flow`. Map its `severity` directly to the AUDIT comment.
- Insert the AUDIT comment immediately after the line the finding references:
  ```html
  <!-- AUDIT:
    type: flow
    severity: <minor | major>
    detail: "<aspect>: <from finding>"
    ref: ""
  -->
  ```
  Prefix the `detail` with the subagent's `aspect` (`progression`, `transition`, `abstraction`, `intro`, `heading-mismatch`) so the refine phase knows what kind of fix is needed.
- If the finding's `suggested-action` adds useful context, append it to the `detail` text.
- If an AUDIT comment already exists at the same location with the same `type` and `aspect`, do not duplicate — update its `detail` only if the auditor surfaced new information.

The subagent's `Outline Summary` is for your judgement only — use it to decide whether a cluster of `progression` findings warrants raising a borderline `minor` to `major`. It does not produce an AUDIT comment of its own.

### Step C3 — structural-depth smell check

After the per-topic findings are applied, look at the in-scope file paths themselves. For each chapter nested 4 or more levels deep under `content/` (i.e. 4+ `/` separators in the relative path), insert an AUDIT comment at the top of the chapter's body (immediately after the H1):

```html
<!-- AUDIT:
  type: flow
  severity: minor
  detail: "structure: chapter nests 4+ levels deep — consider /research-restructure flatten or merge to reduce depth"
  ref: ""
-->
```

Skip this check when the user explicitly scoped the audit to a single chapter; it is a project-shape concern, not a per-chapter one.

## Output

1. **Insert AUDIT comments** directly into the topic files at the relevant locations (immediately after the problematic content).
2. **Remove resolved CONFIDENCE markers** (those that were verified).
3. **Update `research/INDEX.md`**: change status to `audited` only if the file's `audit` frontmatter field now contains all four types (`consistency`, `coverage`, `quality`, `coherence`). Otherwise leave the status unchanged.
4. Update the `updated` date in frontmatter for each modified file.
5. **Track audit progress in frontmatter**: add or update an `audit` field in each audited file's YAML frontmatter listing completed audit types — e.g. `audit: [coherence]`. If the field already exists, append `coherence` to the list (avoid duplicates).
6. **Present a summary** to the user:
   - Number of findings by type and severity
   - List of major findings requiring attention
   - Which topics had their status advanced
   - Any CONFIDENCE markers that could not be resolved

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(audit): <scope> coherence`

## Rules

- Do NOT modify content — only insert/remove comments and update status/dates.
- Do NOT resolve AUDIT findings — that is the refine phase's job.
- Severity guide: `major` = missing logical progression, content doesn't match heading. `minor` = rough transitions, minor abstraction-level shifts.
- If an AUDIT comment already exists at a location, do not duplicate it. Update the existing one if new information changes the assessment.
- A topic can only reach `audited` status in INDEX.md when its frontmatter `audit` field contains all four types: `consistency`, `coverage`, `quality`, `coherence`.
