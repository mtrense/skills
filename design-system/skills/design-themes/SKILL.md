---
name: design-themes
description: >
  Turn the design foundation's theme axes into concrete themes: for each theme a complete light+dark token pair (colors, fonts, radii, shadows) as CSS custom properties, refined Socratically with disposable prototypes and gated by WCAG contrast math. Trigger after /design-foundation whenever the user wants to define, design, or rework the design system's themes or tokens — e.g. "let's do the themes", "define the tokens", "design the dark mode", "add tokens for the high-contrast theme", or /design-themes. Requires design-system/FOUNDATION.md. Seeds each theme via the theme-drafter subagent (every token filled in, contrast pre-checked, choices tagged grounded vs invented), interviews one open choice at a time with /design-prototype loops, then writes THEMES.md plus each <theme>-<light|dark>/ directory's index.css and tokens.md and runs the deterministic check. Re-entrant: with themes already on disk it revises them diff-oriented. Do NOT trigger for adding a whole new theme to a finished system (/design-add-theme) or for small token tweaks to one existing theme (/design-revise).
argument-hint: "[which theme(s) to work on — default: every theme FOUNDATION.md anticipates]"
model: opus
allowed-tools: Read, Write, Edit, Glob, Agent, Skill, Bash(mkdir -p design-system*), Bash(bash *design-audit/design-check.sh *)
---

# Design Themes — From Direction to Tokens

You are phase 2: you turn `FOUNDATION.md`'s theme axes into **concrete token sets** — for each theme a light+dark pair of `--ds-*` CSS custom properties — and the `THEMES.md` narrative. No components yet; the kitchen-sinks are `/design-build`'s job.

**Preflight:** `design-system/FOUNDATION.md` must exist — without it, stop and point at `/design-foundation`. Read it and the token conventions (`<skills-root>/design-audit/references/conventions.md`); both are binding — required roles, naming, hex-for-colors, the 4.5:1 on/base contract, dark-as-designed-not-inverted.

If theme directories already exist, this is a **revision**: work only the themes `$ARGUMENTS` names (or the human picks), pass the drafter the existing files, and interview only the diff.

## Step 1 — Seed each theme (subagent)

For each theme to work on (from `$ARGUMENTS`, else FOUNDATION.md's **Themes** section), spawn a **theme-drafter** subagent (`subagent_type: theme-drafter`) — in parallel when there are several — with: the theme intent line, the design-system dir, the conventions path, and (for second and later themes) the sibling themes' `tokens.md` paths so the family stays coherent.

Each returns a complete strawman: full light+dark token set, self-computed contrast table, font stacks with script coverage, and annotations split **grounded** vs **invented**.

## Step 2 — Refine Socratically, prototype-first

Per theme, show the human the strawman's gestalt first — but for tokens the gestalt is visual, so lead with the eye: invoke `Skill(design-prototype)` with the drafted token set (both modes) so the human reacts to rendered swatches, type, and sample components rather than a hex table.

Then work the **invented** annotations one at a time: what the drafter chose, why, the alternatives; the human picks or corrects. Grounded values need no interview — but if the human contradicts one, name the source (FOUNDATION.md line or reference) and resolve it consciously: either the token yields or the foundation is revised (`/design-foundation` revision), never a silent divergence. When two candidate values compete, prototype them side by side instead of debating.

Contrast is non-negotiable: any human choice that breaks an on/base pair below 4.5:1 gets said out loud and adjusted (nudge the value, or the human explicitly accepts a different pairing — never a silently failing pair).

## Step 3 — Write

For each settled theme (slug from the drafter, confirmed by the human):

1. `mkdir -p design-system/<slug>-light design-system/<slug>-dark`.
2. Write each mode's `index.css`: `:root { --ds-* }` with the settled values, plus the conventions' base-styles block (`body { background/color/font-family via vars }`) and any genuinely global CSS the theme needs. Nothing else.
3. Write each mode's `tokens.md`: the token table (name, value, usage note), the font stacks with script-coverage rationale, and icon direction (which icon set/style the theme intends).
4. Update `design-system/THEMES.md` (create with `# Themes` if missing): one section per theme — intent, personality line, the key token decisions *with rationale* (why this neutral temperature, why this radius), light/dark relationship, links to the two directories.

Then run the gate: `bash <skills-root>/design-audit/design-check.sh design-system <slug>-light <slug>-dark`. Token-level FAILs (missing roles, contrast) are yours to fix now; MISS lines about index.html are expected — nothing is assembled yet.

## When you are done

Report per theme: slug, both dirs written, contrast summary (all pairs passing, tightest ratio). Hand off to `/design-components` (spec the catalog) → `/design-build` (build the kitchen-sinks). If this was a revision of themes that already have assembled kitchen-sinks, note that pure value changes propagate through the CSS vars automatically, but renamed/removed tokens need a `/design-revise` pass over the components. Defer any commit to `/commit`.
