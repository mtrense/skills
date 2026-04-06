---
name: research-investigation
description: "Research and write content for a single section of a topic file based on its RESEARCH directive. Actively searches the web for sources. Arguments: topic file path, optional section heading (defaults to first inquiry-status section)."
argument-hint: "<topic-file> [\"section-heading\"]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Edit, WebSearch, WebFetch
---

# Research Investigation

You are researching and writing content for a single section of a topic file, guided by its RESEARCH directive.

**Arguments**: `$ARGUMENTS`
- First argument: topic file path relative to `research/content/`
- Second argument (optional, quoted): section heading to investigate. If omitted, operate on the first section that still has a RESEARCH directive.

## Prerequisites

1. Read `research/INDEX.md` and confirm the topic has status `inquiry` or `draft` (partially investigated).
   - If status is `stub`, abort: "Run `/research-inquiry` first to create the section outline."
   - If status is `audit` or `done`, abort: "This topic has already passed investigation. Use `/research-refine` to make changes."
2. Read `research/CLAUDE.md` for conventions, tone, citation style.
3. Read the target topic file at `research/content/<topic-file>`.
4. Locate the target RESEARCH directive. If a section heading was specified, find the RESEARCH directive under that heading. Otherwise, find the first `<!-- RESEARCH: ... -->` directive in the file.
   - The **scope** of this invocation is the single heading that directly contains the RESEARCH directive — do NOT expand scope to parent or sibling sections, even if they share a heading hierarchy.
   - If no RESEARCH directive is found, abort: "No sections pending investigation in this file."
5. Read related topics/sections referenced in the directive's `related` field.
6. Read `research/DECISIONS.md` for any prior decisions affecting this topic.

## Research Process

### Step 1: Web Research

Actively search the web based on the RESEARCH directive's `query`, `sources`, and `scale` fields.

- Use WebSearch to find relevant sources.
- Use WebFetch to read and verify promising results.
- Target the source types specified in the `sources` field.
- Respect `sources_detail` constraints (e.g., "post-2023", "peer-reviewed").
- Gather enough material to meet the `scale` requirement.

### Step 2: Write Content

Write the section content following these guidelines:

- **Scale**: Match the `scale` field — `brief` (~1-2 paragraphs), `standard` (~3-5 paragraphs with examples), `deep` (comprehensive, multiple perspectives).
- **Tone and style**: Follow `research/CLAUDE.md` conventions.
- **Structure**: Write content under the heading that contained the RESEARCH directive. Add subheadings one level deeper if needed for deep-scale content. Do NOT write content under sibling or child headings that have their own RESEARCH directives.
- **Cross-references**: Link to related topics using `[display text](relative-path.md#heading-slug)` relative to `content/`.

### Step 3: Confidence Assessment

For each claim in your content:

- **Well-sourced claims** (strong direct evidence): No marker needed.
- **Partially supported claims** (plausible but incomplete evidence):
  ```
  <!-- CONFIDENCE: medium
    reason: "Description of why evidence is incomplete"
  -->
  ```
- **Speculative or weakly sourced claims** (inferred, single weak source):
  ```
  <!-- CONFIDENCE: low
    reason: "Description of why this is uncertain"
  -->
  ```

Place confidence markers immediately after the claim they apply to.

### Step 4: Source Contradictions

When sources directly contradict each other:

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

### Step 5: References

References are stored in two places: full metadata in a YAML file, and short-form entries in the markdown.

**5a: Update `references.yaml`**

Add entries to `<topic-name>_references.yaml` (sibling of the topic markdown file). Create the file if it doesn't exist.

```yaml
citation-key:
  title: "Name of the resource"
  authors: Author Name, Another Author
  url: https://actual-url
  published: 2024-01-15
  last-checked: <today>
  verified: true | false
```

Fields are optional beyond `title`. Use `url` for web resources, `isbn` for books. Citation keys should be descriptive and stable (e.g., `author-year`, `slug-year`).

**5b: Add in-text citations**

Cite sources inline using `[citation-key]` or `[citation-key, pp. N-M]` for page ranges.

**5c: Add section references list**

Add a `### References` subheading at the end of the section (before the next `##` section):

```markdown
### References

- [citation-key] "Title" ("One-sentence takeaway relevant to this section.")
```

**Verification**: For each URL, attempt to fetch it with WebFetch.
- If the fetch succeeds and content matches the cited claim: set `verified: true` in `references.yaml`
- If the fetch fails or content doesn't match: set `verified: false` in `references.yaml`, and add a `<!-- CONFIDENCE: low -->` marker on the associated claim.

### Step 6: Clean Up

- **Remove** the `<!-- RESEARCH: ... -->` directive from the investigated section.
- **Preserve** RESEARCH directives in all other sections.

### Step 7: Status Update

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
- Do NOT fabricate sources. Every URL in references must be real and fetched.
- If the RESEARCH directive's query is ill-defined or overlaps with another section, leave an AUDIT comment with `type: gap, severity: major` and write best-effort content.
- Do NOT advance status beyond `draft`.
