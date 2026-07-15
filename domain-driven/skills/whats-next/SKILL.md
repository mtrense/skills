---
name: whats-next
description: >
  Assess the project's vision, domain model, and context map against the current
  backlog state, surface the coverage gaps, and propose a prioritized list of next
  tasks to work on. Reads the domain artifacts directly and the backlog through the
  tasks.sh helper (frontmatter only — never scanning task bodies). Advisory: it
  proposes tasks and, on approval, hands each to /task-append as a draft — it never
  mints ids, wires dependencies, or refines (that is /task-append and /task-refine).
  The forward-looking companion to the read-only /task-status board.
argument-hint: "[<context>]   (optional — scope the assessment to one bounded context)"
model: opus
allowed-tools: Read, Glob, Bash(bash */skills/task-status/tasks.sh *), Skill
---

# What's Next — Assess the Domain and Propose Next Tasks

You answer *"given where this project wants to go and what is already in the
backlog, what should we work on next?"* You compare the **coverage target** — the
vision, the domain model, the context map — against the **current state** — the
backlog — and hand back a short, prioritized list of concrete next tasks.

This is an **advisory** step. You **propose**; you do not mint ids, write task
files, wire dependencies, size or split anything, or record ADRs. Approved
suggestions are handed to `/task-append` (which captures each as a `draft`);
`/task-refine` later turns those drafts into ready `todo`s. Keeping capture and
refinement where they belong preserves the single-writer id minting the backlog
depends on.

## Precondition

Read `./vision.md` and `./domain-model.md`. If **either** is missing, stop and
point the human at `/grounding` then `/domain-model` — you assess the domain those
describe, you do not invent one. `context-map/` is strongly preferred (it is the
domain-compliance referent and the primary axis you organize suggestions around);
if it is missing, say so and give a coarser, context-agnostic assessment while
recommending `/context-mapping`.

## Step 1 — Load the coverage target (read the domain artifacts directly)

These files are small and central; read them in-session so the assessment is
grounded in their actual language.

- **`./vision.md`** — the outcomes the project is trying to make true.
- **`./domain-model.md`** — the event timeline, aggregates (the consistency
  boundaries that must be built), policies, external systems, and the **hotspots**
  list (unresolved decisions).
- **`context-map/INDEX.md`** and each **`context-map/<context>.md`** — the bounded
  contexts, their responsibilities and relationships, and each one's ubiquitous
  language. If a `<context>` argument was given, load that context's file and scope
  the whole assessment to it.
- **The decision index** if present — `architecture/decisions.md` by default, or under
  the `architecture-path:` directory set in `CLAUDE.md` — so you can tell which hotspots
  have already been settled as ADRs (and needn't be re-flagged). The crisp
  `<architecture-home>/<topic>.md` guideline summaries are a quick read for what the
  foundation already commits to.

## Step 2 — Load the current state (backlog frontmatter only)

The two blocks below are the captured stdout of the `tasks.sh` helper (a sibling
skill directory), run **before** this skill loaded against the default `./tasks`
backlog. They are the source of truth — do not re-run these queries. Each task's
`_id`, `title`, `status`, `context`, and `depends_on` is derived from frontmatter
alone. This is the compliant way to see the corpus: **never open task bodies to
assess coverage** — title + context + status is enough for a gap scan, and the
backlog is allowed to grow large.

### Whole backlog (frontmatter as JSON)

```
!`bash "${CLAUDE_SKILL_DIR}/../task-status/tasks.sh" list 2>&1`
```

### Counts per status (for framing)

```
!`bash "${CLAUDE_SKILL_DIR}/../task-status/tasks.sh" board 2>&1`
```

Non-terminal tasks (`draft`, `todo`, `in progress`) that name an area mean that
area is already accounted for; `done` means it is built; a `split` tombstone is
inert (look through it to its children). Do not re-propose what the backlog already
carries.

## Step 3 — Assess coverage and find the gaps

Cross the target against the state. Look for:

- **Uncovered aggregates / major events.** An aggregate in the model that no task
  (in any live status) builds toward is the clearest gap — aggregates are the
  consistency boundaries the system is made of.
- **Thin or empty contexts.** A bounded context with little or no backlog behind
  it, especially one the vision leans on.
- **Unrepresented vision outcomes.** An outcome the vision names that nothing in
  the backlog moves toward.
- **Blocking hotspots.** A hotspot that is still unresolved *and* unrecorded (no
  ADR, no task) and that gates real work — flag it as a decision to make (offer
  `/adr`, or a spike task) rather than burying it in an implementation task.
- **Foundation ordering.** Which gaps are *roots* — prerequisites that unblock the
  most downstream work — versus leaves. Use the context relationships: an upstream
  context in a customer/supplier or published-language relationship generally needs
  its contract to exist before the downstream context can build against it.
- **Drift (light touch).** A live task whose `context` or evident intent no longer
  matches the current map — note it for `/task-refine`, don't fix it here.

## Step 4 — Propose the next tasks (prioritized, short)

Produce a **focused** list of the highest-value next tasks — the few things worth
doing next, ordered foundation-first — not an exhaustive enumeration of every gap.
For each proposed task give:

- an **imperative title** (what `/task-append` would capture),
- the **target context** (a context-map slug),
- a **one-line why**, tied to a specific vision outcome, aggregate, or event, and
- a **build-order hint** — which existing task id or which other suggestion it
  builds on (a hint for `/task-refine`, not a wired dependency).

Render the assessment compactly: a short gaps summary, then the ranked suggestion
list (a small table is fine; use **mermaid, never ASCII art**, for any graph).
State plainly that these are suggestions — `/task-refine` will size, split, wire
dependencies, and check each against its context before it becomes workable.

## Step 5 — Offer to capture (hand off, never auto-append)

Ask the human which suggestions to capture. For each one they approve, invoke
`Skill(task-append)` with the title and the one-line why so it lands as a `draft` —
one call per approved task. **Do not** append the whole list unprompted, and **do
not** write task files or mint ids yourself; `/task-append` is the single, human-
serial capture point. If the human wants none captured, that is fine — the report
stands on its own.

## When you are done

Close by pointing at the next move: `/task-refine` to turn any freshly captured
drafts into ready `todo`s, or `/task-cycle` if the backlog already has ready work.
If the sharpest gap is really an undecided hotspot, point at `/adr` (or a return to
`/domain-model`) instead. Hand back control.
