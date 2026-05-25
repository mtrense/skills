---
name: research-inquiry
description: "Create a detailed section outline with RESEARCH directives for a topic file. Use after inception to structure a stub topic before investigation. Argument: topic file path relative to research/content/."
argument-hint: "<topic-file>"
model: opus
allowed-tools: Read, Glob, Edit, WebSearch, WebFetch
---

# Research Inquiry

You are creating a detailed outline for a topic file, adding section headings and RESEARCH directives that will guide the investigation phase.

**Target file**: `research/content/$ARGUMENTS`

## Prerequisites

1. Read `research/INDEX.md` and confirm the topic exists with status `stub`.
   - If status is not `stub`, abort with an error explaining which phase should have run and what the current status means.
   - If the topic is not listed in INDEX.md, abort with an error.
2. Read `research/CLAUDE.md` for project conventions, tone, and scope guidance.
3. Read the target topic file to confirm it exists and is a stub.
4. Read `research/INDEX.md` fully to understand related topics and avoid overlap.

## Outline Generation

For the topic, design a logical section structure using markdown headings (`##` for major sections, `###` for subsections). Consider:

- What are the essential aspects of this topic?
- What would a practitioner need to know?
- How does this relate to other topics in the research project? (Check INDEX.md)
- What's the right progression — conceptual foundations first, then practical details?

For **each section**, place a RESEARCH directive comment immediately after the heading:

```markdown
## <Section Title>

<!-- RESEARCH:
  query: "How does X relate to Y in context Z?"
  scale: brief | standard | deep
  scale_detail: "optional free-text, e.g. '> 3 examples'"
  sources: academic | industry | primary | any
  sources_detail: "optional free-text, e.g. 'post-2023, peer-reviewed'"
  related: "other-topic.md#relevant-section"
-->
```

### Choosing `scale`

- `brief`: Overview sections, definitions, context-setting (~1-2 paragraphs)
- `standard`: Core sections that need examples and explanation (~3-5 paragraphs)
- `deep`: Critical sections, controversial areas, or sections needing multiple perspectives (comprehensive treatment)

### Choosing `sources`

- `academic`: Theoretical foundations, algorithms, formal models
- `industry`: Best practices, tooling, real-world patterns
- `primary`: Official specs, RFCs, documentation, source code
- `any`: General context, widely-known information

### Cross-references

Use the `related` field to link to other topics or sections that the investigator should consider. Format: `topic-path.md#section-slug` (relative to `content/`).

## Output

1. **Update the topic file** with the full outline (preserve existing frontmatter).
2. **Update `research/INDEX.md`**: change the topic's status from `stub` to `inquiry`.
3. Present the outline to the user for review.

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(inquiry): <topic-name> section outline`

## Rules

- Do NOT write any content — only headings and RESEARCH directives.
- Do NOT change the topic's title in frontmatter.
- Do NOT modify other topic files.
- Every `##` and `###` section must have exactly one RESEARCH directive.
- The outline should have between 3-8 major sections (`##`), each with 0-4 subsections (`###`).
- Update the `updated` date in frontmatter to today.
