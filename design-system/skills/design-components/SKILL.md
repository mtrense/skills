---
name: design-components
description: >
  Spec the design system's component catalog: settle which components exist and, per component, the shared anatomy (one DOM for all themes), variants, states, accessibility contract, i18n slots, and what themes may vary — written to design-system/COMPONENTS.md with its machine-readable ## Catalog list. Trigger after /design-themes whenever the user wants to define, spec, or restructure the component set — e.g. "let's spec the components", "define the component catalog", "what components do we need", or /design-components. Requires FOUNDATION.md (uses its Catalog trim); seeds from the bundled standard catalog, walks only the genuinely open decisions with the human, and writes the spec — no HTML: building the kitchen-sinks is /design-build's job. Re-entrant: revises an existing COMPONENTS.md diff-oriented. Do NOT trigger for adding one component to a finished system (/design-add-component) or for changing a built component (/design-revise).
argument-hint: "[optional: which components to (re)spec — default: the full catalog from FOUNDATION.md]"
model: opus
allowed-tools: Read, Write, Edit, Glob
---

# Design Components — Spec the Catalog

You are phase 3: you turn FOUNDATION.md's catalog trim into `design-system/COMPONENTS.md` — the **structural spec** that `/design-build`'s workers implement and `design-check.sh` audits against. Spec only; you write no HTML.

**Preflight:** `design-system/FOUNDATION.md` must exist (stop and point at `/design-foundation` otherwise); read it, the bundled standard catalog (`references/standard-catalog.md` beside this skill), and the conventions (`<skills-root>/design-audit/references/conventions.md`) — the catalog grammar, marker contract, and required sample set constrain what you write. `THEMES.md` should exist too; if it doesn't, warn that theme-variance notes will be guesswork but proceed if the human wants.

If `COMPONENTS.md` already exists, this is a **revision**: work only the components `$ARGUMENTS` names, and warn that changing the spec of an already-built component obligates a `/design-revise` pass.

## Step 1 — Draft the whole spec

Build the full `COMPONENTS.md` draft yourself in one pass — no subagent needed; the standard catalog is the seed:

- Start from FOUNDATION.md's **Catalog** section (the included slugs + additions). For standard components, instantiate the standard-catalog entry, adapted to the foundation (a "calm, editorial" system needs fewer button variants than an ops console).
- For project-specific additions, draft a first-cut spec from the foundation and the products named in the intent.
- Order the `## Catalog` list in kitchen-sink order (the standard catalog's grouping is a good default).

Per component section:

```markdown
## <Name>

- **Slug**: `<slug>`
- **Anatomy**: the shared DOM in one short indented sketch — elements, nesting, where label/help/error/icon live. One structure for all themes.
- **Variants**:
  - `<variant-slug>` — when-to-use one-liner. (Exact grammar, two-space indent — `design-check.sh` parses this list and verifies each variant ships a `data-ds-story="variant-<slug>"` sample in every theme.)
- **States**: which of default/hover/focus-visible/disabled/invalid/loading apply.
- **Accessibility**: roles/ARIA wiring, keyboard expectations, labeling rules.
- **i18n**: which parts are locale-formatted slots (data-ds-locale), expected text-expansion behavior (wrap vs truncate), RTL notes beyond the default mirroring.
- **Theme variance**: what themes may legitimately vary (density, columns, emphasis) vs what is fixed.
```

## Step 2 — Walk the open decisions

Don't interview all ~25 components — present the draft's shape (catalog list + one example section) and walk **only the genuinely open calls**, one at a time:

- Variant sets that depend on product reality (does anything need a destructive button? how many table densities?).
- The project-specific additions — these get a real per-section dialog since no standard entry backs them.
- Anywhere the foundation and the standard catalog pull apart.
- Theme-variance opportunities worth designing (the list-as-rows-vs-columns kind) — each one named per component, since it's what makes multiple themes worth having.

Adjust the draft as decisions land. Cutting a component is always on the table — every entry is markup someone maintains.

## Step 3 — Write

Write `design-system/COMPONENTS.md`: intro line, `## Catalog` (exact grammar: `- \`slug\` — one-liner`, kitchen-sink order), then the per-component sections. Update FOUNDATION.md's Catalog section if the dialog changed the set (one-line edit, not a rewrite).

## When you are done

Report: catalog size, the components with notable theme variance, anything deferred. Hand off to `/design-build` to produce the kitchen-sinks. Defer any commit to `/commit`.
