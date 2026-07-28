---
name: showcase
description: >
  Assess the domain-driven project's current progress and report what the human can already test or present — as demoable capabilities tied to vision outcomes, each with a concrete step-by-step walk-through. Read-only: synthesizes the `## Closing → ### Manual testing` records the landed (`done`) tasks already carry (a bounded, status-gated body read — the ids come from `tasks.sh by-status done`, never a scan), grounds every command/URL/action against the repo before scripting it, and closes with what the next `/task-cycle` run would add to the demo. The backward-looking demo companion to `/task-status` (where the backlog stands) and `/whats-next` (what to build next).
argument-hint: "[<context>]   (optional — scope the showcase to one bounded context)"
model: opus
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(bash */skills/task-status/tasks.sh *), Bash(for *), Bash(if *), Bash(awk *), Bash(cat .workflow-overrides/*)
---

# Showcase — What Can Already Be Shown

You answer *"what does the work landed so far already let a human see, touch, test, or present — and how, exactly, step by step?"* You turn the backlog's `done` set into a demo: a short progress summary, the list of capabilities that are already presentable, and a walk-through script the human can follow (or hand to someone else) without reading a single task file.

This is a **read-only** report. You never edit tasks, never write files, never clear flags. Your raw material is the implementation-phase records `/task-cycle` already persisted: each landed task's `## Closing` section, whose `### Manual testing` block holds the human-verification/demo steps the worker reported when the task landed. Reading those bodies is sanctioned here precisely because it is **bounded and status-gated** — exactly the ids `tasks.sh by-status done` lists, pre-extracted below, never a corpus scan.

## Pre-rendered backlog state

The blocks below are the captured stdout of `tasks.sh` queries (sibling `task-status` skill directory) run **before** this skill loaded, against the default `./tasks` backlog. They are the source of truth — do not re-run them. If the board block shows a `tasks.sh: … not found` error, report that the backlog tooling (`jq`/`yj`) or the `tasks/` directory is missing and stop.

### Board totals (counts per status)

```
!`bash "${CLAUDE_SKILL_DIR}/../task-status/tasks.sh" board 2>&1`
```

### Landed tasks with their closing records (id · [context] · title, then the `## Closing` body)

Each `=== NNNN … ===` header is one `done` task; what follows until the next header is that task's `## Closing` section verbatim — its `### Manual testing` steps and `### Deviations from plan` record. A `(deviated)` marker on the header means the shipped code departed from the spec non-trivially: trust the closing record over the task's title when they disagree.

```
!`SH="${CLAUDE_SKILL_DIR}/../task-status/tasks.sh"; dn=$(bash "$SH" by-status done 2>/dev/null); if [ -z "$dn" ]; then echo '(none — nothing has landed yet)'; else for id in $dn; do hdr=$(bash "$SH" get "$id" 2>/dev/null | jq -r '"[\(.context // "-")]  \(.title)\(if .deviated then "  (deviated)" else "" end)"'); printf '=== %s  %s ===\n' "$id" "$hdr"; found=0; for f in tasks/${id}-*.md; do if [ -e "$f" ]; then found=1; awk '/^## Closing/{c=1;next} c&&/^## /{exit} c' "$f"; fi; done; if [ "$found" = 0 ]; then echo '(task file not found)'; fi; printf '\n'; done; fi`
```

### Coming up — ready todos and in-progress work (what the next `/task-cycle` run adds to the demo)

```
!`SH="${CLAUDE_SKILL_DIR}/../task-status/tasks.sh"; any=0; for id in $(bash "$SH" ready 2>/dev/null); do any=1; bash "$SH" get "$id" 2>/dev/null | jq -r '"ready:        \(._id)  [\(.context // "-")]  \(.title)"'; done; for id in $(bash "$SH" by-status "in progress" 2>/dev/null); do any=1; bash "$SH" get "$id" 2>/dev/null | jq -r '"in progress:  \(._id)  [\(.context // "-")]  \(.title)"'; done; if [ "$any" = 0 ]; then echo '(none)'; fi`
```

## If nothing has landed

If the `done` set is empty, there is no showcase yet — say so in two sentences, read the board totals to name where the project actually stands in the pipeline (all drafts → `/task-refine`; ready todos waiting → `/task-cycle`; empty backlog → `/task-append` or `/whats-next`), and stop. Do not fabricate a walk-through from unbuilt specs.

## If a context argument was given

If a `<context>` argument (`$ARGUMENTS`) was supplied, run `bash "${CLAUDE_SKILL_DIR}/../task-status/tasks.sh" by-context <context>` once to get that context's id set and scope everything — capabilities, walk-through, coming-up — to the pre-rendered rows whose id is in that set. With no argument, showcase the whole project.

## Step 1 — Load the framing (small, central files only)

Read **`./vision.md`** and **`./context-map.md`** if present — the vision names the outcomes a demo should prove progress toward, and the map gives each capability its home context and the relationships that order a sensible tour (upstream before downstream). If either is missing, proceed from the tasks alone and say the framing was unavailable. If **`exemplars/exemplars.md`** exists, read the index (one line per exemplar, never the bodies): a `normative` exemplar that a landed task implements is prime demo material — the sample bytes the human can hold up next to the running behavior.

Do **not** read `domain-model.md`, ADR bodies, or any task body beyond the pre-extracted closings — this is a demo report, not an audit.

## Step 2 — Derive the showable set

Work through the landed tasks and sort each into one of two piles:

- **Human-visible capability** — something with an observable surface: a CLI command, an endpoint, a UI screen, a file the system produces, a behavior a test-drive can trigger. This is showcase material.
- **Internal plumbing** — scaffolding, refactors, wiring, library-internal behavior with no surface a human can poke. Real progress, but not walkable; it gets one line in the summary, never a demo step.

Then compose the visible pile into **capabilities**: several tasks often add up to one demoable thing (a walking skeleton plus two follow-ups = "create X end to end"). Group by bounded context, and tie each capability to the vision outcome it moves toward when the framing supports it.

Two integrity rules govern the walk-through you build from the `### Manual testing` records:

- **Freshness.** The records were written task by task, and a later task may have changed the surface an earlier record describes (renamed a command, moved an endpoint, replaced a flow). Where records touching the same surface disagree, prefer the newest; before putting any load-bearing step into the script — the entry-point command, a URL, a config path, a build/run invocation — verify it against the repo with a targeted `Read`/`Grep`/`Glob`. A walk-through that fails at step 1 is worse than none.
- **Grounding.** Every step must be grounded in a Manual-testing record or verified against the repo. Never invent a plausible-sounding step, and never promote something a record describes as partially working into a clean demo step — a known rough edge belongs in the caveats, where the presenter can steer around it. For `(deviated)` tasks, the `### Deviations from plan` record tells you where shipped behavior departed from the spec: describe what *is*, and flag the departure if a viewer might expect otherwise.

## Step 3 — Render the report

Produce, in this order:

1. **Progress snapshot** — two or three sentences: how much has landed (board totals), which contexts have running substance, and the one-line headline of what the project can already do. Lead with this.
2. **What you can already test or present** — the capability list. Per capability: a name, its bounded context, one line on what it shows, the vision outcome it serves (when framing exists), and the contributing task ids. Mention implemented `normative` exemplars here. Close the section with a one-line roll-up of the internal-plumbing pile so landed-but-invisible work still counts.
3. **Walk-through** — the step-by-step demo script, written so a human can execute it top to bottom:
   - **Setup (once)** — prerequisites, environment, build/run commands, seed data. Exact commands, copy-pasteable.
   - **The tour** — numbered steps ordered for presentation: foundation before payoff, upstream context before its downstream consumer, ending on the strongest capability. Each step is one concrete action (a command, a URL, a click, a file to open) followed by *what the viewer should see* — the observable result that proves the step worked.
   - **Caveats** — rough edges, `(deviated)` departures a viewer might trip over, and anything the presenter should avoid poking. Honest beats polished: this section is what makes the script safe to hand to someone else.
4. **Not showable yet** — the coming-up block, rendered as one short list: what is `in progress` or ready, and what each would add to the next showcase.

Keep it compact and human-readable — tables for short enumerable facts, **mermaid (never ASCII art)** if a tour map helps. The report lives in chat; it can be regenerated any time, so persist nothing.

## When you are done

Close by pointing at the move that grows the showcase: `/task-cycle` if the ready-set is non-empty, `/task-refine` if drafts are waiting, `/whats-next` if the backlog is thin. Hand back control — you propose nothing and run nothing.
