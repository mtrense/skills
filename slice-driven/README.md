# Slice-Driven Workflow

An evidence-first build workflow that inverts spec-heavy development: decide the minimum, build a probe or a feature, and let running code settle the rest. The specification is a **ratchet** — it only records what evidence has already validated, so it can never demand more upfront thinking than the code has earned.

## Why

Spec-front-loaded workflows fail in a predictable way: you spend days or weeks making hundreds of design calls in the abstract, without the feedback running code would give. Ungroundable decisions pile up, get second-guessed, and get re-litigated. Slice-driven attacks all three failure modes:

- **Ungroundable decisions** are deferred by design and made with code in hand.
- **Re-litigation** is gated: decisions carry a grounding tier and evidence links; reopening a grounded decision requires new evidence, while provisional ones route to a cheap probe instead of a debate.
- **Reward** arrives within hours: every cycle ends with something runnable.

## The triage rule

There are no phases. Every change enters through `/work` and is typed by one question: *"Could you just build this and judge the result, or is there a decision you can't make without evidence?"*

| Type | Meaning | Path |
|------|---------|------|
| **chore** | No unknown at all ("add structured logging") | Straight to `/build`, no ceremony |
| **feature** | Outcome known, path mostly known | Co-defined breakdown → `/build` under TDD |
| **probe** | A named decision is blocked without evidence | `/slice` branch → `/harvest` |

Probes are subordinate, never a phase: a slice must name the decision it unblocks, is scoped to one session, and no new slice starts while another is unharvested. The default is *build* — uncertainty alone doesn't earn a probe, only uncertainty that is expensive to be wrong about.

## Skills

| Command | What it does | Produces |
|---------|-------------|----------|
| `/intent` | One-off Socratic session: problem, users, success shape, known invariants, vocabulary. Refuses to settle ungroundables — those go to QUESTIONS.md. | `INTENT.md`, `QUESTIONS.md`, `work/` |
| `/work` | Single entry point for any change. Triages, then shapes: outcome, examples, evidence-of-done, decisions touched, task breakdown. | `work/NNNN-slug.md` |
| `/slice` | Probe branch scoped to one named decision; may start from a concrete example. One session, sloppy on purpose. | `slice/NNNN-slug` branch + probe work item |
| `/harvest` | Closes a slice: fate call (approve/adjust/discard), grounded decisions, spec/vocabulary/exemplar deltas, question updates. | Decision records, updated INTENT/QUESTIONS |
| `/build` | Picks the next shaped item (or a named one) and burns down its tasks under strict TDD — one `build-worker` implements each task, then an independent `task-lander` re-runs the tests and commits it (via `/commit`), one commit per task, stamping the item with a baseline SHA at start and each ticked task with its commit's short SHA. Fills the item's Results section. | Passing code + tests, per-task commits, updated work item |
| `/decide` | Records decisions with a grounding tier; gatekeeper for reopening settled ones. | `decisions/NNNN-slug.md` + `DECISIONS.md` |
| `/steer` | Out-of-band direction check: takes a statement, hunch, or question about the project's state, gathers the evidence via subagents (`decision-briefer` + one `claim-checker` per claim), and answers with citations. On contradiction with the code, decisions, or docs, runs a course-correction interview and routes each fix to its owning skill (`/decide` reopening, doc ratchet, captured work item, probe). | Answer + routed corrections |

**Typical flow:** `/intent` (once) → `/work` (as ideas arrive — queuing several before building is fine) → `/build` (next item) → interleaved `/slice` + `/harvest` whenever a breakdown hits an ungroundable call → repeat. `/steer` is invoked out-of-band whenever the human wants to check or discuss the direction — the more autonomously the build loops run, the more that entry point matters.

Depends on `common` being installed alongside it for `/commit` — every task lands through it, invoked by `/build`'s `task-lander` subagent (implementation workers never commit; the lander is a separate agent, so verification stays independent of the worker, and the test output, diff, and commit machinery stay out of the main session), keeping the single-commit-point convention.

## Project artifacts

```
INTENT.md            # one page: problem, users, success, invariants, vocabulary
QUESTIONS.md         # open-unknowns backlog (replaces a roadmap early on)
work/NNNN-slug.md    # one file per work item; YAML frontmatter carries type/status
decisions/NNNN-slug.md
DECISIONS.md         # lean decision index
```

Work items carry machine-readable frontmatter; deterministic shell scripts (in `skills/work/scripts/`, using `yj` + `jq`) handle listing, next-up selection, and status flips — no LLM in the loop for bookkeeping.

## Decision tiers

Every decision record is `grounding: grounded` or `grounding: provisional`. Grounded decisions link their evidence (a slice branch, commit, benchmark output) and are locked unless contradicted by new evidence. Provisional decisions are explicit assumptions — fair game for a cheap `/slice` at any time. This tiering is the anti-second-guessing mechanism: doubt about a grounded decision meets its evidence; doubt about a provisional one becomes a probe, not a debate.
