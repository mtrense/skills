---
name: research-audit-quality
description: "Audit research topics for depth and sourcing adequacy. Produces AUDIT directive comments for the refine phase. Arguments: optional topic path."
argument-hint: "[topic-path]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Bash(grep *), Bash(bash */skills/research-status/research-status.sh *), Edit, Agent, WebFetch
---

# Research Audit — Quality

You are auditing research content for depth and sourcing adequacy. You produce structured AUDIT comments that the refine phase will resolve.

**Arguments**: `$ARGUMENTS`
- First argument (optional): topic path relative to `research/content/` — a file or directory. Omit to audit all topics.

## Prerequisites

1. Derive each topic's status to identify which topics are in scope. Run `bash <skills-root>/research-status/research-status.sh research` for the whole project (or `--path <target>` when a topic is targeted) and read the first whitespace-delimited field of each line. (`<skills-root>` is the `.claude/skills/` directory the research skills are installed in — `~/.claude/skills` for a global install, `<project>/.claude/skills` for a project install.)
   - Topics with derived status `stub` or `inquiry` are skipped (not yet ready for audit).
   - Topics with derived status `draft`, `audited`, or `done` are eligible.
   - If a specific file is targeted and its derived status is `stub` or `inquiry`, abort with an error.
2. Read `research/CLAUDE.md` for project conventions.
3. Read `research/DECISIONS.md` for prior decisions.
4. Read `research/glossary.md` for term definitions.

You do not need to read the in-scope topic files yourself — the per-topic `quality-auditor` subagents (Step Q1 below) read them. The exception is Step P1, which uses Grep for marker discovery.

## Priority: CONFIDENCE Markers

Before running the audit, resolve outstanding `<!-- CONFIDENCE: low -->` and `<!-- CONFIDENCE: medium -->` markers in the in-scope files. These are the highest priority items.

### Step P1 — collect markers

Scan the in-scope files (use Grep for `<!-- CONFIDENCE:`) and build a marker list. For each match capture:
- `file`, `line`, `level` (`low`/`medium`), and the marker's existing `reason:` text.
- The 1–3 sentences of `claim` text the marker qualifies (typically the lines immediately above the marker, within the same paragraph).
- Any `[citation-key]` slugs already cited in that claim, plus the matching entries from the relevant `<topic>_references.yaml` (URL, title, authors, published, `verified`).

If the list is empty, skip to the depth/sourcing audit.

### Step P2 — delegate verification

Spawn the `confidence-verifier` subagent via the `Agent` tool with the marker list as input. Pass it the `research/CLAUDE.md` path and the relevant `<topic>_references.yaml` paths so it can reuse existing citation keys.

For very large batches (>30 markers spread across many topics), split by topic file and spawn multiple `confidence-verifier` subagents in parallel — one per topic, each receiving only that file's markers.

### Step P3 — apply decisions

Apply the subagent's `recommended-action` per marker. Every marker resolves one of two ways — **verified** (removed) or **converted to an AUDIT** — and this pass must leave **zero** CONFIDENCE markers in the in-scope files. A CONFIDENCE marker is never left in place or downgraded; its only consumer is this audit phase, so anything not verified here must become an AUDIT directive for refine to pick up.
- `remove marker; set verified: true on <key>` — delete the marker; update `references.yaml` (`verified: true`, `last-checked: <today>`); ensure the key is in the section's `### References` list.
- `remove marker; add new citation <key> + section reference` — delete the marker; add the new entry to `references.yaml`; add the in-text `[citation-key]` and the `### References` line.
- `convert marker to AUDIT type: contradiction; ref: <URL>` — **delete the CONFIDENCE marker** and insert an AUDIT comment immediately after the claim. Severity is the audit skill's call (see this skill's severity guide).
- `convert marker to AUDIT type: weak-source` — **delete the CONFIDENCE marker** and insert an AUDIT comment.
- `skipped` — the verifier had no usable `claim`; convert to an AUDIT `type: weak-source` so the marker still leaves the file. Never leave it in place.

Spot-check with WebFetch only when a `recommended-action` carries unusually high weight (e.g., a contradiction that would force a DECISIONS.md entry).

## Audit Operation: Depth and Sourcing Adequacy

The depth/sourcing analysis itself is delegated to the per-topic `quality-auditor` subagent. You orchestrate, then translate its findings into AUDIT comments.

### Step Q1 — fan out per topic

Spawn one `quality-auditor` subagent per in-scope topic file via the `Agent` tool. Send the spawns **in a single message** so they run concurrently. For very large projects (>15 in-scope files), batch into groups of ~10 spawns per message to avoid overwhelming the agent harness.

Each spawn's prompt contains:
- The absolute path to the topic file.
- The path to `research/CLAUDE.md`.
- The path to the sibling `<topic-name>_references.yaml` (skip if it doesn't exist — note that fact in the prompt).
- The relevant snippet of `research/INDEX.md` for this topic (so the subagent doesn't re-read the whole index).

If a subagent returns `Findings: (skipped — no investigated content)`, skip to the next topic.

### Step Q2 — translate findings to AUDIT comments

For each finding in a subagent's report:

- Map the subagent's `type` (`weak-source`, `contradiction`) and `severity` directly to the AUDIT comment's fields. The auditor's severity calls follow the same severity guide as this skill, so trust them by default.
- Insert the AUDIT comment immediately after the line the finding references:
  ```html
  <!-- AUDIT:
    type: <weak-source | contradiction>
    severity: <minor | major>
    detail: "<from finding>"
    ref: ""
  -->
  ```
- If the finding's `suggested-action` adds useful context, prepend it to the `detail` text (e.g., "Suggest expand with example: …").
- If an AUDIT comment already exists at the same location with the same `type`, do not duplicate — update its `detail` only if the auditor surfaced new information.

`Section-Level Notes` from the subagent inform borderline calls but do not themselves produce AUDIT comments unless they're explicitly tied to a line.

## Output

1. **Insert AUDIT comments** directly into the topic files at the relevant locations (immediately after the problematic content).
2. **Clear every CONFIDENCE marker** — deleted when verified, converted to an AUDIT otherwise. None may remain after this pass.
3. Update the `updated` date in frontmatter for each modified file.
4. **Track audit progress in frontmatter**: add or update an `audit` field in each audited file's YAML frontmatter listing completed audit types — e.g. `audit: [quality]`. If the field already exists, append `quality` to the list (avoid duplicates). Appending this lens is what advances the topic's derived status: once the `audit` field holds all four core types (`consistency`, `coverage`, `quality`, `coherence`), the derivation reports `audited` on its own — there is no status to write anywhere.
5. **Present a summary** to the user:
   - Number of findings by type and severity
   - List of major findings requiring attention
   - Which topics' derived status advanced (to `audited`)
   - CONFIDENCE markers converted to AUDIT directives (count) — none should remain open

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(audit): <scope> quality`

## Rules

- Do NOT modify content — only insert/remove comments and update status/dates.
- Do NOT resolve AUDIT findings — that is the refine phase's job.
- Severity guide: `major` = factual errors, missing critical sourcing. `minor` = weak but not wrong sourcing, missing examples.
- If an AUDIT comment already exists at a location, do not duplicate it. Update the existing one if new information changes the assessment.
- A topic's derived status only reaches `audited` when its frontmatter `audit` field contains all four core types: `consistency`, `coverage`, `quality`, `coherence`.
