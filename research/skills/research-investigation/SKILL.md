---
name: research-investigation
description: "Research and write content for a single section of a topic file based on its RESEARCH directive. Delegates web search and source verification to the source-investigator subagent (optionally several in parallel), then synthesizes the section from its structured report. Arguments: topic file path, optional section heading (defaults to first inquiry-status section)."
argument-hint: "<topic-file> [\"section-heading\"]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Edit, Agent, WebFetch
---

# Research Investigation

You are researching and writing content for a single section of a topic file, guided by its RESEARCH directive.

You orchestrate one or more `source-investigator` subagents to do the actual web search-fetch-verify loop, then synthesize the section's prose from their structured reports. You never see raw page payloads in your own context — only the distilled report(s).

**Arguments**: `$ARGUMENTS`
- First argument: topic file path relative to `research/content/`
- Second argument (optional, quoted): section heading to investigate. If omitted, operate on the first section that still has a RESEARCH directive.

## Prerequisites

1. Read `research/INDEX.md` and confirm the topic has status `inquiry` or `draft` (partially investigated).
   - If status is `stub`, abort: "Run `/research-inquiry` first to create the section outline."
   - If status is `audited` or `done`, abort: "This topic has already passed investigation. Use `/research-refine` to make changes."
2. Read `research/CLAUDE.md` for conventions, tone, citation style.
3. Read the target topic file at `research/content/<topic-file>`.
4. Locate the target RESEARCH directive. If a section heading was specified, find the RESEARCH directive under that heading. Otherwise, find the first `<!-- RESEARCH: ... -->` directive in the file.
   - The **scope** of this invocation is the single heading that directly contains the RESEARCH directive — do NOT expand scope to parent or sibling sections, even if they share a heading hierarchy.
   - If no RESEARCH directive is found, abort: "No sections pending investigation in this file."
5. Read related topics/sections referenced in the directive's `related` field.
6. Read `research/DECISIONS.md` for any prior decisions affecting this topic.
7. If a sibling `<topic-name>_references.yaml` exists, read it so existing citation keys can be reused by the subagent(s).

## Research Process

### Step 1: Spawn source-investigator subagent(s)

Use the `Agent` tool with `subagent_type: source-investigator`. Hand each spawn a self-contained prompt containing:

- The full RESEARCH directive verbatim (`query`, `scale`, `scale_detail`, `sources`, `sources_detail`, `related`).
- The path to `research/CLAUDE.md` and the parent topic file path (so the subagent can read conventions and ground cross-references).
- The path to `<topic-name>_references.yaml` if it exists, so the subagent can reuse existing citation keys.

**Parallelism rule**:

- If `sources: any`, spawn **two or three** subagents in a single message — one biased toward `academic`, one toward `industry`, optionally one toward `primary`. Pass the bias in the prompt explicitly (e.g., "Prioritise academic sources for this run").
- If `sources` is a single class, spawn **one** subagent.
- If the directive's `scale` is `brief`, always spawn one — extra parallelism is wasted on small scopes.

If a subagent returns an under-scaled report (its `Coverage vs. Scale` section says it couldn't reach the target), you may spawn one follow-up subagent with a refined prompt — never more than once.

### Step 2: Merge subagent reports

You receive one or more structured reports. Merge them:

- **Citation keys**: deduplicate by URL. If two subagents proposed different keys for the same URL, prefer the one already present in `<topic-name>_references.yaml`; otherwise prefer the more descriptive of the two.
- **Quotes**: keep all distinct quotes. Quotes from different sources that support the same claim become evidence for a `well-sourced` claim.
- **Contradictions**: union both lists; do not silently drop any.
- **Confidence**: a claim's overall confidence is the highest level supported across all reports (e.g., if one subagent rates it `medium` and another `well-sourced`, treat it as `well-sourced`).

If two reports disagree on a citation's `verified` status, prefer `false` — re-check with WebFetch yourself only if the citation will carry significant weight in the prose.

### Step 3: Write Content

Write the section content following these guidelines:

- **Scale**: Match the `scale` field — `brief` (~1-2 paragraphs), `standard` (~3-5 paragraphs with examples), `deep` (comprehensive, multiple perspectives). If the merged report's `Coverage vs. Scale` notes that target scale was unachievable, lean toward the next-smaller scale and note the limitation in an Open Question or DECISIONS entry.
- **Tone and style**: Follow `research/CLAUDE.md` conventions.
- **Structure**: Write content under the heading that contained the RESEARCH directive. Add subheadings one level deeper if needed for deep-scale content. Do NOT write content under sibling or child headings that have their own RESEARCH directives.
- **Cross-references**: Link to related topics using `[display text](relative-path.md#heading-slug)` relative to `content/`.
- **Cite from the report only**: every in-text `[citation-key]` must correspond to an entry in the merged report's `Sources` section. Do not invent claims that no quote in the report supports.

### Step 4: Confidence Assessment

Use the per-claim confidence levels from the merged report:

- **Well-sourced claims**: No marker needed.
- **Medium-confidence claims**:
  ```
  <!-- CONFIDENCE: medium
    reason: "Description of why evidence is incomplete"
  -->
  ```
- **Low-confidence claims**:
  ```
  <!-- CONFIDENCE: low
    reason: "Description of why this is uncertain"
  -->
  ```

Place confidence markers immediately after the claim they apply to. Use the report's `note:` fields for unverified citations as the basis for the `reason` text.

### Step 5: Source Contradictions

For each entry in the merged report's `Contradictions` section:

1. Present both positions in the section text.
2. Add a `DECISIONS.md` entry:
   ```
   ### DEC-NNN: <title>
   **Date**: <today>
   **Topic**: <topic-file-path>
   **Context**: <what the contradiction is>
   **Decision**: <which position was adopted>
   **Rationale**: <why>
   **Alternatives considered**: <the other position and why it was not chosen>
   ```
   Also add a row to the summary table in DECISIONS.md.
3. Insert an audit comment:
   ```
   <!-- AUDIT:
     type: contradiction
     severity: major
     detail: "Sources disagree on X — see DEC-NNN"
     ref: "DECISIONS.md#dec-nnn"
   -->
   ```

### Step 6: References

References are stored in two places: full metadata in a YAML file, and short-form entries in the markdown.

**6a: Update `references.yaml`**

For each citation actually used in the prose, write/update an entry in `<topic-name>_references.yaml`. Take the metadata directly from the merged report's `Sources` section:

```yaml
citation-key:
  title: "Name of the resource"
  authors: Author Name, Another Author
  url: https://actual-url
  published: 2024-01-15
  last-checked: <today>
  verified: true | false
```

Fields are optional beyond `title`. Use `url` for web resources, `isbn` for books. Reuse stable keys from the report (which themselves reuse keys already in this file when available).

**6b: Add in-text citations**

Cite sources inline using `[citation-key]` or `[citation-key, pp. N-M]` for page ranges.

**6c: Add section references list**

Add a `### References` subheading at the end of the section (before the next `##` section):

```markdown
### References

- [citation-key] "Title" ("One-sentence takeaway relevant to this section.")
```

**Verification**: trust the subagent's `verified` status by default. Spot-check with WebFetch only when:

- The citation carries a load-bearing claim (e.g., the only source for a contradiction's resolution), or
- The merged report flagged conflicting `verified` values across subagents.

If a spot-check fails, set `verified: false` in `references.yaml` and add a `<!-- CONFIDENCE: low -->` marker on the associated claim.

### Step 7: Clean Up

- **Remove** the `<!-- RESEARCH: ... -->` directive from the investigated section.
- **Preserve** RESEARCH directives in all other sections.

### Step 8: Status Update

After writing the section, check if ALL sections in the file have been investigated (no remaining `<!-- RESEARCH: ... -->` directives).

- If **all sections done**: Update `research/INDEX.md` status from `inquiry` → `draft`.
- If **sections remain**: Leave status as `inquiry` (or keep as `draft` if it was already `draft`).

Update the `updated` date in frontmatter to today.

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(investigation): <topic-name> <section-reference>`

## Rules

- Only write content for ONE RESEARCH directive per invocation. The scope is the single heading that contains that directive — not a parent section, not sibling subsections.
- Do NOT modify other sections' content (only remove the directive from the investigated heading).
- Do NOT restructure the topic or change headings — if the section scope is wrong, leave an AUDIT comment.
- Do NOT fabricate sources. Every citation must come from a subagent's `Sources` section. URL spot-checks are by WebFetch only.
- If the RESEARCH directive's query is ill-defined or overlaps with another section, leave an AUDIT comment with `type: gap, severity: major` and write best-effort content from whatever the subagent could surface.
- Do NOT advance status beyond `draft`.
- **Do not** call WebSearch yourself. The subagent owns search; you own synthesis.
- **Tolerate subagent under-scaling.** A `Coverage vs. Scale` shortfall is a footnote in the prose (and possibly an Open Question), not a fatal error. The section is still useful at a smaller scale.
