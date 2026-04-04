# Overview

I'd like to create Claude Skills for researching with Claude Code. It should completely work on markdown files, and operate in phases. Each markdown file represents one topic, the headings in the markdown files structure each topic into sections and subsections. Topics can be organized hierarchically using nested directories. Filenames serve as stable keys for cross-references, git commits, and INDEX.md entries. The target audience is humans *and* AI, as I would like to use the resulting knowledge base both for human review and learning as well as for AI-native coding and writing. The research is not intended to fully qualify for scientific research, but rather to build a knowledge base for practical applications.

# Repository Layout
Everything is placed in a `/research/` folder to later be able to use the same repository with AI-native Engineering for a SDLC workflow or even other frameworks/workflows/skills.

```
/
├── CLAUDE.md
├── research/
│   ├── CLAUDE.md
│   ├── INDEX.md
│   ├── DECISIONS.md
│   ├── glossary.md
│   ├── content/
│   │   ├── authentication.md          ← standalone topic
│   │   ├── authentication_references.yaml ← references for authentication.md
│   │   ├── data-pipelines/            ← hierarchical topic
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

Topics use descriptive filenames as stable keys — no numeric prefixes. A topic starts as a single file and can be promoted into a directory when it outgrows one file. Directory overviews live in the `##` entry in `INDEX.md` — no separate index file per directory.

The root `CLAUDE.md` file is relevant for the entire project (which is out of scope for these skills, as they only touch on researching and the context might be vastly different from project to project).

Further customizations to these skills (directory organization, )

# Source Verification
All URLs in references must be verified via web fetch before a section can advance to `audit` status. Each reference in `references.yaml` carries a `verified` field (`true` or `false`). During investigation, newly added references default to `verified: false`. The investigation skill should attempt to fetch and verify each URL; if verification succeeds, set `verified: true`. Unverified references (`verified: false`) are treated as `CONFIDENCE: low` findings by the audit phase. A section cannot reach `done` status while any reference remains unverified.

# Git Usage
Git is used to commit research results and later provide meta-data (like at which date/time some research was conducted, ...). Conventional commits provide context to each commit, using the following format per phase:

- `research(inception): initialize project structure`
- `research(inquiry): authentication section outline`
- `research(investigation): data-pipelines/batch-processing s2.3`
- `research(audit): api-design/ consistency`
- `research(refine): authentication s1 correct sourcing`
- `research(restructure): promote data-pipelines`
- `research(glossary): sync after data-pipelines investigation`

# Phases

## Inception
First phase is research inception, generating a `CLAUDE.md` file (how to research, tone, citation style, conventions) and `INDEX.md` (defining topics of research, scope and directory/file layout). It also creates the necessary topic files with a frontmatter block. (Skill: `research-inception` )

**Invocation**: `/research-inception` — no arguments; operates on the entire project.

## Inquiry
Second phase is a coarse research (inquiry) for a single file, providing an outline in markdown headings for further research with HTML comment detailing the research query for each section `<!-- RESEARCH: ... -->`). Each directive comment includes the query and expected depth/scale (like `N paragraphs`, `> 3 examples`, ...) and links to potentially related topics or sections. (Skill: `research-inquiry` )

**Invocation**: `/research-inquiry <topic-file>` — e.g., `/research-inquiry data-pipelines/batch-processing.md`.

## Investigation
The third phase is research, where an individual section is researched based on its directive comment and filled with content and references. This skill operates on a single section at a time. When a claim cannot be strongly sourced or is inferred rather than directly supported, the skill must place a `<!-- CONFIDENCE: low | medium -->` comment immediately after the claim to flag it for the audit phase. Well-sourced claims need no marker (high confidence is the default). When sources directly contradict each other, the skill must log both positions in the section, add a `DECISIONS.md` entry explaining which was chosen and why, and insert an audit comment rather than silently picking one. Removes the directive comment and updates the section status in `INDEX.md` once fulfilled. (Skill: `research-investigation` )

**Invocation**: `/research-investigation <topic-file> [section-heading]` — e.g., `/research-investigation data-pipelines/batch-processing.md "Error Handling"`. If section-heading is omitted, operates on the first section with `inquiry` status in the topic.

## Audit
A fourth phase allows to audit and cross-check files against each other, looking for contradictions, gaps and unclear connections. It allows checking for `consistency` (cross-topic contradictions), `coverage` (gaps relative to the research plan), `quality` (depth and sourcing adequacy), and `coherence` (assess the narrative flow). The audit phase prioritizes claims marked with `<!-- CONFIDENCE: low | medium -->`, verifying or upgrading them before auditing unmarked content. The call scopes the audit call to either one file, a directory subtree, a specific operation, or a combination. Audit produces structured comments to be consumed by the `refine` phase (see AUDIT directive format below), removes resolved CONFIDENCE markers, and updates the section status in `INDEX.md` to `audit`. (Skill: `research-audit`)

**Invocation**: `/research-audit [topic-path] [operation]` — e.g., `/research-audit data-pipelines/batch-processing.md consistency` or `/research-audit api-design/ quality`. Both arguments are optional; omitting the path audits all topics, omitting the operation runs all audit checks. Operations: `consistency`, `coverage`, `quality`, `coherence`.

## Refine
A separate phase for refining or adapting any topic based on new information or previous audits. It operates on the currently selected topic file and resolves AUDIT directive comments. It is provided refinement instructions like `correct` (information is inaccurate/wrong), `expand`, `condense`, `restructure`, `cross-reference`, and `update` (new information supersedes old, distinct from `correct`) together with details on the expected refinement. These operations are examples, the skill should be able to handle any content-level correction within a single topic file. Updates the section status in `INDEX.md` after refinement. (Skill: `research-refine` )

**Invocation**: `/research-refine <topic-file> <operation> [details]` — e.g., `/research-refine api-design/versioning.md correct "Section 2.1 cites an outdated API version"`. Operations: `correct`, `expand`, `condense`, `restructure`, `cross-reference`, `update`, or any free-text instruction scoped to the topic.

## Restructure
A separate phase for structural changes that affect the project layout. It handles `split` (topic file grew too large), `merge` (two topics overlap too much), `promote` (convert a single file into a directory with child files), and `demote` (collapse a directory back into a single file). These operations trigger `INDEX.md` updates and require rewriting all cross-references that used the old path. (Skill: `research-restructure` )

**Invocation**: `/research-restructure <operation> <topic-path> [target-path]` — e.g., `/research-restructure split data-pipelines.md`, `/research-restructure merge api-design/rest-conventions.md api-design/versioning.md`, `/research-restructure promote data-pipelines.md`, or `/research-restructure demote data-pipelines/`.

## Glossary Sync
A utility phase that reconciles `glossary.md` against current topic content. It adds new terms introduced during investigation or refinement, updates definitions that have changed, and removes terms that are no longer used. Should be invoked after any content-changing phase (investigation, refine, restructure). (Skill: `research-glossary-sync` )

**Invocation**: `/research-glossary-sync` — no arguments; scans all topic files against `glossary.md`.

# Error and Escape Handling
When a skill cannot complete its task, it must not silently fail or produce partial results without signaling the problem. The following policies apply:

- **Scope mismatch**: If investigation discovers that a section's RESEARCH query is ill-defined, overlaps with another section, or requires structural changes, the skill should leave a `<!-- AUDIT: type: gap, severity: major, detail: "..." -->` comment explaining the problem, write best-effort content, and proceed. It must not restructure the topic.
- **Missing prerequisites**: If a skill is invoked on a section whose status does not meet the required precondition (e.g., running investigation on a `stub` section that has no RESEARCH directive), the skill should abort with a clear error message stating what is missing and which phase should run first.
- **Contradictory directives**: If a section contains directives that conflict with each other or with `INDEX.md` (e.g., status says `done` but AUDIT comments are present), the skill should flag the inconsistency to the user and not proceed until resolved.
- **Source verification failure**: If a URL cannot be fetched or returns content that does not match the cited claim, the reference must be marked `verified: false` in `references.yaml` and a `<!-- CONFIDENCE: low -->` marker placed on the associated claim.
- **Unrecoverable errors**: If a skill encounters an error it cannot handle (e.g., file not found, permission denied), it should report the error clearly and make no changes to any files.

# Files

## Topic Files

The frontmatter for each topic file contains:

```
---
title: "Topic Title"
created: 2026-02-17
updated: 2026-03-17
---
```


The `RESEARCH` directives are structured like:

```
<!-- RESEARCH:
  query: "How does X relate to Y in context Z?"
  scale: brief | standard | deep
  scale_detail: "> 3 examples"            # optional free-text override
  sources: academic | industry | primary | any
  sources_detail: "post-2023, peer-reviewed" # optional free-text override
  related: "data-pipelines/batch-processing.md#error-handling"
-->
```

- `scale`: `brief` (~1-2 paragraphs, overview), `standard` (~3-5 paragraphs, with examples), `deep` (comprehensive treatment, multiple perspectives).
- `sources`: `academic` (papers, journals), `industry` (blog posts, docs, conference talks), `primary` (official specs, RFCs, source code), `any` (no restriction).

`CONFIDENCE` markers flag individual claims that need verification:

```
<!-- CONFIDENCE: low | medium
  reason: "No primary source found; inferred from adjacent examples"
-->
```

- `low`: claim is speculative, inferred, or based on a single weak source. Audit should prioritize these.
- `medium`: claim is plausible and partially supported but lacks strong direct evidence.
- High confidence is the default and needs no marker. The audit phase should treat unmarked claims as well-sourced and focus verification effort on `low` and `medium` markers first.

The `AUDIT` directives are structured like:

```
<!-- AUDIT:
  type: contradiction | gap | weak-source | flow
  severity: minor | major
  detail: "Section claims X, but api-design/versioning.md#deprecation-policy states the opposite"
  ref: "api-design/versioning.md#deprecation-policy"
-->
```

## References

References are split between two locations:

### `<topic>_references.yaml` — Full Reference Data

Each topic file `<name>.md` has a sibling `<name>_references.yaml` in the same directory. The YAML file maps citation keys to structured metadata:

```yaml
vaswani-2017:
  title: "Attention Is All You Need"
  authors: Ashish Vaswani, Noam Shazeer, Niki Parmar, Jakob Uszkoreit, Llion Jones, Aidan N. Gomez, Lukasz Kaiser, Illia Polosukhin
  url: https://arxiv.org/abs/1706.03762
  published: 2017-06-12
  last-checked: 2026-04-04
  verified: true
```

Fields are all optional beyond `title`. Common fields: `title`, `authors`, `url` (for URLs/blogs/documentation), `isbn` (for books), `published`, `last-checked`, `verified`. The `verified` field defaults to `false` if omitted.

Citation keys should be descriptive and stable — typically `author-year` or `slug-year` (e.g., `vaswani-2017`, `react-docs-2024`, `rfc-7519`).

### Markdown — Short-Form References and In-Text Citations

Each section in a topic file ends with a `### References` subheading listing the references used in that section:

```markdown
### References

- [vaswani-2017] "Attention Is All You Need" ("Introduced the transformer, demonstrating that self-attention alone — without recurrence or convolution — achieves state-of-the-art translation quality with dramatically less training time.")
- [dean-2004] "MapReduce: Simplified Data Processing on Large Clusters" ("Established the programming model for distributed batch processing at scale.")
```

Each entry has the format: `- [citation-key] "Title" ("Takeaway relevant to this section.")`

In-text citations use `[citation-key]` or `[citation-key, pp. 12-15]` for page ranges:

```markdown
The transformer architecture [vaswani-2017] replaced recurrence with self-attention.
As shown in the original paper [vaswani-2017, pp. 5-6], multi-head attention allows...
```

## `INDEX.md`
`INDEX.md` contains the outline of the current research project and a brief abstract for each structure. Headings use the relative path from `content/` as their identifier, mirroring the directory tree:

```
# <Research Topic>
<abstract>

## data-pipelines/
<abstract>

### data-pipelines/batch-processing.md
**Status**: stub | inquiry | draft | audit | done

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

Directory entries (`##`) group their child topics but do not carry a status themselves. Only leaf topic files (`###`) have a status.

Section status lifecycle: `stub` → `inquiry` → `draft` → `audit` → `done`.
- `stub`: topic file created during inception, no content yet.
- `inquiry`: section headings and RESEARCH directives placed by the inquiry phase.
- `draft`: section content written by the investigation phase.
- `audit`: section reviewed by the audit phase; may have AUDIT directive comments pending.
- `done`: all audit findings resolved, content finalized.

Each skill may only advance status forward (e.g., investigation moves `inquiry` → `draft`). The `refine` skill does not change status unless it resolves all outstanding AUDIT comments, in which case it advances `audit` → `done`.

## `glossary.md`
Provides a concise and ordered list of all terms used and their brief definitions. Each entry can can contain a reference if the definition within that reference is useful and in line with the research.

## `DECISIONS.md`
Contains a structured list of decisions taken (exclusion of a certain source, choosing between competing sources, ...). This file also includes explicit turning points in which the conclusion on a specific topic changes due to new material, further research or experiments.

When sources directly contradict each other, the handling policy is:
1. Both positions are presented in the section text.
2. A `DECISIONS.md` entry is added explaining which position was adopted and the reasoning.
3. An `<!-- AUDIT: type: contradiction ... -->` comment is inserted so the audit phase can verify the resolution.

## Assets
Assets are co-located with their topic file. When a topic `<name>.md` has assets, they go in a sibling `<name>_assets/` directory and are referenced using relative paths (e.g., `![diagram](authentication_assets/flow.png)`). Do not create a central `assets/` directory.

Similarly, references are co-located: `<name>.md` has a sibling `<name>_references.yaml`. See the References section above for the full format.