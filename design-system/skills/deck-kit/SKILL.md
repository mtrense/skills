---
name: deck-kit
description: >
  Extend a finished design system with a presentation layer: spec the slide masters into deck-kit/DECKKIT.md (seeded from a bundled standard master catalog, trimmed per FOUNDATION.md), write each theme's deck.css bridge mapping reveal.js's --r-* vars onto the theme's --ds-* tokens, build every master across every theme via slide-smith workers into per-theme sample decks, and gate with deck-check plus a deck-critic rendering pass. Trigger whenever the user wants the design system to cover presentations/slides — "make a deck kit", "add slide masters to the design system", "I want to build presentations in our design language", or /deck-kit. Requires FOUNDATION.md and at least one built theme pair. Re-entrant: with a DECKKIT.md present it revises diff-oriented. Do NOT trigger for building an actual presentation (/deck-build) or for changing an existing master or deck (/deck-revise).
argument-hint: "[optional: which masters or themes to (re)build — default: the full kit]"
model: opus
allowed-tools: Read, Write, Edit, Glob, Grep, Agent, Bash(mkdir -p design-system*), Bash(bash *deck-build/deck-assemble.sh *), Bash(bash *deck-build/deck-check.sh *), Bash(rm -rf design-system/deck-kit/.fragments*)
---

# Deck Kit — The Design System Learns to Present

You extend an existing design system with its presentation layer: `design-system/deck-kit/` — the master spec, one `deck.css` bridge per theme×mode, and per-theme sample decks that are to masters what the kitchen-sinks are to components. Read the deck conventions first (`<skills-root>/deck-kit/references/deck-conventions.md`); they are the contract everything below targets.

## Step 0 — Preflight

Required on disk: `design-system/FOUNDATION.md` and at least one `<theme>-<mode>/` dir with `index.css` + `tokens.md`. Missing → stop and name the phase skill (`/design-foundation`, `/design-themes`). Enumerate the theme dirs. If `deck-kit/DECKKIT.md` already exists you are in **revision mode**: diff-oriented — confirm what changes (masters added/removed/re-specced, themes added), keep the rest untouched, and skip straight to the affected steps.

## Step 1 — Spec the masters (DECKKIT.md)

Seed from the bundled standard catalog (`<skills-root>/deck-kit/references/standard-masters.md`), trimmed per `FOUNDATION.md` (a marketing-leaning foundation earns `quote`/`image-full`; an internal-tooling one maybe not). Present the proposed master list with one-line rationale and interview only the genuinely open calls — which masters exist, the type-ramp base size (projection vs screen-share density, from FOUNDATION.md's density direction), footer furniture (slide numbers, brand mark — a per-master slot, not a runtime feature). Then write `deck-kit/DECKKIT.md`: the machine-readable `## Masters` list plus a section per master (anatomy, content slots, content budget, theme-variance notes) per the conventions.

## Step 2 — Write the bridges

For each theme dir, write `deck-kit/<theme-dir>/deck.css` from the conventions' template: `@import` the theme's `index.css`, map every required `--r-*` onto the theme's `--ds-*` tokens (reading `tokens.md` for what exists — `--ds-font-display` and `--ds-font-mono` get used when present), and set the deck-only decisions (`--r-main-font-size`, `--r-block-margin`) per the Step 1 answers. Never a literal color — the gate verifies contrast through the var chain, so the `on-*` pairing rule from the conventions is binding.

Run `bash <skills-root>/deck-build/deck-check.sh kit design-system` now — mapping/contrast FAILs are cheapest to fix before any markup exists. Sample-deck MISS lines are expected.

## Step 3 — Build the masters

The worklist is derived, never remembered: the union of `bash <skills-root>/deck-build/deck-assemble.sh missing-masters design-system <theme-dir>` across theme dirs, in `## Masters` order. In batches of 4, spawn **slide-smith** subagents (`subagent_type: slide-smith`) in parallel in a single message — MASTER mode, one per master, each given: the slug, the `DECKKIT.md` path, the conventions path, all theme dirs, and the fragments dir (`design-system/deck-kit/.fragments/`). One smith owns one master across ALL themes — that keeps the DOM identical.

After each batch: `deck-assemble.sh assemble-sample design-system <theme-dir>` for every theme, then `deck-check.sh kit design-system`. Master-attributable FAILs (unbalanced markers, physical classes, missing anchor) → respawn that one smith **once** with the FAIL lines quoted; still failing → park it and surface at the end. Mapping FAILs are yours (Step 2), token FAILs belong to `/design-themes` / `/design-revise` — report, don't fix.

## Step 4 — Critic close-out

When no MISS remains, spawn one **deck-critic** subagent (`subagent_type: deck-critic`) with kit scope (all themes). Present findings severity-ranked; for approved fixes run targeted smith rounds and re-assemble + re-check. The human decides when it's good. Then `rm -rf design-system/deck-kit/.fragments` — the sample decks are the source of truth; `deck-assemble.sh` re-extracts blocks from them.

## When you are done

Report: the master list, per-theme bridge + sample status, the check summary line, the critic verdict, and anything parked. Point the human at `deck-kit/sample/<theme-dir>.html` to browse, and at `/deck-build` to make an actual presentation. Defer the commit to `/commit`.
