---
name: design-build
description: >
  Drive the component kitchen-sinks to done: fan component-smith workers out one-per-component (each building that component across every theme), assemble each theme's index.html and the root index.html deterministically, run the design-check gate, and close with a visual-critic pass. Takes [<limit>|all][@<workers>] (default all@4). Resumable and idempotent — the worklist is re-derived from the marker blocks each pass.
disable-model-invocation: true
argument-hint: "[<limit>|all][@<workers>]   (e.g. `all`, `5`, `all@8`, `@2`; default `all@4`)"
model: opus
allowed-tools: Read, Edit, Glob, Grep, Agent, Bash(bash *design-build/assemble.sh *), Bash(bash *design-audit/design-check.sh *), Bash(rm -rf design-system/.fragments*)
---

# Design Build — Burn Down the Catalog

You are the orchestrator of phase 4: every catalog component, built across every theme, assembled into browsable kitchen-sinks. You hold worklists and reports — the markup lives in the **component-smith** workers and the fragment files, never in your context.

## Invariants

- **Workers write only fragments.** A component-smith touches `.fragments/<slug>/` and nothing else. Only `assemble.sh` writes an `index.html`; only you decide when it runs.
- **One worker owns one component across ALL themes** — that's what keeps the DOM identical between themes. Never split a component's themes across workers.
- **The worklist is derived, never remembered.** Each pass recomputes it from `assemble.sh missing` — that makes the cycle resumable and idempotent.

## Step 0 — Parse the argument & preflight

- Parse `[<limit>|all][@<workers>]` (default `all@4`): `limit` = max components this run, `workers` = parallel smiths per batch.
- Required on disk: `design-system/FOUNDATION.md`, `THEMES.md`, `COMPONENTS.md` with a non-empty catalog (`bash <skills-root>/design-build/assemble.sh catalog design-system`), and at least one `<theme>-<mode>/` dir with `index.css` + `tokens.md`. Missing any → stop and name the phase skill that produces it.
- Enumerate the theme dirs (every `*-light`/`*-dark` with an `index.css`).

## Step 1 — Derive the worklist

For each theme dir run `bash <skills-root>/design-build/assemble.sh missing design-system <theme-dir>`. The worklist is the **union** of slugs missing anywhere, in catalog order — a component missing in only one theme is still built by one smith for **all** themes (the shared DOM must be re-established, and existing blocks in other themes get replaced by its fragments). Cap at `limit`.

Empty worklist → skip to Step 3 (assembly may still be pending) and report.

## Step 2 — Batch the smiths

In batches of `workers`, spawn **component-smith** subagents (`subagent_type: component-smith`) **in parallel in a single message** — one per slug, each given: the slug, the `COMPONENTS.md` path, the conventions path (`<skills-root>/design-audit/references/conventions.md`), the full theme-dir list, and the fragments dir. Distinct slugs write to distinct `.fragments/<slug>/` dirs, so a batch never collides.

Collect reports. A worker that flags a spec problem (missing token, ambiguous anatomy) gets its component parked — surface those to the human at the end rather than improvising a spec fix mid-cycle.

## Step 3 — Assemble & gate

After each batch:

1. `bash <skills-root>/design-build/assemble.sh assemble design-system <theme-dir>` for every theme dir, then `… index design-system`.
2. `bash <skills-root>/design-audit/design-check.sh design-system`.
3. FAILs traceable to a just-built component (unbalanced markers, physical classes, missing anchor) → respawn that one smith **once** with the FAIL lines quoted; re-assemble, re-check. Still failing → park it and move on. FAILs in tokens are not yours — report them toward `/design-themes`/`/design-revise`.

Loop Steps 1–3 until the worklist is empty or `limit` is reached.

## Step 4 — Visual close-out

When the catalog is fully assembled (no MISS lines), spawn one **visual-critic** subagent (`subagent_type: visual-critic`) scoped to all themes. Present its findings to the human severity-ranked. For the fixes the human approves, run targeted smith rounds (the affected slugs, all themes, the finding quoted in the brief) and re-assemble + re-check. The human decides when it's good — the critic advises.

Then clean up the intermediates: `rm -rf design-system/.fragments` (the assembled pages are the source of truth; `assemble.sh` re-extracts blocks from them when needed).

## When you are done

Report: components built this run, parked components (and why), the check summary line, the critic verdict per theme, and what remains if `limit` cut the run short. Defer the commit to `/commit`.
