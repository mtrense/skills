---
name: design-add-theme
description: >
  Add one new theme (a light+dark pair) to a finished design system: optionally distill fresh references, seed a complete token strawman via the theme-drafter subagent (kept a deliberate sibling of the existing themes), refine Socratically with prototype loops, write the two theme directories, then rebuild every catalog component for the new theme with component-smith workers that reuse the existing DOM verbatim — only classes change. Trigger whenever the user wants a whole new theme over the existing component set — "add a high-contrast theme", "we need a second brand theme", "derive a theme from this reference", or /design-add-theme. Requires FOUNDATION.md, THEMES.md, COMPONENTS.md, and built kitchen-sinks. Do NOT trigger for the initial theme phase (/design-themes) or for tweaking an existing theme's tokens (/design-revise).
argument-hint: "<theme name/intent> [new references — URLs, files, named systems]"
model: opus
allowed-tools: Read, Write, Edit, Glob, Agent, Skill, Bash(mkdir -p design-system*), Bash(bash *design-build/assemble.sh *), Bash(bash *design-audit/design-check.sh *), Bash(rm -rf design-system/.fragments*)
---

# Design Add-Theme — Grow the Family

The out-of-band entry point for a whole new theme after the system is built. The existing kitchen-sinks define the DOM; the new theme reskins it.

**Preflight:** `design-system/` must have FOUNDATION.md, THEMES.md, COMPONENTS.md, and at least one assembled theme (a `*-light/index.html` with component blocks) — the assembled blocks are the DOM source the new theme copies. Missing pieces → route to the owning phase skill and stop. Read the conventions (`<skills-root>/design-audit/references/conventions.md`).

## Step 1 — References (optional)

If `$ARGUMENTS` brings new references, run them through **reference-analyst** subagents in parallel (as `/design-foundation` does) and append the digests + an updated synthesis note to `design-system/references.md`. If the new theme contradicts FOUNDATION.md's personality, surface that: either the theme is out of scope or the foundation gets a conscious revision first.

## Step 2 — Draft & refine the tokens

Spawn **theme-drafter** (`subagent_type: theme-drafter`) with the theme intent, the design-system dir, the conventions path, and **all sibling `tokens.md` paths** — the sibling constraint (shared bones, articulated divergence) is the whole point of this skill. Refine exactly as `/design-themes` does: gestalt first via `Skill(design-prototype)`, then the invented annotations one at a time, contrast non-negotiable.

Write `<slug>-light/` and `<slug>-dark/` (`index.css` + `tokens.md`), append the theme's section to `THEMES.md`, and add the theme to FOUNDATION.md's Themes list. Run `design-check.sh` on the two new dirs (MISS on index.html expected).

## Step 3 — Reskin the catalog

In batches of ~4, spawn **component-smith** subagents in parallel — one per catalog slug (`bash <skills-root>/design-build/assemble.sh catalog design-system`) — each given: the slug, `COMPONENTS.md`, the conventions path, **only the two new theme dirs** as targets, the fragments dir, and as **existing-DOM source** an assembled sibling's `index.html`. The smith reuses that DOM verbatim and restyles; passing the DOM source is what keeps the family structurally identical.

After each batch: `assemble.sh assemble` for the two new dirs. When all slugs are done: `assemble.sh index design-system`, full `design-check.sh`, then a **visual-critic** pass scoped to the new theme (its rubric includes cross-theme identity — do the siblings read as a family?). Approved fixes → targeted smith rounds. Then `rm -rf design-system/.fragments`.

This step is resumable: re-derive remaining slugs from `assemble.sh missing design-system <new-theme-dir>`.

## When you are done

Report: the new slug, both dirs, contrast summary, components reskinned, critic verdict on family resemblance. Defer the commit to `/commit`.
