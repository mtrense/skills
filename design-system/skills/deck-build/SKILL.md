---
name: deck-build
description: >
  Build a presentation in the design system's language: draft or resume a deck's OUTLINE.md (title, target theme, slide list where every slide instantiates a deck-kit master, per-slide content), confirm it with the human, then fan slide-smith workers out one-per-slide, assemble the reveal.js deck deterministically, gate with deck-check, and close with a deck-critic rendering pass. Trigger whenever the user wants an actual slide deck/presentation built from the design system — "build a deck about the Q3 results", "make a presentation from these notes in our design language", "turn this doc into slides", or /deck-build. Requires a built deck kit (deck-kit/DECKKIT.md + sample decks — /deck-kit). Resumable and idempotent — the worklist is re-derived from the marker blocks each pass. Do NOT trigger for creating the kit itself (/deck-kit), for changing an existing deck (/deck-revise), or for a Deckset presentation (/deckset).
argument-hint: "<deck dir to resume | title/topic + source material for a new deck> [@<workers>] (default @4)"
model: opus
allowed-tools: Read, Write, Edit, Glob, Grep, Agent, Bash(mkdir -p *), Bash(ls *), Bash(bash *deck-build/deck-assemble.sh *), Bash(bash *deck-build/deck-check.sh *), Bash(rm -rf *.fragments*), Bash(open *)
---

# Deck Build — From Outline to Projection

You build **one deck** — a directory with an `OUTLINE.md` spec and an assembled reveal.js `index.html` — out of the deck kit's masters. You hold the outline and reports; slide markup lives in the **slide-smith** workers and the fragments. Read the deck conventions first (`<skills-root>/deck-kit/references/deck-conventions.md`).

## Invariants

- **The outline leads the markup.** Every structural change flows `OUTLINE.md` → rebuild, never the other way. Slide content comes from the outline; smiths never invent it.
- **Workers write only fragments; only `deck-assemble.sh` writes the page.**
- **The worklist is derived** from `deck-assemble.sh missing-slides` each pass — resumable and idempotent.

## Step 0 — Preflight & argument

Parse `$ARGUMENTS`: a path whose dir contains an `OUTLINE.md` → **resume mode** (skip to Step 2); otherwise it's the title/topic (plus any source-material paths) for a **new deck**. `@<workers>` caps parallel smiths (default 4). Verify the kit: `deck-kit/DECKKIT.md` exists and `bash <skills-root>/deck-build/deck-check.sh kit design-system` has no FAIL — otherwise stop and route to `/deck-kit`.

## Step 1 — The outline (new deck)

Interview briefly — this is scoping, not Socratic design: working title; **target theme×mode** (list the dirs that have a `deck.css`; one per deck — the sibling mode is a separate build); audience and duration (a rough slide budget: ~1–2 slides/minute); the source material (paths — read it; for a large corpus delegate the read to a `general-purpose` subagent that returns a per-topic digest, keeping the material out of your context); deck location (default `presentations/<slug>/` at the project root, `ds:` frontmatter set to the relative path back to `design-system/`).

Draft `OUTLINE.md` per the conventions: frontmatter (`title`, `theme`, `ds`, `lang`/`dir` if not en/ltr), the `## Slides` list — every slide `` - `NN-slug` [master] — one-liner `` citing a real master, numbered in tens-friendly order (`01`, `02`, …) — and a `## NN-slug` content section per slide: exact headline, body content distilled from the sources, asset paths (copy assets into `assets/`), and the talk track destined for speaker notes. Respect each master's content budget when distilling — split at the outline level, not in markup.

**Present the outline to the human and get approval before building.** The slide list + one-liners is the review surface; adjust until it's their talk.

## Step 2 — Burn down the slides

Worklist: `bash <skills-root>/deck-build/deck-assemble.sh missing-slides <deck-dir>` (each line `slug master`). In batches of `workers`, spawn **slide-smith** subagents (`subagent_type: slide-smith`) in parallel in a single message — SLIDE mode, one per slide, each given: the slug, the master's DOM source (`deck-assemble.sh master-block design-system <theme-dir> <master>` — you fetch it, the smith gets the block), that slide's `## NN-slug` outline section, the conventions path, the assets listing, and the deck's fragments dir. Distinct slugs write distinct fragment files — no collisions.

Collect reports. **Overflow flags** (content busting a master's budget with a proposed split) go to the human: accepted splits are outline edits (renumber, add the new slide) and the new slugs join the next worklist pass.

## Step 3 — Assemble & gate

After each batch: `bash <skills-root>/deck-build/deck-assemble.sh assemble <deck-dir>`, then `bash <skills-root>/deck-build/deck-check.sh deck <deck-dir>`. Slide-attributable FAILs → respawn that one smith **once** with the FAIL lines quoted; still failing → park it. Kit-attributable FAILs (bridge mappings, master problems) are not yours — report toward `/deck-kit`. Loop Steps 2–3 until `missing-slides` is empty.

## Step 4 — Critic close-out

Spawn one **deck-critic** subagent (`subagent_type: deck-critic`) with deck scope. Present findings severity-ranked; approved fixes are either outline edits (density/split findings → Step 1 surface, then targeted smiths) or targeted smith respawns (visual findings), then re-assemble + re-check. Delete the intermediates (`rm -rf <deck-dir>/.fragments`) and offer to `open <deck-dir>/index.html`.

## When you are done

Report: the deck path, slide count, the check summary line, the critic verdict, parked slides, and any kit findings routed to `/deck-kit`. Defer the commit to `/commit`.
