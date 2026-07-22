---
name: design-revise
description: >
  Revise a finished design system along either axis: the tokens of one existing theme (rebrand, contrast fix, font swap — pure value changes propagate through the CSS vars automatically; renamed/removed tokens trigger a targeted component pass) or the structure of one existing component (anatomy, variants, samples — spec updated in COMPONENTS.md, then rebuilt across every theme by a component-smith reusing the settled DOM decisions). Trigger whenever the user wants to change something that already exists in the design system — "darken the primary in aurora", "fix the contrast warnings in slate-dark", "the table needs a compact variant", "rework the card component", or /design-revise. Always ends with the deterministic check and a scoped visual-critic pass. Do NOT trigger for new components (/design-add-component), new themes (/design-add-theme), or direction-level rework of the whole brief or theme family (/design-foundation, /design-themes revisions).
argument-hint: "<theme-slug | component-slug> — <what to change>"
model: opus
allowed-tools: Read, Write, Edit, Glob, Grep, Agent, Skill, Bash(bash *design-build/assemble.sh *), Bash(bash *design-audit/design-check.sh *), Bash(rm -rf design-system/.fragments*)
---

# Design Revise — Change What Exists

One skill, two axes. Establish from `$ARGUMENTS` which one: the target names a **theme** (matches a `<slug>-light`/`-dark` pair) or a **component** (matches a catalog slug). Ambiguous or neither → ask one question. Read the conventions (`<skills-root>/design-audit/references/conventions.md`) either way.

**Foundation drift check (both axes):** if the requested change contradicts FOUNDATION.md (a "calm" system asked for a neon primary), name the contradiction before encoding it — the human either narrows the change or consciously revises the foundation (`/design-foundation` revision) first. Never silently diverge the system from its brief.

## Axis A — Theme tokens

1. **Interview the change.** Read the theme's `tokens.md` + `index.css` (both modes). Settle the exact token deltas with the human — offer `Skill(design-prototype)` when candidate values compete. Contrast stays non-negotiable: recompute affected on/base pairs as you go.
2. **Classify the delta:**
   - **Value-only changes** (same token names, new values) — edit `index.css` + `tokens.md` in both affected modes; the kitchen-sinks pick the change up through the vars with zero markup edits. This is the cheap, common case.
   - **Structural changes** (token renamed, removed, or newly required by the change) — additionally `grep` the theme's `index.html` for the old var name; every component referencing it needs a smith pass: spawn **component-smith** for those slugs (all themes as targets if the token structure changed family-wide, else just this theme's pair with a sibling `index.html` as existing-DOM source), then `assemble.sh assemble` the affected dirs.
3. Update the theme's section in `THEMES.md` where the rationale changed.

## Axis B — Component structure

1. **Interview against the spec.** Read the component's `COMPONENTS.md` section. Settle the change — new variant, changed anatomy, sample fix — and edit the section (and its catalog one-liner if the summary shifted). The spec stays the single structural truth; markup never leads it.
2. **Rebuild.** Spawn one **component-smith** with the slug, updated `COMPONENTS.md`, the conventions path, **all** theme dirs, the fragments dir, and — when the change is additive rather than a re-anatomy — an existing block as DOM source so settled decisions survive. Then `assemble.sh assemble` every theme dir.

## Close-out (both axes)

`bash <skills-root>/design-audit/design-check.sh design-system` — FAILs introduced by the revision get one smith/token fix round, then surface. Spawn **visual-critic** scoped to the change (the theme pair, or the slug across themes); present findings, apply approved fixes, `rm -rf design-system/.fragments`.

## When you are done

Report: axis, what changed (tokens with old→new values, or the spec delta), which files were touched vs propagated-for-free via vars, gate summary, critic verdict. Defer the commit to `/commit`.
