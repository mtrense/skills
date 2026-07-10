---
name: research-inception
description: "Initialize a research project structure with CLAUDE.md, INDEX.md, DECISIONS.md, glossary.md, and topic stubs. Use when starting a new research effort from scratch."
disable-model-invocation: true
model: opus
allowed-tools: Read, Glob, Write, Edit
argument-hint: <optional domain name>
---

# Research Inception

You are initializing a new research project. This is an interactive, Socratic phase — guide the user through defining their research scope before generating any files.

## Phase 0: Preflight

Before Discovery, glob `research/**` to inventory what's already on disk. Branch on what you find:

- **Greenfield** (no `research/` directory, or only an empty one) — proceed to Phase 1 as normal.
- **Fully initialised** (`research/INDEX.md` exists AND `research/content/` contains at least one topic file) — stop. Tell the user the project is already initialised and point them to the right targeted skill: `/research-add-topic` to add a new topic, `/research-add-chapter` to extend an existing topic, or `/research-inquiry` to start outlining sections. Do not proceed unless the user explicitly says they want to re-scaffold from scratch and acknowledges that existing files will be preserved (never overwritten).
- **Partial state** (some scaffolding present but incomplete — e.g. `CLAUDE.md` without `INDEX.md`, topic files on disk not listed in `INDEX.md`, or vice versa) — present the inventory to the user as a short list ("found: X, Y; missing: Z"), confirm they want to fill in the gaps, and carry that inventory into Phase 2. Topic files discovered on disk should be surfaced during Phase 1b so the user can decide whether to keep them and whether to extend the topic set.

In all non-greenfield cases, Phase 2 operates in **fill-gaps mode**: every Write is preceded by an existence check, and existing files are left untouched. Use Edit (never Write) if a structural addition to an existing file is genuinely needed — but prefer deferring that to the targeted skills above.

## Phase 1: Discovery (Interactive)

Guide the user through a structured conversation. Do NOT dump all questions at once. Ask 2–3 at a time, grouped by theme, and adapt based on answers. Typically this takes 3–5 rounds.

**Important:** Users often arrive knowing *what domain they want to research* but not fully aware of *why the research matters* or *what decisions it will ultimately inform*. Research without a clear "so what?" tends to drift in scope and depth. Your job is to uncover the real motivation before shaping the knowledge base.

### Phase 1a: Understand the Motivation (before the structure)

If `$ARGUMENTS` is provided, the user has named the domain up front. Acknowledge it —
"So you're looking to build a knowledge base around [paraphrase]" — and use it to skip the
"what domain?" opener and go straight to probing motivation and scope. But do NOT skip the
Socratic discovery. The domain name tells you *what*, not *why* — which makes the motivation
questions even more important.

Start here. Resist the urge to discuss topics or file structure until the purpose is clear.

**Need & Context**
- What's driving this research? Is there a decision, project, or problem it needs to inform?
- Who will use this knowledge base, and what will they do with it?
- What's the trigger — why now?

**Validation**
- If this knowledge base didn't exist, how would you (or your team) get the information you need? How well does that work?
- Have you seen existing resources on this domain? What's missing or wrong about them?

**Stakes & Scope Pressure**
- What happens if the research stays shallow or incomplete in the wrong areas?
- Are there time-sensitive decisions this needs to support?

### Phase 1b: Shape the Knowledge Base

Once you understand the motivation, explore what the research should cover.

1. **Research domain** — What broad area are we researching?
2. **Goals** — What practical outcomes should this knowledge base support? (Anchor these to the motivations discovered in Phase 1a.)
3. **Topics** — What specific topics should be covered? Help the user brainstorm and refine. For each topic, clarify:
   - Is it shallow enough for a single chapter file, or does it warrant a directory with multiple chapters (and possibly sub-chapter groups for the deepest)?
   - What's the expected scope (brief overview vs. deep dive)?
   - Are there known relationships to other topics?
   Depth should follow the material — don't force every topic into the same shape. A topic with one focused question is a single `.md` file; a sprawling topic with three distinct sub-areas becomes a directory with sub-directories.
4. **Conventions** — Ask about:
   - Preferred tone (technical, accessible, mixed)
   - Citation style preferences (inline links, reference sections, both)
   - Any domain-specific terminology conventions
   - Target audience beyond "humans and AI"
5. **Scope boundaries** — What is explicitly *out of scope*?

Build on the user's answers naturally, not as a checklist.

### Phase 1c: Convergence Checkpoint

Before moving on, synthesize and present two things separately:

1. **The research motivation** — the underlying need, independent of this knowledge base.
   Frame it as: "The core need is [X]. Today, people get this information by [Y], which
   falls short because [Z]."

2. **The knowledge base thesis** — how this research project addresses that need.
   Frame it as: "This knowledge base addresses that by [coverage/approach], for [audience],
   enabling [decisions/outcomes it supports]."

Ask: "Does this accurately capture why this research matters and what the knowledge base
needs to achieve?" If the user corrects or nuances either statement, iterate. Do not
proceed to file generation until both statements feel right to the user — you should be
confident you understand what they *actually* need to learn, not just the domain they
initially named.

## Phase 2: File Generation

Once the user confirms the research plan, generate the following files under `research/`.

**Idempotency rule:** Before every Write in this phase, check whether the target path already exists (from the Phase 0 inventory). If it does, skip it and note the skip in the Phase 3 summary. Never overwrite an existing file in this skill — populated files like `INDEX.md` and `DECISIONS.md` may contain user work that this skill has no way to merge safely.

### `research/CLAUDE.md`

This file guides all future research phases. Include:

- Research domain and goals (from discovery)
- Tone and writing conventions
- Citation style and reference format
- Section structure expectations
- Cross-reference conventions: use `[display text](relative-path.md#heading-slug)` relative to `content/`
- Any domain-specific rules discovered during the conversation

References are split between a YAML file and the markdown:

- Each topic `<name>.md` has a sibling `<name>_references.yaml` with full metadata (title, authors, url, isbn, published, last-checked, verified).
- In markdown, each section ends with a `### References` subheading listing short-form entries: `- [citation-key] "Title" ("Takeaway.")`
- In-text citations use `[citation-key]` or `[citation-key, pp. N-M]`.

Example `references.yaml` entry:
```yaml
vaswani-2017:
  title: "Attention Is All You Need"
  authors: Ashish Vaswani, Noam Shazeer, et al.
  url: https://arxiv.org/abs/1706.03762
  published: 2017-06-12
  last-checked: 2026-04-04
  verified: true
```

Example markdown references section:
```markdown
### References

- [vaswani-2017] "Attention Is All You Need" ("Introduced the transformer architecture.")
```

### `research/INDEX.md`

Structure:

```markdown
# <Research Project Title>
<abstract — 2-3 sentences describing the research scope and goals>

## <directory-topic>/
<abstract for this topic group>

### [<directory-topic>/<chapter-file>.md](content/<directory-topic>/<chapter-file>.md)
<1-2 sentence abstract>

## [<single-chapter-topic>.md](content/<single-chapter-topic>.md)
<1-2 sentence abstract>
```

If a topic warrants nested sub-chapter groups during inception, mirror them with deeper headings — `####` for chapters two levels below `content/`, `#####` for three levels, etc.

Rules:
- Directory entries (whether `##` for top-level or deeper for nested groups) group their children and are plain-text path headings (no link — there is no single file to point at)
- Leaf chapter entries carry no status line — chapter status (`stub → inquiry → draft → audited → done`) is *derived* on demand from on-disk signals by the `research-status.sh` helper, never stored in INDEX.md — and use a heading level matching their depth (`##` for a single-chapter top-level topic, `###` for a chapter in a top-level directory, `####` for a chapter one level deeper, …)
- Every leaf chapter heading is a markdown link: the link text is the path relative to `content/`, and the link target is that same path prefixed with `content/` (relative to `INDEX.md`) — e.g. `### [api/rest.md](content/api/rest.md)`. This keeps the path visible as the entry's stable identifier while making the tree navigable and machine-parsable.
- Order topics and chapters logically, not alphabetically
- Every chapter in the tree appears in INDEX.md regardless of depth; sections within a chapter do not

### `research/DECISIONS.md`

```markdown
# Decisions

This log records decisions made during research — source selection, scope exclusions, contradictions resolved, and turning points where conclusions changed.

| ID | Date | Topic | Decision | Rationale |
|----|------|-------|----------|-----------|

## Decision Details

<!-- Entries will be added as:

### DEC-001: <title>
**Date**: YYYY-MM-DD
**Topic**: <topic-file-path>
**Context**: <what prompted this decision>
**Decision**: <what was decided>
**Rationale**: <why>
**Alternatives considered**: <what else was weighed>

-->
```

### `research/glossary.md`

```markdown
---
title: "Glossary"
created: <today>
updated: <today>
---

# Glossary

<!-- Terms are organized by domain area. Each area is a heading.
     Format: **term**: definition
     Add a reference link if the definition comes from an authoritative source. -->
```

Leave the glossary empty — it will be populated during investigation and glossary-sync.

### Chapter files in `research/content/`

For each topic identified during discovery, create chapter stub files at the depths the discussion settled on:

```markdown
---
title: "<Chapter Title>"
created: <today>
updated: <today>
---

# <Chapter Title>
```

Layout rules:
- A single-chapter topic is one `.md` file directly under `content/`.
- A multi-chapter topic is a directory under `content/` containing one `.md` per chapter (and, if the discussion warranted it, sub-directories for chapter groups).
- Nesting can go arbitrarily deep, but only when the material justifies it — don't pre-emptively scaffold sub-directories with one child.

The files are intentionally minimal stubs — the inquiry phase adds section structure.

## Phase 3: Summary

After generating all files, present:
- A tree view of what was created, with skipped (pre-existing) paths marked explicitly
- The full INDEX.md content for review (if it was newly written; otherwise note that the existing INDEX.md was left untouched)
- A reminder that the next step is `/research-inquiry <topic-file>` for each topic

## Git

Do NOT commit. The user will review and use `/commit` when ready.

## Important Principles

- **Motivation before structure.** Users often arrive with a domain in mind but not a clear
  reason the research matters. Your first job is to understand the underlying need independently,
  then validate that the proposed knowledge base is the right response to it. This reframing
  frequently shifts scope, depth, or topic selection in ways the user finds valuable.
- **Scope, not sections.** This phase captures *what* to research and *why*, never *how* to
  structure individual topics. Section outlines and content planning belong in the inquiry phase.
- **Concise over comprehensive.** An INDEX.md that people actually read beats an exhaustive
  taxonomy that nobody navigates. Aim for the smallest set of topics that covers the real need.
- **Dual audience.** Every description should be clear to a human reader AND parseable by an
  AI agent building context about the research. Avoid ambiguity, jargon without definition,
  and vague hand-waving.
- **Socratic, not interrogative.** Frame questions as collaborative exploration. Explain *why*
  you're asking when it's not obvious. Offer your own hypotheses when the user seems stuck —
  "It sounds like this research is mainly to inform a build-vs-buy decision — is that right?"
- **Respect the human's expertise.** They know the domain. You're helping them articulate and
  structure what they already know, and occasionally surfacing blind spots in coverage.
- **No premature commitment.** If the user is unsure about a topic's scope or placement, mark
  it as provisional rather than forcing a decision. The inquiry and restructure phases exist
  precisely for refinement.
- **Stress-test strong framing.** When a user arrives with a confident, pre-formed view of the
  domain — "I already know the topics, just set it up" — that's when Socratic questioning
  matters most. Probe the domain boundaries they've drawn, the exclusions they're making
  (deliberately or by habit), and whether the scope reflects examined choices or inherited
  framing from a single source. This isn't obstruction; it's ensuring the research foundation
  is examined before building on it. Deference to confidence is the opposite of what this
  skill exists to do.

## Important Rules

- Do NOT create a root `CLAUDE.md` — that is out of scope for this skill.
- All paths are relative to the repository root unless stated otherwise.
- Topic filenames use lowercase with hyphens, no numeric prefixes.
- Today's date for frontmatter: use the current date in YYYY-MM-DD format.
