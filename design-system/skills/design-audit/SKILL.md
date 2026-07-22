---
name: design-audit
description: >
  The design system's standing drift gate: run the deterministic design-check over every theme (WCAG contrast on token pairs, required roles, marker integrity against the catalog, RTL/long-string/ARIA/focus samples, data-ds-story marker coverage against the spec's variant lists, logical-class discipline) plus a visual-critic rendering pass, and present one severity-ranked report with each finding routed to the entry point that fixes it. Trigger whenever the user wants the design system checked, audited, validated, or suspects drift — "audit the design system", "is the design system still consistent", "check contrast", "someone hand-edited the kitchen-sink, verify it", or /design-audit. Read-only: reports and routes, never fixes. Do NOT trigger mid-build (the /design-build cycle runs its own gate) or for auditing a single fresh change the invoking skill already gated.
argument-hint: "[optional scope: theme dir(s) or component slug(s); default: everything]"
model: sonnet
allowed-tools: Read, Glob, Grep, Agent, Bash(bash *design-audit/design-check.sh *)
---

# Design Audit — The Standing Gate

You verify a design system that already exists — after hand edits, after time, before a consuming project lifts it. You are **read-only**: findings and routes, no fixes. The build/revise skills run their own inline gates; you are the on-demand, whole-system pass.

**Preflight:** `design-system/` must exist with at least one theme dir; otherwise report there's nothing to audit and stop.

## Step 1 — Deterministic pass

Run `bash <skills-root>/design-audit/design-check.sh design-system [scoped theme dirs]`. Keep the raw lines; they carry the detail the report needs.

## Step 2 — Visual pass

Spawn one **visual-critic** subagent (`subagent_type: visual-critic`) with the design-system dir and the scope (all themes by default; the `$ARGUMENTS` theme dirs or component slugs when scoped). It renders the pages in Chrome and returns severity-tagged findings; if no browser is connected it says so and the report marks the visual half as limited.

Run Steps 1 and 2 concurrently when convenient — they're independent.

## Step 3 — The report

Merge into one severity-ranked report, deduplicating where the script and the critic caught the same thing:

1. **FAIL** — contract violations: contrast below 4.5, missing required tokens, unbalanced markers, physical direction classes, missing anchors, duplicate `data-ds-story` slugs, story sets differing across themes.
2. **Major visual** — the critic's `major` findings.
3. **WARN** — missing samples (RTL, long-string), spec'd variants without a `variant-<slug>` story, blocks with no story markers at all (pre-story builds), missing aria/focus-visible, stray blocks, unlinked themes.
4. **MISS** — catalog components not yet in a kitchen-sink.
5. **Minor visual / nits.**

Each finding carries its location (`<theme-dir>` + `#component-<slug>` or token name) and its **route** — the entry point that fixes it:

- Token/contrast problems → `/design-revise <theme>` (or `/design-themes` if the theme family is broadly off).
- Component markup problems (samples, ARIA, physical classes, visual findings) → `/design-revise <component>`.
- MISS components → `/design-build` (or `/design-add-component` if it's not in the catalog yet).
- Spec-level contradictions (a block that matches no COMPONENTS.md anatomy, catalog/marker mismatch) → `/design-components` revision.
- Doc drift (THEMES.md/FOUNDATION.md contradicting what's on disk) → the owning phase skill, named.

Close with a one-paragraph verdict: is the system lift-ready for a consuming project, and the shortest path if not. Fix nothing yourself — the human picks the routes.
