# Skill Family: Research

A family of skills for building structured knowledge bases with Claude Code, intended for both human review and AI-native consumption. Operates entirely on markdown files. Content is organized hierarchically into **topics** (top-level subjects under `content/`), **chapters** (individual `.md` files within a topic, possibly nested several directories deep), and **sections** (headings within a chapter). Filenames are stable keys for cross-references, git history, and `INDEX.md` entries. The output is not academic-grade research; it is practical, citable knowledge tuned for downstream coding and writing.

## Terminology

- **Topic** — a top-level node directly under `content/`. May be a single `.md` file (shallow subject) or a directory containing chapters (broader subject). Created by `/research-inception` or `/research-add-topic`.
- **Chapter** — any `.md` file at any depth inside a topic. The leaf unit of work for inquiry, investigation, audit, and refine. A chapter at depth 1 is the topic itself (single-file topic); a chapter at depth 2+ lives in a subdirectory. Informal terms "sub-chapter" and "sub-sub-chapter" just describe depth — structurally there is one concept.
- **Section** — a heading (`##`, `###`, …) within a chapter file. The granularity at which RESEARCH directives, CONFIDENCE markers, and AUDIT directives are placed.

Nesting depth is unbounded but should follow the material. The coherence audit flags chapters nested four or more levels deep as a smell.

## Skill Family

A phased workflow with four broad steps — bootstrap, inquiry, investigation, and audit-then-refine — plus structural and glossary maintenance utilities. All skills currently set `disable-model-invocation: true` and are user-invoked, so each phase is an explicit, reviewable step rather than an autonomous loop.

1. **`/research-inception`** — One-time bootstrap. Creates `research/CLAUDE.md` (research conventions, citation style, tone), `INDEX.md` (topic outline), `DECISIONS.md`, `glossary.md`, and one stub topic file per declared topic.
   **Invocation**: `/research-inception` — no arguments; operates on the entire project.

2. **`/research-add-topic <topic-name> [summary]`** — Adds a new top-level topic to an existing project (single chapter file or directory with chapter stubs, plus `INDEX.md` entry).

3. **`/research-add-chapter <parent-directory>`** — Adds new chapter stubs under an existing directory in the topic tree. Works at any depth: a top-level topic directory, or a nested sub-directory. If the target is a single `.md` chapter, the skill prompts to promote it to a directory first (delegating to `/research-restructure promote`).

4. **`/research-inquiry <topic-file>`** — Coarse outline phase. Adds section headings to the topic file with `<!-- RESEARCH: ... -->` directives capturing the query, expected scale, source profile, and related sections. Advances section status to `inquiry`.
   **Invocation**: `/research-inquiry data-pipelines/batch-processing.md`.

5. **`/research-investigation <topic-file> [section-heading]`** — Fills one section based on its RESEARCH directive. Adds references to `<topic>_references.yaml`, attempts URL verification, and tags any claim that lacks strong sourcing with a `<!-- CONFIDENCE: low | medium -->` marker. When sources directly contradict, both positions are presented in-text, a `DECISIONS.md` entry records which was adopted and why, and an AUDIT directive is inserted for follow-up. Removes the RESEARCH directive once fulfilled and advances status to `draft`.
   **Invocation**: `/research-investigation data-pipelines/batch-processing.md "Error Handling"`. Omitting the section operates on the first section still in `inquiry` status.

6. **`/research-audit-consistency [topic-path]`**, **`/research-audit-coverage [topic-path]`**, **`/research-audit-quality [topic-path]`**, **`/research-audit-coherence [topic-path]`** — Four narrow audit skills (one per concern: cross-topic contradictions, gaps relative to the plan, depth and sourcing adequacy, narrative flow). Each prioritizes claims marked with `<!-- CONFIDENCE: low | medium -->`, verifies or upgrades them before auditing unmarked content, removes resolved CONFIDENCE markers, and inserts `<!-- AUDIT: ... -->` directives for follow-up. The optional path scopes to one file or a directory subtree; omitting it audits everything. Advances status to `audited`.

7. **`/research-refine <topic-file> <operation> [details]`** — Resolves AUDIT directives within a single topic. Built-in operations: `correct` (information is wrong), `expand`, `condense`, `restructure`, `cross-reference`, `update` (new information supersedes old, distinct from `correct`). Free-text instructions scoped to the topic also work. Status is unchanged unless all outstanding AUDIT comments are cleared, in which case it advances `audited` → `done`.

8. **`/research-restructure <operation> <chapter-path> [target-path]`** — Structural changes that affect layout. Operations apply at any depth in the topic tree:
   - `split` — break an oversized chapter into siblings (or into a new sub-directory).
   - `merge` — combine two overlapping chapters into one.
   - `promote` — convert a `.md` chapter into a directory with child chapters.
   - `demote` — collapse a directory back into a single `.md` chapter.
   - `nest <chapter> <target>` — move a chapter under another chapter; promotes the target to a directory first if needed.
   - `flatten <chapter>` — move a chapter up one level (out of its current sub-directory).

   All ops update `INDEX.md` and rewrite every cross-reference that used the old path.

9. **`/research-glossary-sync`** — Reconciles `glossary.md` with current topic content. Adds new terms introduced during investigation or refinement, updates changed definitions, removes unused terms. Should be run after any content-changing phase.

10. **`/research-status [path] [--status S]`** — Read-only progress report. Runs the shared `research-status.sh` helper to derive and print each chapter's status (live, from on-disk signals) with detail counts of what is still missing. The human-facing front end to the same helper every other skill consults for status. See [Status Lifecycle](#status-lifecycle).

## Project Layout

Everything lives under a `research/` folder so the same repository can host other workflows (milestone-driven, codebase-survey) without collision:

```
/
├── CLAUDE.md
├── research/
│   ├── CLAUDE.md
│   ├── INDEX.md
│   ├── DECISIONS.md
│   ├── glossary.md
│   ├── content/
│   │   ├── authentication.md                 ← single-chapter topic (shallow)
│   │   ├── authentication_references.yaml
│   │   ├── data-pipelines/                   ← topic as directory
│   │   │   ├── batch-processing.md           ← chapter at depth 2
│   │   │   ├── batch-processing_references.yaml
│   │   │   ├── stream-processing.md
│   │   │   └── stream-processing_references.yaml
│   │   ├── api-design/                       ← topic with nested sub-directories
│   │   │   ├── overview.md                   ← chapter at depth 2
│   │   │   ├── overview_references.yaml
│   │   │   ├── rest/                         ← sub-chapter group
│   │   │   │   ├── conventions.md            ← chapter at depth 3
│   │   │   │   ├── conventions_references.yaml
│   │   │   │   ├── versioning.md
│   │   │   │   └── versioning_references.yaml
│   │   │   └── graphql/
│   │   │       ├── schema-design.md
│   │   │       └── schema-design_references.yaml
│   │   └── ...
├── src/
│   ├── CLAUDE.md
│   └── ...
└── ...
```

Chapter filenames are descriptive and stable — no numeric prefixes. A chapter that outgrows itself is `promote`d into a directory; sibling chapters can be regrouped via `nest`/`flatten`. Nesting is unbounded; depth should follow the material, not a fixed template. Directory overviews live in the matching heading in `INDEX.md`; there is no separate index file per directory. The repo-root `CLAUDE.md` is project-wide and out of scope for these skills (the research-specific conventions live in `research/CLAUDE.md`).

Assets are co-located with their chapter file: when `<name>.md` has assets they go in a sibling `<name>_assets/` directory and are referenced with relative paths (e.g. `![diagram](authentication_assets/flow.png)`). References are similarly co-located in `<name>_references.yaml`. There is no central `assets/` directory.

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

Outline of the project plus a brief abstract per node. Every leaf chapter heading is a markdown link whose text is the path relative to `content/` and whose target is that path prefixed with `content/` (relative to `INDEX.md`) — so the tree mirrors the directory layout, stays navigable in any markdown viewer, and is machine-parsable by the helper scripts. Heading level matches nesting depth: top-level topics are `##`, chapters one level in are `###`, two levels in are `####`, and so on:

```
# <Research Topic>
<abstract>

## data-pipelines/
<abstract>

### [data-pipelines/batch-processing.md](content/data-pipelines/batch-processing.md)
<abstract>

### [data-pipelines/stream-processing.md](content/data-pipelines/stream-processing.md)
<abstract>

## [authentication.md](content/authentication.md)
<abstract>

## api-design/
<abstract>

### [api-design/overview.md](content/api-design/overview.md)
<abstract>

### api-design/rest/
<abstract for this sub-chapter group>

#### [api-design/rest/conventions.md](content/api-design/rest/conventions.md)
<abstract>

#### [api-design/rest/versioning.md](content/api-design/rest/versioning.md)
<abstract>
```

Directory entries (whether top-level `##` or nested `###`/`####`) group their children and stay plain-text path headings (no single file to link). Leaf `.md` chapters are rendered as markdown links. Every chapter in the tree appears in `INDEX.md` regardless of depth — sections within a chapter do not.

`INDEX.md` carries **no status field**. A chapter's status is not stored — it is derived on demand from the signals on disk (see [Status Lifecycle](#status-lifecycle)) by the `research-status.sh` helper. `INDEX.md` is purely the outline plus abstracts.

### `glossary.md`

Concise, ordered list of terms with brief definitions. Each entry may carry a citation when the cited definition is useful and aligned with the research.

### `DECISIONS.md`

Structured list of decisions taken (excluding a source, choosing between competing sources, …) and explicit turning points where conclusions change due to new material or experiments. The contradiction-handling policy is:

1. Both positions are presented in the section text.
2. A `DECISIONS.md` entry explains which was adopted and the reasoning.
3. An `<!-- AUDIT: type: contradiction ... -->` comment is inserted so the audit phase can verify the resolution.

## Source Verification

Each reference carries a `verified` field. Newly added references default to `verified: false`. The investigation skill attempts to fetch each URL; on success, sets `verified: true`. An **unverified reference is folded into the marker scheme** rather than acting as a separate gate: investigation places a `<!-- CONFIDENCE: low -->` marker on the claim it backs (so the chapter stays `draft`), and the audit phase — being total over CONFIDENCE — either verifies-and-removes it or converts it to an `<!-- AUDIT: type: weak-source -->` directive (so the chapter stays `audited` until refine resolves it). Reference verification therefore reaches `done` through the ordinary marker pipeline; there is no independent "unverified references remain" gate.

## Status Lifecycle

`stub` → `inquiry` → `draft` → `audited` → `done`.

Status is **derived, never stored**. There is no status enum in `INDEX.md` or in a
frontmatter field — a chapter's status is computed from the signals that actually
live on disk, so it can never drift out of sync with the work:

Status is the **earliest phase with an open worklist marker** — `RESEARCH ≺ CONFIDENCE ≺ AUDIT` — with the `audit:` lens field disambiguating a clean draft from `done`. Each marker type is the worklist of exactly one phase and has exactly one producer and one consumer:

| Marker present | Derived status | Producer → Consumer |
|---|---|---|
| `<!-- RESEARCH: -->` | `inquiry` | inquiry → investigation |
| `<!-- CONFIDENCE: -->` | `draft` | investigation → audit |
| `<!-- AUDIT: -->` | `audited` | audit → refine |
| none | `done` | refine → ∎ |

- `stub`: no section headings and no RESEARCH directives — a bare file from inception.
- `inquiry`: at least one open `<!-- RESEARCH: -->` directive (outline placed, not yet investigated).
- `draft`: no RESEARCH directives remain and the file has sections, and either an open `<!-- CONFIDENCE: -->` marker or fewer than the four core lenses recorded (investigated, not yet audited).
- `audited`: all four core lenses (`consistency`, `coverage`, `quality`, `coherence`) are recorded in `audit:`, **no open CONFIDENCE markers** (audit is total over them — see below), and open `<!-- AUDIT: -->` directives remain.
- `done`: all four core lenses recorded and no open marker of any kind.

The audit phase is **total over CONFIDENCE**: it verifies-and-removes each marker or converts the unresolved ones to an `<!-- AUDIT: -->` directive (`type: weak-source` / `contradiction`). No CONFIDENCE marker survives audit, so CONFIDENCE never gates `done` on its own — a stray marker at four lenses instead regresses the chapter to `draft` for re-audit (surfaced as `warn=stray-confidence`).

Skills that used to advance a stored status now simply do their work and leave the
signals that make the derivation move forward: investigation removes RESEARCH
directives (`inquiry` → `draft`), the audit lenses clear CONFIDENCE markers and
append to the `audit:` field (`draft` → `audited`), and refine clears AUDIT
directives (`audited` → `done`). No skill writes a status label anywhere.

### The `research-status.sh` helper

A single shared script computes the derivation. It ships in the `research-status`
skill directory and is the source of truth every skill consults instead of reading a
status from `INDEX.md`:

```
bash <skills-root>/research-status/research-status.sh <research-dir> [--path P] [--status S]
```

- `<skills-root>` — the `.claude/skills/` directory the skills are installed in
  (`~/.claude/skills` global, `<project>/.claude/skills` project-local).
- `<research-dir>` — the project's research directory (default `research`).
- `--path P` — scope to one chapter (`--path api-design/rest/conventions.md`) or a
  subtree (`--path api-design/`).
- `--status S` — emit only chapters whose derived status is `S` (used by the cycle
  skills to enumerate candidates: `--status stub`, `--status draft`, etc.).

It prints one line per chapter, ordered by `INDEX.md`, with detail counts of what is
still missing before `done`:

```
<status>  <rel_path>  research=N conf=lo/me audit=mi/ma lenses=D/4 gfx=y|n refs=V/T [warn=...]
```

`#`-prefixed lines are the header and the trailing `summary:` / `untracked:` footers
(a filtered run suppresses the footer, leaving a clean candidate list). `warn=`
appears only when signals contradict each other. The `/research-status` skill is the
human-facing wrapper around this helper.

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
