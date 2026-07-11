---
name: research-audit-topic
description: "Audit a single research topic across every lens — consistency, coverage, quality, coherence, and graphics — in one pass, inserting AUDIT directives and advancing the topic to `audited`. Runs as a forked subagent that inlines all lens analysis and CONFIDENCE verification (no nested subagents). Arguments: one topic path relative to research/content/."
argument-hint: "<topic-path>"
model: opus
context: fork
agent: research-audit-worker
---

# Research Audit — Whole-Topic (All Lenses)

You audit **one topic** across every audit lens in a single pass, then advance
it to `audited`. This is the per-item counterpart to the standalone
`/research-audit-*` skills (each of which runs one lens across all topics). You
are the unit of work that `/research-audit-cycle` fans out — one fork per topic.

You run as a **forked subagent**. All lens analysis and CONFIDENCE verification
happen inline in your own context (you have `WebSearch`/`WebFetch` for the
latter — there is **no** `Agent` or `Skill` tool, so no nested subagents). The
outer orchestrator only sees the final ` ```report ` block.

The standalone lens skills — `research-audit-consistency`, `-coverage`,
`-quality`, `-coherence`, `-graphics` — remain the authoritative, richer
description of each lens's heuristics and severity guide. This skill inlines a
faithful, compressed version of each so one topic can be audited end-to-end
without leaving the fork. Keep their conventions identical: same AUDIT comment
shapes, same severity calls, same `audit:` frontmatter tracking.

**Arguments**: `$ARGUMENTS`
- First argument (required): one topic path relative to `research/content/` — a
  file, or a directory (audit every eligible chapter file under it, one at a
  time). If missing, halt with reason `missing topic path`.

## Prerequisites

1. Resolve the argument to the in-scope file(s) and **derive** each one's status
   with the helper: `bash <skills-root>/research-status/research-status.sh research --path <topic>`,
   reading the first whitespace-delimited field. (`<skills-root>` is the
   `.claude/skills/` directory the research skills are installed in —
   `~/.claude/skills` global, `<project>/.claude/skills` project. The helper is
   available inside this fork.)
   - A topic at derived status `stub` or `inquiry` is **not ready** — halt with
     reason `topic not ready for audit (status: <status>)`.
   - Eligible statuses: `draft`, `audited`, `done`. (Re-auditing an already
     `audited`/`done` topic is allowed but should be rare — the cycle skips
     these; a direct invocation may re-run.)
2. Read `research/CLAUDE.md` for project conventions and tone.
3. Read `research/DECISIONS.md` for prior decisions.
4. Read `research/glossary.md` for term definitions.
5. Read the in-scope topic file(s) end-to-end. You may also **read** sibling
   topics (read-only) when a lens needs cross-topic comparison — but you write
   **only** to your own topic's file(s) and their sibling `_references.yaml`.
   (You derive your own topic's status from the helper; there is no stored status
   to write.)

Process each in-scope file fully (all lenses) before moving to the next. Never
touch a file outside your argument's path.

## Pass 0 — CONFIDENCE markers (highest priority)

Before the lenses, resolve outstanding `<!-- CONFIDENCE: low -->` and
`<!-- CONFIDENCE: medium -->` markers in the in-scope file(s). Grep for
`<!-- CONFIDENCE:` and, for each hit, capture `file`, `line`, `level`, the
marker's `reason:`, the 1–3 sentences of `claim` it qualifies, any
`[citation-key]` slugs already cited, and the matching `<topic>_references.yaml`
entries (url, title, authors, published, `verified`).

Verify each marker inline with `WebSearch` + `WebFetch` (you are the verifier —
there is no `confidence-verifier` subagent to delegate to). This pass is **total
over CONFIDENCE**: every marker is either verified-and-removed or converted to an
AUDIT directive. A CONFIDENCE marker is never kept, downgraded, or left in place —
its only consumer is this audit pass, so anything unresolved must become an AUDIT
for the refine phase. Zero CONFIDENCE markers may remain in the file when Pass 0
finishes. Apply:

- **Verified** → remove the marker; set `verified: true` and
  `last-checked: <today>` on the citation in `references.yaml`; ensure the key
  is in the section's `### References` list.
- **Verified via a new source** → remove the marker; add the new entry to
  `references.yaml`; add the in-text `[citation-key]` and the `### References`
  line.
- **Contradiction found** → **delete the CONFIDENCE marker** and insert an AUDIT
  comment (`type: contradiction`, `ref:` the source URL) after the claim. If the
  contradiction is decision-worthy, note it for the report (the cycle surfaces
  it; DECISIONS.md entries are the refine phase's job, not yours).
- **Weak source / still shaky / unresolvable** → **delete the CONFIDENCE marker**
  and insert an AUDIT comment (`type: weak-source`) whose `reason:` captures what
  remains unconfirmed. Never leave the marker behind.

## The lenses

Run all five, in this order, on each in-scope file. Insert every AUDIT comment
immediately after the line/content it refers to, using the exact shapes below.
If an AUDIT comment already exists at a location with the same `type` (and
`aspect`/`graphic-type` where applicable), do **not** duplicate — update its
`detail` only if you surfaced new information.

### Lens 1 — Consistency (cross-topic contradictions)

Compare this topic's claims against the other in-scope topics (read them
read-only as needed) and the glossary. Look for direct contradictions
(A says X, B says not-X), inconsistent terminology for the same concept,
conflicting recommendations, and inconsistent glossary-term use.

```html
<!-- AUDIT:
  type: contradiction
  severity: minor | major
  detail: "This section claims X, but <other-topic>#<section> states Y"
  ref: "<other-topic-path>#<section-slug>"
-->
```

Severity: `major` = factual error / direct contradiction; `minor` =
inconsistent terminology or style.

### Lens 2 — Coverage (gaps vs the research plan)

Compare content against the plan in `INDEX.md`: are planned sections addressed;
are obvious referenced subtopics missing; do cross-references point to sections
that exist and are written (not stubs); is anything discussed in prose but
absent from `INDEX.md`?

```html
<!-- AUDIT:
  type: gap
  severity: minor | major
  detail: "Section references 'caching strategies' but no topic covers this"
  ref: "<relevant-index-entry-or-topic>"
-->
```

Severity: `major` = missing critical content / broken cross-reference; `minor` =
minor or peripheral gaps.

### Lens 3 — Quality (depth & sourcing)

For each investigated section (skip sections that still carry a
`<!-- RESEARCH: ... -->` directive):

- **Depth vs scale** — infer the intended scale from sibling sections' surviving
  directives and the content's own shape (`brief` ≈ 1–2 paragraphs; `standard` ≈
  3–5 with examples; `deep` ≈ comprehensive, multi-perspective). Flag sections
  that read thin under a load-bearing heading, or verbose-but-shallow under a
  `deep` heading, or stub-like (1–2 sentences) under a non-trivial heading.
- **Sourcing** — for each substantive factual claim, check there is a nearby
  in-text `[citation-key]`, that it resolves in `references.yaml`, that the entry
  is `verified: true`, and that the key appears in the section's `### References`
  block. Flag missing/weak/unverified sourcing.
- **Example concreteness** — flag abstract claims that assert a mechanism or
  ratio with no concrete example.

```html
<!-- AUDIT:
  type: weak-source | contradiction
  severity: minor | major
  detail: "<finding; prepend a suggested action when useful>"
  ref: ""
-->
```

Severity: `major` = factual error / missing critical sourcing (or a thin central
claim); `minor` = weak-but-not-wrong sourcing, missing examples.

### Lens 4 — Coherence (narrative flow)

Build the heading outline (`##`/`###`, first + last sentence of each), skipping
un-investigated sections. Assess:

- **Progression** — do headings move through a defensible order (concept →
  mechanism → application), or bounce? Would a section read better elsewhere?
- **Transitions** — are adjacent sections bridged, or does the reader get
  dropped in? (Respect a terse house style in `CLAUDE.md` — don't flag every
  join.)
- **Abstraction consistency** — are sibling sections at the same depth?
- **Intro adequacy** — does the intro set up what follows?
- **Heading-vs-content match** — does each section deliver what its heading
  promises?

```html
<!-- AUDIT:
  type: flow
  severity: minor | major
  detail: "<aspect>: <finding>"
  ref: ""
-->
```

Prefix `detail` with the `aspect` (`progression`, `transition`, `abstraction`,
`intro`, `heading-mismatch`). Severity: `major` = broken progression / content
doesn't match heading; `minor` = rough transitions, soft re-orderings.

**Structural-depth smell check** — only when the argument was a directory (a
whole topic), not a single chapter: for each chapter file nested 4+ levels deep
under `content/` (4+ `/` in its relative path), insert at the top of the
chapter body (after the H1):

```html
<!-- AUDIT:
  type: flow
  severity: minor
  detail: "structure: chapter nests 4+ levels deep — consider /research-restructure flatten or merge to reduce depth"
  ref: ""
-->
```

### Lens 5 — Graphics (visual opportunities) — supplementary

Flag content that a visual would materially clarify: processes/architectures
(diagram), quantitative comparisons or trends (graph), 3+ item comparisons
buried in prose (table), protocol/format/layout (schematic), UI/tool output
(screenshot). Be selective — a handful of high-value suggestions beats flagging
every paragraph.

```html
<!-- AUDIT:
  type: graphics
  severity: minor | major
  detail: "This section describes a 5-step auth flow with branching — a sequence diagram would clarify the handshake"
  graphic-type: diagram | graph | table | schematic | screenshot
  ref: ""
-->
```

Severity: `major` = genuinely hard to follow without the visual; `minor` = a
visual would be nice but prose is adequate.

## Write-out (per in-scope file)

1. AUDIT comments inserted (Passes/Lenses above).
2. Every CONFIDENCE marker cleared — removed when verified, converted to an AUDIT
   otherwise; none remain. `references.yaml` updated.
3. **`audit:` frontmatter** — add/update the list to include every lens you
   completed on this file. The four **core** lenses are `consistency`,
   `coverage`, `quality`, `coherence`; `graphics` is supplementary. Append
   without duplicating. This is what advances the topic's derived status: once
   the `audit:` list contains all four core types, the derivation reports
   `audited` on its own — there is no status to flip anywhere. `graphics` alone
   never advances status.
4. Update the `updated` date in each modified file's frontmatter.

## Rules

- **Do NOT modify content.** Only insert/remove comments and update
  status/dates/`references.yaml`. Resolving AUDIT findings is the refine phase.
- **Write only within your topic's path.** Reading siblings is fine (consistency
  needs it); writing to them is not.
- **No commits.** The outer orchestrator / human reviews and runs `/commit`.
- **No nested subagents.** CONFIDENCE verification and every lens run inline.
- Halt (don't ask questions) if anything blocks you — emit the HALTED report.

## Report (required exit signal)

End your run with exactly one fenced ` ```report ` block. The orchestrator
parses it; free-form prose after it is an error.

```report
STATUS: OK | HALTED
topic: <argument path>
files_audited: <n>
lenses_completed: [consistency, coverage, quality, coherence, graphics]
findings: contradiction=<n> gap=<n> weak-source=<n> flow=<n> graphics=<n>
confidence_cleared: <n found> → verified=<n removed> converted=<n to AUDIT> (must sum to found; 0 left in file)
derived_status: <e.g. draft → audited, or unchanged — derived from the `audit:` field now holding all four core lenses, not a written flip>
halt_reason: <verbatim reason, or none>
```
