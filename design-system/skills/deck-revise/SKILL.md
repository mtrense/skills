---
name: deck-revise
description: >
  Revise the design system's presentation layer along any of three axes: the content/order of one existing deck (OUTLINE.md updated first, then targeted slide-smith rebuilds of exactly the changed slides), the structure of one deck-kit master (DECKKIT.md updated first, rebuilt across every theme's sample deck, with re-instantiation offered for the decks that use it), or a theme's deck.css bridge (value-only remaps propagate free through the CSS vars). Trigger whenever the user wants to change something that already exists in the deck layer — "redo slide 4", "drop the agenda slide", "the quote master needs an attribution line", "make the deck type ramp bigger", or /deck-revise. Always ends with the deterministic deck-check and a scoped deck-critic pass. Do NOT trigger for building a new deck (/deck-build), for creating or wholesale re-speccing the kit (/deck-kit), or for changing the design system's tokens themselves (/design-revise — deck.css inherits those for free).
argument-hint: "<deck dir | master slug | theme-dir bridge> — <what to change>"
model: opus
allowed-tools: Read, Write, Edit, Glob, Grep, Agent, Bash(bash *deck-build/deck-assemble.sh *), Bash(bash *deck-build/deck-check.sh *), Bash(rm -rf *.fragments*), Bash(open *)
---

# Deck Revise — Change What Exists

One skill, three axes. Establish from `$ARGUMENTS` which one: the target is a **deck** (a dir with an `OUTLINE.md`), a **master** (a `DECKKIT.md` `## Masters` slug), or a **bridge** (a theme-dir's `deck.css`). Ambiguous or neither → ask one question. Read the conventions (`<skills-root>/deck-kit/references/deck-conventions.md`) either way.

**The drift check applies on every axis:** a change that contradicts `FOUNDATION.md` or a master's DECKKIT.md spec is named before it's encoded — the human narrows the change or consciously revises the upstream spec first, never a silent divergence. And the spec leads the markup: `OUTLINE.md`/`DECKKIT.md` are edited before any fragment is built.

## Axis 1 — A deck's content or order

1. Edit `OUTLINE.md` first: content changes in the `## NN-slug` sections; adds/removes/reorders/splits in the `## Slides` list (order in the list IS the deck order; a removed slide's block disappears at assembly because it's no longer listed — also delete its `## NN-slug` section).
2. Pure reorders/removals need no smith: re-run `deck-assemble.sh assemble <deck-dir>` and existing blocks are carried into the new order. Changed or added slides: spawn one **slide-smith** (`subagent_type: slide-smith`, SLIDE mode) per affected slug — master block fetched via `deck-assemble.sh master-block`, the updated outline section as content.
3. `deck-assemble.sh assemble`, then `deck-check.sh deck <deck-dir>`; one respawn on slide-attributable FAILs.

## Axis 2 — A master's structure

1. Update the master's section in `DECKKIT.md` (anatomy, slots, budget). Adding/removing a master is `/deck-kit` revision territory — route there if the list itself changes.
2. Rebuild it everywhere: one **slide-smith** (MASTER mode) for the slug across ALL theme dirs, then `deck-assemble.sh assemble-sample` per theme and `deck-check.sh kit design-system`.
3. **Built decks don't auto-follow** — they instantiated the old DOM. Ask the human which deck dirs exist (or glob `**/OUTLINE.md`), list the decks whose outlines use this master, and offer re-instantiation: per accepted deck, targeted SLIDE-mode smiths for the affected slugs + re-assemble + `deck-check.sh deck`. A declined deck is named in the report as intentionally stale.

## Axis 3 — A bridge (deck.css)

Value-only changes — a different `--ds-*` token behind `--r-heading-color`, a new `--r-main-font-size`, print rules — are edits to `deck-kit/<theme-dir>/deck.css` alone; every sample and deck picks them up through the var chain with zero regeneration. Then `deck-check.sh kit design-system <theme-dir>` (the contrast re-verification through the var chain is the point). Changes that belong to the design system's tokens themselves (the color's actual value) are `/design-revise` — route, don't duplicate.

## Close-out

Whatever the axis: spawn one **deck-critic** (`subagent_type: deck-critic`) scoped to what changed (the deck, or kit scope limited to the affected themes), present findings severity-ranked, apply approved fixes via targeted smiths, and clean up any `.fragments`. Report what changed, the check summary line, the critic verdict, and any decks left intentionally stale. Defer the commit to `/commit`.
