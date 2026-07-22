---
name: design-foundation
description: >
  Start a new design system: distill the given design references and run a Socratic dialog to a shared design brief. Trigger whenever the user wants to start, found, or bootstrap a design system, define its visual direction, or distill design references into a brief — e.g. "let's build a design system", "start the design foundation", "here are some sites/mocks I like, turn them into a design direction", or /design-foundation. Accepts references as live site URLs, local images/exports (screenshots, Figma or Claude Design exports, product mocks), and named design systems ("like shadcn"); fans a reference-analyst subagent out per reference and persists the digests as references.md, then interviews the human one topic at a time — personality, color, type, density, accessibility and i18n baselines, theme axes, component catalog trim — offering /design-prototype loops whenever looking beats talking. Writes design-system/FOUNDATION.md and stops there: themes (/design-themes) and components (/design-components) are deliberately separate phases. Do NOT trigger for one-off page styling, for prototyping alone (that is /design-prototype), or when a FOUNDATION.md already exists and the user wants to change it (revise it in dialog, don't re-found).
argument-hint: "[references — URLs, image/file paths, named systems — and/or a one-line design intent]"
model: opus
allowed-tools: Read, Write, Edit, Glob, Agent, Skill, Bash(mkdir -p design-system*)
---

# Design Foundation — From References to a Brief

You take a pile of design references plus a Socratic dialog and produce the **design brief**: `design-system/FOUNDATION.md`, the referent every later phase (`/design-themes`, `/design-components`, `/design-build`) grounds in. You also persist the distilled references as `design-system/references.md` so later entry points (`/design-add-theme`, `/design-revise`) can reuse them without re-analyzing.

This is phase 1 of the design-system workflow. You produce the brief and **stop** — no tokens, no components, no HTML. The conventions everything targets live in the bundled conventions doc: `<skills-root>/design-audit/references/conventions.md` — read it once so the brief you write is buildable.

If `design-system/FOUNDATION.md` already exists, this run is a **revision**: read it, take the requested change through the same dialog discipline (below), and edit — don't re-found from scratch. New references in a revision still go through Step 1 and get appended to `references.md`.

## Step 0 — Collect the inputs

From `$ARGUMENTS` and the conversation, gather:

- **References** — any mix of: live URLs, local file paths (images, HTML/design exports), named design systems ("Vercel-ish", "like shadcn"). Unlike an exemplar intake, live URLs are fine here — you distill direction from them, you don't pin bytes.
- **The design intent** — one or two lines: what product(s) this system will serve and the feel it should have.

If there are no references at all, say the dialog can carry it alone but ask once whether any exist — a single screenshot beats three interview rounds. If the intent is missing, ask for it; nothing else proceeds without it.

## Step 1 — Distill the references (subagents)

Spawn one **reference-analyst** subagent (`subagent_type: reference-analyst`) per reference, **all in parallel in a single message**, each given its reference, the design intent, and any stated focus. Each returns a digest; the raw pages/screenshots stay in the subagents.

`mkdir -p design-system`, then write `design-system/references.md`: a heading per reference (source, date analyzed) with its digest verbatim, and a short **Synthesis** section you write yourself — where the references agree (that's the gravitational center), where they conflict (open questions for Step 2), and what none of them cover. On a revision, append new digests and update the synthesis.

Present the human the synthesis, not the digests.

## Step 2 — The Socratic dialog

Work the agenda below **one topic at a time**: state what the references and intent already imply (with source), propose a concrete default, ask only what's genuinely open. Never a questionnaire dump; never re-ask what a reference settles unless the human contradicts it.

1. **Personality** — 3–5 adjectives the system must live up to, and 1–2 it must avoid. These become the visual-critic's rubric, so make them falsifiable ("calm, dense, editorial" — not "clean, modern").
2. **Audience & density** — who uses the products, on what devices; information density (comfortable/dense/both as variants).
3. **Color direction** — neutral temperature, brand color role and weight, how loud status colors may be. Direction, not hex — tokens are `/design-themes`' job.
4. **Typography direction** — sans/serif/mono roles, scale feel, weight discipline; note licensing constraints (system stacks vs webfonts).
5. **Shape, depth, motion** — radius language, border-vs-shadow reliance, elevation levels, motion appetite (the components are static, but the brief records intent).
6. **Accessibility baseline** — WCAG 2.2 AA is the floor (per conventions); ask only whether anything demands more (AAA text contrast, larger targets).
7. **i18n baseline** — confirm the conventions' defaults (RTL-safe markup, long-string samples, locale-format slots) and settle what's project-specific: target scripts (drives font-stack coverage), expected worst-case text expansion.
8. **Theme axes** — which themes are anticipated and *why each earns existence* (default + high-contrast? brand A + brand B?). Names and one-line intents only; light+dark per theme is a given.
9. **Catalog trim** — walk the group headings of the bundled standard catalog (`<skills-root>/design-components/references/standard-catalog.md`), asking which groups the products actually need, and capture needed components it doesn't cover. Record the trim as a list of included slugs + additions; the per-component specs are `/design-components`' job.

**Prototype instead of debating.** Whenever a topic stalls on words — two color temperatures both sound right, the type scale is abstract — offer to settle it by eye: invoke `Skill(design-prototype)` with the competing directions; it renders disposable side-by-side samples, the human points, you record the verdict and move on.

## Step 3 — Write FOUNDATION.md

Write `design-system/FOUNDATION.md`:

```markdown
# Design Foundation

## Intent            # the product(s) and the one-line feel
## Personality       # the adjectives, must-avoid list
## References        # 2–3 line pointer into references.md: what was taken from where
## Color direction
## Typography direction
## Shape, depth & motion
## Density
## Accessibility baseline   # the floor + anything above it
## i18n baseline            # scripts, RTL, expansion, locale slots
## Themes                   # each anticipated theme: name + one-line intent
## Catalog                  # included component slugs + project-specific additions (spec deferred to COMPONENTS.md)
## Open questions           # anything deliberately deferred
```

Every section states decisions, each traceable to a reference, a dialog answer, or a prototype verdict — no unsourced taste. Keep it tight (one page-ish): this file is loaded by every later phase.

## When you are done

Report the brief in three sentences (personality, themes anticipated, catalog size) and hand off: `/design-themes` turns the theme axes into token sets, then `/design-components` specs the catalog, then `/design-build` builds the kitchen-sinks. Defer any commit to `/commit`. Do not start the next phase yourself.
