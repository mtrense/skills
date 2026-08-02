# Slice-Driven Workflow — Shared Overview

Read this to understand where the current skill sits in the family. The workflow has no phases; it has one entry point and a small set of loops.

## Principles

1. **Code is the probe, spec is the harvest.** Nothing is specified in depth before evidence exists. The spec/intent docs only ratchet forward with what running code has validated.
2. **Triage over phases.** Every change enters through `/work` and is typed by one question: *could you just build this and judge the result, or is there a decision you can't make without evidence?* → chore / feature / probe.
3. **Probes are subordinate.** A slice must name the decision it unblocks, sourced from a feature breakdown or QUESTIONS.md. One session, one decision. No new slice while one is unharvested. Default is build.
4. **Decisions are tiered.** `grounded` (evidence-linked, locked unless contradicted) vs `provisional` (explicit assumption, fair game for a cheap slice). Never re-open settled ground uninvited; never run unprompted audit passes over it.
5. **Feedback in hours.** Every cycle — slice or first walking-skeleton task — ends the same session with something runnable.

## The loop

```
/intent (once)
   ↓
/work  ──chore──────────────────────────→ /build
   │──feature → shape + breakdown ──────→ /build (per task, TDD)
   │──probe ──→ /slice → /harvest ──────→ (feature resumes or new /work)
   ↑______________________________________|
```

`/decide` is called from within the other skills (and directly by the human) whenever a decision is made or challenged.

## Project artifacts

| File | Role | Owner |
|------|------|-------|
| `INTENT.md` | One page: problem, users, success shape, **Invariants**, **Vocabulary** | `/intent`, appended by `/harvest` + `/build` |
| `QUESTIONS.md` | Open-unknowns backlog, prioritized by risk × load-bearingness | all skills |
| `work/NNNN-slug.md` | One work item (chore/feature/probe); frontmatter is machine-readable | `/work` creates, `/build`+`/slice`+`/harvest` update |
| `decisions/NNNN-slug.md` | One decision record with `grounding:` tier and `evidence:` link | `/decide` |
| `DECISIONS.md` | Lean index, one line per decision | `/decide` |

## Deterministic bookkeeping

Status flips, listing, and next-item selection are done by shell scripts, not by the LLM: `scripts/` inside the `work` skill (`work-list.sh`, `work-next.sh`, `work-status.sh`, `work-new.sh`). Skills call these instead of hand-editing frontmatter. Requires `yj` and `jq`.

## Work item frontmatter

```yaml
---
id: 7                 # integer, unique, ascending
slug: local-admin-api
title: Local admin API
type: feature         # feature | chore | probe
status: shaped        # shaped | in-progress | blocked | done | dropped
entered: 2026-08-02
blocked_by: []        # ids of work items this waits on (usually a probe)
branch: null          # probes only: slice/NNNN-slug
decision: null        # probes only: the decision this probe unblocks
---
```

Body sections (in order): `## Outcome`, `## Examples`, `## Evidence of done`, `## Decisions touched`, `## Tasks`, `## Results`. Chores may omit Examples and Decisions touched. Results is filled during `/build` / `/harvest`: what was tested and how, naming deviations from the shaped plan, surprises, and follow-ups spawned.
