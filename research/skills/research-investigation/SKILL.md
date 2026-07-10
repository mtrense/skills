---
name: research-investigation
description: "Research and write content for a single section of a topic file based on its RESEARCH directive. Runs as a forked subagent: drives the web search-fetch-verify loop inline, then synthesizes the section. Arguments: topic file path, optional section heading (defaults to the first section still carrying a RESEARCH directive)."
argument-hint: "<topic-file> [\"section-heading\"]"
model: opus
context: fork
agent: research-investigation-worker
allowed-tools: Bash(bash */skills/research-status/research-status.sh *)
---

# Research Investigation

You are researching and writing content for a single section of a topic file, guided by its RESEARCH directive.

You run as a forked subagent. The entire investigation — search, fetch, verify, synthesise — happens in your own context and is discarded when you exit. The outer orchestrator only sees the final report block at the end of this prompt.

**Arguments**: `$ARGUMENTS`
- First argument: topic file path relative to `research/content/`
- Second argument (optional, quoted): section heading to investigate. If omitted, operate on the first section that still has a RESEARCH directive.

If the second argument is missing and you are running under `/research-investigation-cycle`, halt with reason `missing section_heading — orchestrator must disambiguate`. (Direct human invocations may omit it.)

## Prerequisites

1. Derive the topic's status by running `bash <skills-root>/research-status/research-status.sh research --path <topic-file>` and reading the first whitespace-delimited field of the output line. (`<skills-root>` is the `.claude/skills/` directory the research skills are installed in — `~/.claude/skills` for a global install, `<project>/.claude/skills` for a project install.) Confirm the derived status is `inquiry` or `draft` (partially investigated).
   - If the derived status is `stub`, abort: "Run `/research-inquiry` first to create the section outline."
   - If the derived status is `audited` or `done`, abort: "This topic has already passed investigation. Use `/research-refine` to make changes."
2. Read `research/CLAUDE.md` for conventions, tone, citation style.
3. Read the target topic file at `research/content/<topic-file>`.
4. Locate the target RESEARCH directive. If a section heading was specified, find the RESEARCH directive under that heading. Otherwise, find the first `<!-- RESEARCH: ... -->` directive in the file.
   - The **scope** of this invocation is the single heading that directly contains the RESEARCH directive — do NOT expand scope to parent or sibling sections, even if they share a heading hierarchy.
   - If no RESEARCH directive is found, abort: "No sections pending investigation in this file."
5. Read related topics/sections referenced in the directive's `related` field.
6. Read `research/DECISIONS.md` for any prior decisions affecting this topic.
7. If a sibling `<topic-name>_references.yaml` exists, read it so existing citation keys can be reused.

## Research Process

### Step 1 — Plan the search

Translate the directive into 2–5 `WebSearch` queries. Use the directive's own `query` as the seed; vary phrasing for breadth. Bias toward the `sources`/`sources_detail` class:

- `academic` — prefer arXiv, ACL, ACM, IEEE, journal pages, Google Scholar's referenced PDFs. Add domain qualifiers (`site:arxiv.org`, `filetype:pdf`).
- `industry` — prefer engineering blogs of recognised orgs, postmortems, conference talks, vendor docs. De-prioritise marketing pages.
- `primary` — prefer specs (RFCs, W3C, ISO/IETC, language standards), official docs, source-code permalinks, release notes.
- `any` — broad: run two or three search arcs sequentially (academic / industry / primary) so the final citation mix is balanced. Within one fork these arcs are serial, not parallel.

Respect `sources_detail` filters (e.g., "post-2023", "peer-reviewed"). If a constraint is unsatisfiable from the open web, note it in `Tooling Notes` at the end rather than silently relaxing it.

### Step 2 — Fetch and skim

For each promising search hit, use `WebFetch` to read the page and extract:

- The 1–3 sentences that directly support a claim relevant to the directive's `query`.
- The author / publisher / date metadata you can verify on the page.
- Whether the page actually says what the search snippet implied (search snippets often misrepresent — verify).

Stop fetching when the volume of distinct, supporting quotes is enough to satisfy the directive's `scale`:

- `brief` — 2–4 verified quotes from 2–3 sources is plenty.
- `standard` — 6–10 quotes from 4–6 sources.
- `deep` — 10+ quotes spanning multiple perspectives, including at least one source that pushes back on the dominant view if such a view exists.

Cap `WebFetch` at ~10 calls per invocation. Beyond that the marginal return is poor; lean toward a smaller scale instead.

### Step 3 — Verify each URL

A citation's `verified` status is binary:

- `verified: true` — the page fetched cleanly **and** its content matches the quote you intend to attribute.
- `verified: false` — the page failed to fetch, returned a paywall / login wall, or the content does not match the quote.

If a high-value source can't be fetched but the citation's title/author strongly suggest the quote is supported (e.g., a known paper visible only on a paywalled journal), record it as `verified: false` with a `note:` explaining why — you may still cite it but mark the claim with a CONFIDENCE marker (Step 6).

### Step 4 — Note contradictions

If two or more sources directly disagree on a claim relevant to the directive, do **not** pick a winner. Record both positions for Step 7's DECISIONS.md handling.

### Step 5 — Per-claim confidence

For each distinct claim you propose to surface, classify the supporting evidence:

- `well-sourced` — multiple independent sources agree, all verified.
- `medium` — single strong source, or multiple sources that aren't fully independent.
- `low` — single weak source, paywalled / unverifiable, or you inferred the claim across two pages without a direct statement.

You'll use these in Step 6 to decide whether a `<!-- CONFIDENCE: ... -->` marker is needed.

### Step 6 — Write content

Write the section content under the heading that contained the RESEARCH directive. Guidelines:

- **Scale**: Match the `scale` field — `brief` (~1-2 paragraphs), `standard` (~3-5 paragraphs with examples), `deep` (comprehensive, multiple perspectives). If you couldn't reach the target scale (Step 2 hit the fetch cap or sources were thin), lean toward the next-smaller scale and note the limitation in the report block's `Notes` line.
- **Tone and style**: Follow `research/CLAUDE.md` conventions.
- **Structure**: Add subheadings one level deeper if needed for deep-scale content. Do NOT write content under sibling or child headings that have their own RESEARCH directives.
- **Cross-references**: Link to related topics using `[display text](relative-path.md#heading-slug)` relative to `content/`.
- **Cite only verified facts**: every in-text `[citation-key]` must correspond to a source you actually fetched in Step 2. Do not invent claims that no fetched quote supports.

Apply confidence markers from Step 5 immediately after the claim they qualify:

```
<!-- CONFIDENCE: medium
  reason: "Description of why evidence is incomplete"
-->
```

```
<!-- CONFIDENCE: low
  reason: "Description of why this is uncertain"
-->
```

`well-sourced` claims need no marker.

### Step 7 — Handle contradictions

For each contradiction noted in Step 4:

1. Present both positions in the section text.
2. Append a `DECISIONS.md` entry:
   ```
   ### DEC-NNN: <title>
   **Date**: <today>
   **Topic**: <topic-file-path>
   **Context**: <what the contradiction is>
   **Decision**: <which position was adopted>
   **Rationale**: <why>
   **Alternatives considered**: <the other position and why it was not chosen>
   ```
   Also add a row to the summary table in DECISIONS.md. Pick the next free `DEC-NNN` by re-reading DECISIONS.md immediately before appending — concurrent forks can otherwise race on numbering.
3. Insert an audit comment near the contradiction in the section text:
   ```
   <!-- AUDIT:
     type: contradiction
     severity: major
     detail: "Sources disagree on X — see DEC-NNN"
     ref: "DECISIONS.md#dec-nnn"
   -->
   ```

### Step 8 — References

References are stored in two places: full metadata in a YAML file, and short-form entries in the markdown.

**8a — Update `references.yaml`**

For each citation actually used in the prose, write/update an entry in `<topic-name>_references.yaml`:

```yaml
citation-key:
  title: "Name of the resource"
  authors: Author Name, Another Author
  url: https://actual-url
  published: 2024-01-15
  last-checked: <today>
  verified: true | false
```

Fields are optional beyond `title`. Use `url` for web resources, `isbn` for books. Reuse stable keys already present in the file when the same source resurfaces.

**8b — Add in-text citations**

Cite sources inline using `[citation-key]` or `[citation-key, pp. N-M]` for page ranges.

**8c — Add section references list**

Add a `### References` subheading at the end of the section (before the next `##` section):

```markdown
### References

- [citation-key] "Title" ("One-sentence takeaway relevant to this section.")
```

### Step 9 — Clean up

- **Remove** the `<!-- RESEARCH: ... -->` directive from the investigated section.
- **Preserve** RESEARCH directives in all other sections.

### Step 10 — Status derivation (no write)

Status is never stored; it is derived from the on-disk signals. Removing this section's RESEARCH directive in Step 9 is exactly what advances the derivation: once the file's **last** RESEARCH directive is gone, `research-status.sh` reports the topic as `draft` on its own. If other sections still carry RESEARCH directives, the derivation stays `inquiry`. Either way, do nothing here — leave the derivation to reflect the disk.

Update the `updated` date in frontmatter to today.

## Git

Do NOT commit. The user (or the orchestrating cycle) reviews and runs `/commit` when ready. Expected commit message format: `research(investigation): <topic-name> <section-reference>`.

## Halt conditions

HALT INSTEAD OF PUSHING THROUGH if any of these happen:

- The topic file does not contain a RESEARCH directive under the named section.
- The directive is malformed or ambiguous in a way that needs a human call.
- The derived status (see Prerequisites) is `stub`, `audited`, or `done`.
- A new `DEC-NNN` you tried to write collides with an existing ID (another fork beat you to that number). Re-read DECISIONS.md, pick the next free number, and continue — but if the collision keeps happening, halt with reason `DECISIONS.md numbering race`.
- Web research returns zero usable sources for a load-bearing claim — write what you can but halt rather than fabricate.
- Anything else that would normally cause you to ask the human a question.

When you halt, do not loop, do not retry, do not move to another directive.

## Report format — required exit signal

End your final message with exactly one fenced ` ```report ` block. The outer orchestrator parses it; missing or malformed blocks are treated as failure.

**Success**:

```report
Topic: <topic_file>
Section: <section_heading>
Prose: <approx word count> words
Citations: <comma-separated citation keys, or "—">
New decisions: <comma-separated DEC-NNN IDs added to DECISIONS.md, or "—">
Audits inserted: <count and severities, e.g. "1 major (gap), 1 minor (contradiction)", or "—">
Derived status: <e.g. "inquiry → draft (RESEARCH directives remaining: 0)", or "inquiry (RESEARCH directives remaining: N)"> — derived, not written
Notes: <one short line — e.g. "leaned brief: only 3 verified sources found", or "—">
```

**Halted**:

```report
HALTED
Topic: <topic_file>
Section: <section_heading or "—">
Reason: <one or two sentences>
State: <what's on disk — partial prose? unremoved directive? appended DECISIONS entry?>
```

Do not add free-form prose after the report block.

## Rules

- Only write content for ONE RESEARCH directive per invocation. The scope is the single heading that contains that directive — not a parent section, not sibling subsections.
- Do NOT modify other sections' content (only remove the directive from the investigated heading).
- Do NOT restructure the topic or change headings — if the section scope is wrong, leave an AUDIT comment.
- Do NOT fabricate sources, URLs, authors, dates, or quotes. Every citation must come from a page you actually fetched.
- If the RESEARCH directive's query is ill-defined or overlaps with another section, leave an AUDIT comment with `type: gap, severity: major` and write best-effort content from whatever you could surface.
- Do NOT run audit lenses or touch the frontmatter `audit:` field — this skill's scope ends at filling section content; advancing the derivation beyond `draft` is the audit phase's job.
- Do NOT commit.
