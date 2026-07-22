---
name: design-add-component
description: >
  Add one new component to a finished design system: spec it Socratically (seeded from the standard catalog when it's a known pattern), append it to COMPONENTS.md's catalog and sections, build it across every theme via a component-smith worker, re-assemble the kitchen-sinks, and gate with the deterministic check plus a scoped visual-critic pass. Trigger whenever the user wants a component added to an existing design system — "add a date-picker to the design system", "we need a stepper component", "the system is missing a file-upload", or /design-add-component. Requires FOUNDATION.md, THEMES.md, and COMPONENTS.md to exist. Do NOT trigger during the initial catalog phase (/design-components) or for changing an existing component (/design-revise).
argument-hint: "<component name/slug> [what it's for]"
model: opus
allowed-tools: Read, Write, Edit, Glob, Agent, Bash(bash *design-build/assemble.sh *), Bash(bash *design-audit/design-check.sh *), Bash(rm -rf design-system/.fragments*)
---

# Design Add-Component — Grow the Catalog

The out-of-band entry point for one new component after the system is built. Same contract as the phase skills, scoped to a single slug.

**Preflight:** `design-system/FOUNDATION.md`, `THEMES.md`, and `COMPONENTS.md` must exist — otherwise route to the missing phase skill and stop. Read the conventions (`<skills-root>/design-audit/references/conventions.md`) and check the component isn't already in the catalog (then this is `/design-revise`'s job — say so and stop).

## Step 1 — Spec it

Draft the component's section yourself: if the standard catalog (`<skills-root>/design-components/references/standard-catalog.md`) covers it, instantiate that entry adapted to FOUNDATION.md; otherwise first-cut it from the foundation and the stated purpose. Same section shape as every other component: slug, anatomy (shared DOM), variants, states, accessibility, i18n, theme variance.

Walk the open calls with the human one at a time — variants, states, the theme-variance opportunity — exactly as `/design-components` would. Then edit `COMPONENTS.md`: the `- \`slug\` — one-liner` catalog line at its right position in kitchen-sink order, plus the section.

## Step 2 — Build it

Spawn one **component-smith** subagent (`subagent_type: component-smith`) with the slug, the `COMPONENTS.md` path, the conventions path, every theme dir, and the fragments dir. It writes the fragments; you never see the markup.

## Step 3 — Assemble & gate

1. `bash <skills-root>/design-build/assemble.sh assemble design-system <theme-dir>` for each theme dir (the new block lands at its catalog position), then `… index design-system` if theme dirs changed (they didn't — skip).
2. `bash <skills-root>/design-audit/design-check.sh design-system`. FAILs on the new slug → respawn the smith once with the FAIL lines; still failing → surface to the human.
3. Spawn **visual-critic** (`subagent_type: visual-critic`) scoped to the new slug across all themes; present findings, apply approved fixes via another targeted smith round.
4. `rm -rf design-system/.fragments`.

## When you are done

Report: the slug, its catalog position, per-theme variance notes from the smith, gate summary, critic verdict. Defer the commit to `/commit`.
