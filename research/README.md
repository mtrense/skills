# Skill Family: Research

A family of skills for building structured knowledge bases with Claude Code, intended for both human review and AI-native consumption. Operates entirely on markdown files. Topics are organized hierarchically — each topic file represents one subject, headings within structure it into sections, and directories group related topics. Filenames are stable keys for cross-references, git history, and `INDEX.md` entries. The output is not academic-grade research; it is practical, citable knowledge tuned for downstream coding and writing.

## Skill Family

A phased workflow with four broad steps — bootstrap, inquiry, investigation, and audit-then-refine — plus structural and glossary maintenance utilities. All skills currently set `disable-model-invocation: true` and are user-invoked, so each phase is an explicit, reviewable step rather than an autonomous loop. (See `feedback_disable_model_invocation.md` if relaxing that for individual skills later.)

1. **`/research-inception`** — One-time bootstrap. Creates `research/CLAUDE.md` (research conventions, citation style, tone), `INDEX.md` (topic outline), `DECISIONS.md`, `glossary.md`, and one stub topic file per declared topic.
   **Invocation**: `/research-inception` — no arguments; operates on the entire project.

2. **`/research-add-topic <topic-name> [summary]`** — Adds a new top-level topic to an existing project (directory plus chapter stubs plus `INDEX.md` entry).

3. **`/research-add-chapter <topic-directory>`** — Adds new chapter stubs to an existing topic directory.

4. **`/research-inquiry <topic-file>`** — Coarse outline phase. Adds section headings to the topic file with `<!-- RESEARCH: ... -->` directives capturing the query, expected scale, source profile, and related sections. Advances section status to `inquiry`.
   **Invocation**: `/research-inquiry data-pipelines/batch-processing.md`.

5. **`/research-investigation <topic-file> [section-heading]`** — Fills one section based on its RESEARCH directive. Adds references to `<topic>_references.yaml`, attempts URL verification, and tags any claim that lacks strong sourcing with a `<!-- CONFIDENCE: low | medium -->` marker. When sources directly contradict, both positions are presented in-text, a `DECISIONS.md` entry records which was adopted and why, and an AUDIT directive is inserted for follow-up. Removes the RESEARCH directive once fulfilled and advances status to `draft`.
   **Invocation**: `/research-investigation data-pipelines/batch-processing.md "Error Handling"`. Omitting the section operates on the first section still in `inquiry` status.

6. **`/research-audit-consistency [topic-path]`**, **`/research-audit-coverage [topic-path]`**, **`/research-audit-quality [topic-path]`**, **`/research-audit-coherence [topic-path]`** — Four narrow audit skills (one per concern: cross-topic contradictions, gaps relative to the plan, depth and sourcing adequacy, narrative flow). Each prioritizes claims marked with `<!-- CONFIDENCE: low | medium -->`, verifies or upgrades them before auditing unmarked content, removes resolved CONFIDENCE markers, and inserts `<!-- AUDIT: ... -->` directives for follow-up. The optional path scopes to one file or a directory subtree; omitting it audits everything. Advances status to `audited`.

7. **`/research-refine <topic-file> <operation> [details]`** — Resolves AUDIT directives within a single topic. Built-in operations: `correct` (information is wrong), `expand`, `condense`, `restructure`, `cross-reference`, `update` (new information supersedes old, distinct from `correct`). Free-text instructions scoped to the topic also work. Status is unchanged unless all outstanding AUDIT comments are cleared, in which case it advances `audited` → `done`.

8. **`/research-restructure <operation> <topic-path> [target-path]`** — Structural changes that affect project layout: `split` (oversized topic), `merge` (two topics overlap), `promote` (single file → directory with child files), `demote` (directory → single file). Updates `INDEX.md` and rewrites every cross-reference that used the old path.

9. **`/research-glossary-sync`** — Reconciles `glossary.md` with current topic content. Adds new terms introduced during investigation or refinement, updates changed definitions, removes unused terms. Should be run after any content-changing phase.

## Project Layout

Everything lives under a `research/` folder so the same repository can host other workflows (engineering, codebase-survey) without collision:

```
/
├── CLAUDE.md
├── research/
│   ├── CLAUDE.md
│   ├── INDEX.md
│   ├── DECISIONS.md
│   ├── glossary.md
│   ├── content/
│   │   ├── authentication.md                 ← standalone topic
│   │   ├── authentication_references.yaml    ← references for authentication.md
│   │   ├── data-pipelines/                   ← hierarchical topic
│   │   │   ├── batch-processing.md
│   │   │   ├── batch-processing_references.yaml
│   │   │   ├── stream-processing.md
│   │   │   └── stream-processing_references.yaml
│   │   ├── api-design/
│   │   │   ├── rest-conventions.md
│   │   │   ├── rest-conventions_references.yaml
│   │   │   ├── versioning.md
│   │   │   └── versioning_references.yaml
│   │   └── ...
├── src/
│   ├── CLAUDE.md
│   └── ...
└── ...
```

Topics use descriptive filenames as stable keys — no numeric prefixes. A topic starts as a single file and is `promote`d into a directory when it outgrows one file. Directory overviews live in the `##` entry in `INDEX.md`; there is no separate index file per directory. The repo-root `CLAUDE.md` is project-wide and out of scope for these skills (the research-specific conventions live in `research/CLAUDE.md`).

Assets are co-located with their topic file: when `<name>.md` has assets they go in a sibling `<name>_assets/` directory and are referenced with relative paths (e.g. `![diagram](authentication_assets/flow.png)`). References are similarly co-located in `<name>_references.yaml`. There is no central `assets/` directory.

## File Formats

### Topic file frontmatter

```
---
title: "Topic Title"
created: 2026-02-17
updated: 2026-03-17
---
```

### RESEARCH directives (placed by inquiry, consumed by investigation)

```
<!-- RESEARCH:
  query: "How does X relate to Y in context Z?"
  scale: brief | standard | deep
  scale_detail: "> 3 examples"               # optional free-text override
  sources: academic | industry | primary | any
  sources_detail: "post-2023, peer-reviewed" # optional free-text override
  related: "data-pipelines/batch-processing.md#error-handling"
-->
```

- `scale`: `brief` (~1–2 paragraphs, overview), `standard` (~3–5 paragraphs with examples), `deep` (comprehensive, multiple perspectives).
- `sources`: `academic` (papers, journals), `industry` (blog posts, docs, conference talks), `primary` (specs, RFCs, source code), `any` (no restriction).

### CONFIDENCE markers (placed by investigation, resolved by audit)

```
<!-- CONFIDENCE: low | medium
  reason: "No primary source found; inferred from adjacent examples"
-->
```

- `low`: speculative, inferred, or single weak source — audit should prioritize.
- `medium`: plausible and partially supported but lacking strong direct evidence.
- High confidence is the default and needs no marker. Audit treats unmarked claims as well-sourced and focuses verification effort on `low`/`medium`.

### AUDIT directives (placed by audit skills, resolved by refine)

```
<!-- AUDIT:
  type: contradiction | gap | weak-source | flow
  severity: minor | major
  detail: "Section claims X, but api-design/versioning.md#deprecation-policy states the opposite"
  ref: "api-design/versioning.md#deprecation-policy"
-->
```

### References

References are split between two locations.

**`<topic>_references.yaml`** — full structured metadata, keyed by citation:

```yaml
vaswani-2017:
  title: "Attention Is All You Need"
  authors: Ashish Vaswani, Noam Shazeer, Niki Parmar, Jakob Uszkoreit, Llion Jones, Aidan N. Gomez, Lukasz Kaiser, Illia Polosukhin
  url: https://arxiv.org/abs/1706.03762
  published: 2017-06-12
  last-checked: 2026-04-04
  verified: true
```

Only `title` is required. Common fields: `title`, `authors`, `url` (URLs/blogs/docs), `isbn` (books), `published`, `last-checked`, `verified`. The `verified` field defaults to `false` when omitted. Citation keys should be descriptive and stable — typically `author-year` or `slug-year` (e.g., `vaswani-2017`, `react-docs-2024`, `rfc-7519`).

**Markdown** — short-form references and in-text citations. Each section ends with a `### References` subheading:

```markdown
### References

- [vaswani-2017] "Attention Is All You Need" ("Introduced the transformer, demonstrating that self-attention alone — without recurrence or convolution — achieves state-of-the-art translation quality with dramatically less training time.")
- [dean-2004] "MapReduce: Simplified Data Processing on Large Clusters" ("Established the programming model for distributed batch processing at scale.")
```

Format: `- [citation-key] "Title" ("Takeaway relevant to this section.")`. In-text citations use `[citation-key]` or `[citation-key, pp. 12-15]`:

```markdown
The transformer architecture [vaswani-2017] replaced recurrence with self-attention.
As shown in the original paper [vaswani-2017, pp. 5-6], multi-head attention allows...
```

### `INDEX.md`

Outline of the project plus a brief abstract per node. Headings use the path relative to `content/` so they mirror the directory tree:

```
# <Research Topic>
<abstract>

## data-pipelines/
<abstract>

### data-pipelines/batch-processing.md
**Status**: stub | inquiry | draft | audited | done

<abstract>

### data-pipelines/stream-processing.md
**Status**: draft

<abstract>

## authentication.md
**Status**: inquiry

<abstract>

## api-design/
<abstract>

### api-design/rest-conventions.md
**Status**: done

<abstract>
```

Directory entries (`##`) group their child topics but carry no status; only leaf topic files (`###`) do.

### `glossary.md`

Concise, ordered list of terms with brief definitions. Each entry may carry a citation when the cited definition is useful and aligned with the research.

### `DECISIONS.md`

Structured list of decisions taken (excluding a source, choosing between competing sources, …) and explicit turning points where conclusions change due to new material or experiments. The contradiction-handling policy is:

1. Both positions are presented in the section text.
2. A `DECISIONS.md` entry explains which was adopted and the reasoning.
3. An `<!-- AUDIT: type: contradiction ... -->` comment is inserted so the audit phase can verify the resolution.

## Source Verification

All URLs in `references.yaml` must be verified via web fetch before a section can advance to `audited`. Each reference carries a `verified` field. Newly added references default to `verified: false`. The investigation skill attempts to fetch each URL; on success, sets `verified: true`. Unverified references are treated as `CONFIDENCE: low` claims by the audit phase. A section cannot reach `done` while any of its references remains unverified.

## Status Lifecycle

`stub` → `inquiry` → `draft` → `audited` → `done`.

- `stub`: topic file created during inception, no content yet.
- `inquiry`: section headings and RESEARCH directives placed.
- `draft`: section content written.
- `audited`: section reviewed; may have AUDIT directive comments pending.
- `done`: all audit findings resolved, content finalized.

Each skill may only advance status forward (e.g., investigation moves `inquiry` → `draft`). `refine` does not change status unless it resolves the last outstanding AUDIT comment, in which case it advances `audited` → `done`.

## Process

1. **Bootstrap** — `/research-inception` (once).
2. **Add topics or chapters as needed** — `/research-add-topic`, `/research-add-chapter`.
3. **Inquiry burndown** — `/research-inquiry <topic>` per topic file to attach RESEARCH directives.
4. **Investigation burndown** — `/research-investigation <topic> [section]` per section.
5. **Audit** — `/research-audit-consistency`, `coverage`, `quality`, `coherence` (scoped or whole-project).
6. **Refine** — `/research-refine <topic> <operation>` to resolve AUDIT directives.
7. **Restructure** — `/research-restructure <op> <path>` when topics outgrow or overlap their layout.
8. **Glossary sync** — `/research-glossary-sync` after any content-changing phase.

## Error and Escape Handling

When a skill cannot complete its task it must signal the problem rather than silently fail or produce partial results.

- **Scope mismatch**: if investigation finds a section's RESEARCH query ill-defined, overlapping with another section, or requiring structural changes, the skill leaves a `<!-- AUDIT: type: gap, severity: major, detail: "..." -->` comment, writes best-effort content, and proceeds. It must not restructure the topic.
- **Missing prerequisites**: if a skill is invoked on a section whose status does not meet the precondition (e.g., investigation on a `stub` section with no RESEARCH directive), it aborts with a clear error stating what is missing and which phase should run first.
- **Contradictory directives**: if a section contains directives that conflict with each other or with `INDEX.md` (e.g., status says `done` but AUDIT comments are present), the skill flags the inconsistency to the user and does not proceed until resolved.
- **Source verification failure**: if a URL cannot be fetched or returns content that does not match the cited claim, the reference is marked `verified: false` and a `<!-- CONFIDENCE: low -->` marker is placed on the associated claim.
- **Unrecoverable errors**: on errors a skill cannot handle (file not found, permission denied), it reports clearly and makes no changes.

## Git Usage

Git records research progress and provides metadata (when each piece of research was conducted, etc.). Conventional commits identify the phase:

- `research(inception): initialize project structure`
- `research(inquiry): authentication section outline`
- `research(investigation): data-pipelines/batch-processing s2.3`
- `research(audit): api-design/ consistency`
- `research(refine): authentication s1 correct sourcing`
- `research(restructure): promote data-pipelines`
- `research(glossary): sync after data-pipelines investigation`
