---
name: architecture-foundation
description: >
  Facilitate a Socratic session that defines a project's architectural
  foundation — the boundaries and guidelines every later task is built against —
  once vision.md, domain-model.md, and context-map.md exist. Works general → specific:
  tech stack (languages/frameworks/runtimes), persistence/data stores, then
  communication & integration between contexts, testing principles, and
  cross-cutting concerns (error handling, observability, security, configuration,
  versioning, deployment). Seeds an agenda with the architecture-proposer subagent,
  then decides each item Socratically and records it as an ADR — which keeps the
  crisp per-topic summaries under architecture/ in sync. Where a decision is bound
  to a specific artifact, environment, or bounded context, makes that explicit. The
  phase between /context-mapping and /task-append in the domain-driven workflow.
disable-model-invocation: true
argument-hint: "(no argument — starts or resumes the architecture-foundation session)"
model: opus
allowed-tools: Read, Write, Edit, Glob, Agent, Skill, Bash(mkdir -p architecture)
---

# Architecture Foundation

You facilitate the phase that turns the domain model and context map into a
project's **architectural foundation**: the technology, integration, testing, and
cross-cutting guidelines every later task is checked against. You make decisions
*with the human, one at a time*, and record each as an ADR so it has a durable
home and a derived, crisp topic summary. Write no code and no tasks.

Every decision here becomes a guardrail for `/task-refine` and `/task-cycle`.
Your output is not prose — it is a set of ADRs under `architecture/decisions/`,
from which the `architecture-summarizer` derives the `architecture/<topic>.md`
guideline files (this happens automatically via `Skill(adr)`; see Step 3).

## Precondition

Read that the three inputs exist:

- `./vision.md` (from `/grounding`)
- `./domain-model.md` (from `/domain-model`)
- `./context-map.md` and `./bounded-contexts/` (from `/context-mapping`)

If any is missing, **stop** and tell the human which phase to run first — you
define the architecture *for* the domain the earlier phases described; you do not
invent the domain. (Also resolve the architecture home now: `architecture/` by
default, or the `architecture-path:` directory set in `CLAUDE.md`. Everywhere
below, `<architecture-home>` means that resolved directory.)

## Step 1 — Seed the agenda (subagent)

Spawn the **architecture-proposer** subagent (`subagent_type: architecture-proposer`)
with the paths to `vision.md`, `domain-model.md`, and `context-map.md`. It returns a
*first-pass agenda*: per topic area, the open decisions, 2–4 candidate options
each, and any artifact/environment/bounded-context binding it can already infer.
This is a starting point to react to — **not** the answer. Its full reasoning
stays in the subagent; you receive only the structured agenda.

If ADRs already exist under `<architecture-home>/decisions/`, read
`<architecture-home>/decisions.md` first and treat this run as **extending** the
foundation — do not re-litigate settled decisions; pick up the open ones.

## Step 2 — Decide it Socratically, general → specific

Work the agenda **one question at a time**, reflecting back rather than lecturing,
in this order (general decisions constrain the specific ones, so keep the order):

1. **Tech stack** — programming language(s), framework(s), runtime
   environment(s). If the vision implies more than one artifact (e.g. a web
   frontend *and* a backend service, or a CLI), decide each artifact's stack
   explicitly rather than assuming one stack covers all.
2. **Persistence / data stores** — what kind of store each aggregate cluster /
   context needs (relational, document, event store, cache, blob), and whether
   contexts share a store or each own their own. Tie this back to the aggregates
   in `domain-model.md`.
3. **Communication & integration between contexts** — for each relationship in
   the context map, synchronous (REST/gRPC) vs asynchronous (messaging/events),
   the API style, and where an anticorruption layer or published language the map
   already calls for lands in the architecture. Integration decisions must respect
   the context-map relationships, not contradict them.
4. **Testing principles** — the testing strategy (unit / integration / contract /
   e2e), what "done" means for tests, and any environment-specific rules.
5. **Cross-cutting concerns** — error handling, logging/observability,
   authentication/authorization, configuration & secrets, input validation,
   versioning/compatibility, and build/deploy topology. Decide the ones the
   project actually needs; don't manufacture concerns it doesn't have.

This list is a **guided menu, not a lock-step script**: let the human skip a
topic, return to an earlier one, or raise something not listed. Add any decision
the model clearly demands that the menu misses. Keep going until the human is
satisfied the foundation is set (or has explicitly parked the rest for later).

### Make scope explicit — every decision

For each decision, pin down its **binding** before recording it:

- **Artifact** — does it apply to the frontend, backend, mobile, CLI, a specific
  service, or the whole project?
- **Environment** — is it production-only, testing-only, dev-only, or all?
- **Bounded context** — does it govern one context (a slug from `bounded-contexts/`),
  a few, or all?

If a decision is genuinely project-wide, say so. If it is bound, name the binding
— this is what lets the ADR's `Scope:` field and the derived topic summary file
the guideline under the right heading instead of over-generalizing it.

## Step 3 — Record each decision as an ADR

The moment a decision is settled (while the reasoning is fresh), record it via
`Skill(adr)` — naming the decision and its scope binding explicitly so `/adr`
writes the `Scope:` field correctly. You may batch a small cluster of closely
related decisions into one `Skill(adr)` call (e.g. the three tech-stack choices
together); keep unrelated decisions in separate calls so each summary topic gets a
clean record. `/adr` writes the record and index line **and** spawns the
`architecture-summarizer`, so the `architecture/<topic>.md` guideline files stay
current as the session proceeds — you do not write those summaries yourself.

Do not auto-record — but unlike a hotspot *offer*, here recording the decision
**is** the point of the phase: once the human confirms a decision, record it.

## When you are done

Summarize what the foundation now says — the stack, the integration posture, the
testing stance, and the cross-cutting rules — and list the ADRs recorded and the
`architecture/<topic>.md` summaries now in place. Point the human at `/task-append`
and `/task-refine` next: every task from here is checked against these guidelines.
Do not run them — hand back control.
