---
name: research-audit-graphics
description: "Audit research topics for opportunities to add graphical representations (diagrams, graphs, schematics, tables, screenshots). Produces AUDIT directive comments for the refine phase. Arguments: optional topic path."
argument-hint: "[topic-path]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Bash(grep *), Edit, WebSearch, WebFetch
---

# Research Audit — Graphics

You are auditing research content for places that would benefit from graphical representations. You produce structured AUDIT comments that the refine phase will resolve.

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

## Audit Operation: Graphics Opportunities

For each section, identify content that would be significantly clearer or more useful with a visual representation. Look for:

- **Diagrams**: processes, workflows, architectures, system interactions, state machines, decision trees — anything with components and relationships
- **Graphs/Charts**: quantitative comparisons, trends, distributions, performance characteristics, trade-off curves
- **Tables**: feature comparisons, option matrices, property summaries that are currently buried in prose
- **Schematics**: protocol flows, data formats, memory layouts, network topologies
- **Screenshots**: UI references, tool configurations, visual output that the text tries to describe

For each finding, assess whether the visual would **materially improve comprehension** — not every list needs a diagram. Prioritize cases where:
- The text describes spatial or relational structure that prose struggles to convey
- A comparison across 3+ items is written as sequential paragraphs
- A process with branching or parallelism is described linearly
- Quantitative relationships are described qualitatively ("much faster", "significantly larger")

For each finding:
```html
<!-- AUDIT:
  type: graphics
  severity: minor | major
  detail: "This section describes a 5-step authentication flow with branching — a sequence diagram would clarify the handshake"
  graphic-type: diagram | graph | table | schematic | screenshot
  ref: ""
-->
```

## Output

1. **Insert AUDIT comments** directly into the topic files at the relevant locations (immediately after the content that would benefit from a visual).
2. Update the `updated` date in frontmatter for each modified file.
3. **Track audit progress in frontmatter**: add or update an `audit` field in each audited file's YAML frontmatter listing completed audit types — e.g. `audit: [graphics]`. If the field already exists, append `graphics` to the list (avoid duplicates).
4. **Present a summary** to the user:
   - Number of findings by graphic type and severity
   - List of major findings (high-impact visuals that would substantially improve the content)
   - Which files were modified

Note: the `graphics` audit is supplementary — it does not affect whether a topic reaches `audited` status in INDEX.md. Do NOT change topic status based on this audit alone.

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(audit): <scope> graphics`

## Rules

- Do NOT modify content — only insert comments and update dates/frontmatter.
- Do NOT create the graphics — that is the refine phase's job.
- Severity guide: `major` = content is genuinely hard to follow without a visual (complex process, multi-dimensional comparison). `minor` = a visual would be nice but the prose is adequate.
- If an AUDIT comment already exists at a location, do not duplicate it. Update the existing one if new information changes the assessment.
- Be selective. A handful of high-value graphics suggestions per topic is better than flagging every paragraph. Aim for visuals that earn their space.
