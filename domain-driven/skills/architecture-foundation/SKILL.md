---
name: architecture-foundation
description: >
  Facilitate a Socratic session that defines a project's architectural foundation — the boundaries and guidelines every later task is built against — once vision.md, domain-model.md, and context-map.md exist. Opens the agenda with the domain model's still-open hotspots — the last gate where each must be resolved, explicitly parked, reclassified, or (when it needs facts rather than a decision) handed to /dossier before the build phase — then works general → specific: tech stack (languages/frameworks/runtimes), persistence/data stores, then communication & integration between contexts, testing principles, and cross-cutting concerns (error handling, observability, security, configuration, versioning, deployment). Seeds an agenda with the architecture-proposer subagent, then decides each item Socratically and records it as an ADR — which keeps the crisp per-topic summaries under architecture/ in sync. Where a decision is bound to a specific artifact, environment, or bounded context, makes that explicit. Where a decision has a natural data shape (a config file, a payload, an event schema), offers to pin it with a concrete exemplar via the exemplar skill. Closes a first run by proposing a walking-skeleton task — one thin vertical slice that exercises the freshly decided stack, persistence, and one cross-context integration end-to-end, so wrong decisions surface while superseding them is cheap. Re-entrant: with ADRs but no landed code it extends the foundation; once implementation has landed it runs in revision mode — reading the architecturally-deviated tasks' closing records and superseding the decisions reality contradicted. The phase between /context-mapping and /task-append in the domain-driven workflow.
disable-model-invocation: true
argument-hint: "(no argument — starts, extends, or revises the architecture foundation)"
model: opus
allowed-tools: Read, Write, Edit, Glob, Agent, Skill, Bash(mkdir -p architecture), Bash(bash */skills/task-status/tasks.sh *)
---

# Architecture Foundation

You facilitate the phase that turns the domain model and context map into a project's **architectural foundation**: the technology, integration, testing, and cross-cutting guidelines every later task is checked against. You make decisions *with the human, one at a time*, and record each as an ADR so it has a durable home and a derived, crisp topic summary. Write no code and no tasks.

Every decision here becomes a guardrail for `/task-refine` and `/task-cycle`. Your output is not prose — it is a set of ADRs under `architecture/decisions/`, from which the `architecture-summarizer` derives the `architecture/<topic>.md` guideline files (this happens automatically via `Skill(adr)`; see Step 3).

## Precondition

Read that the three inputs exist:

- `./vision.md` (from `/grounding`)
- `./domain-model.md` (from `/domain-model`)
- `./context-map.md` and `./bounded-contexts/` (from `/context-mapping`)

If any is missing, **stop** and tell the human which phase to run first — you define the architecture *for* the domain the earlier phases described; you do not invent the domain. (Also resolve the architecture home now: `architecture/` by default, or the `architecture-path:` directory set in `CLAUDE.md`. Everywhere below, `<architecture-home>` means that resolved directory.)

## Step 1 — Seed the agenda (subagent)

Spawn the **architecture-proposer** subagent (`subagent_type: architecture-proposer`) with the paths to `vision.md`, `domain-model.md`, and `context-map.md`. It returns a *first-pass agenda*: first the domain model's still-open hotspots (settled ones already dropped against the decision index, with the settling ADR noted), then per topic area, the open decisions, 2–4 candidate options each, and any artifact/environment/bounded-context binding it can already infer. This is a starting point to react to — **not** the answer. Its full reasoning stays in the subagent; you receive only the structured agenda.

If the proposer reports hotspots an existing ADR already settles, tick those off in `domain-model.md` now (annotate the entry with the ADR number) — they need no session time.

If ADRs already exist under `<architecture-home>/decisions/`, read `<architecture-home>/decisions.md` first. Then check whether implementation has landed: run `bash <skills-root>/task-status/tasks.sh by-status done`. If nothing is `done` yet, treat this run as **extending** the foundation — no code has tested the settled decisions, so do not re-litigate them; pick up the open ones. If tasks have landed, follow **Revision mode** below instead — settled decisions that shipped code has since stressed are exactly the ones worth revisiting, and refusing to re-litigate them would defeat the point of the run.

## Step 2 — Decide it Socratically, general → specific

Work the agenda **one question at a time**, reflecting back rather than lecturing, in this order (general decisions constrain the specific ones, so keep the order):

0. **Open hotspots from `domain-model.md`** — this session is the last gate before the build phase, so sweep the list first: nothing unresolved may silently survive into `/task-append`. For each open hotspot, drive it to exactly one of four outcomes: **resolved** (decide it here — usually it folds into one of the topic areas below; record it as an ADR per Step 3 and tick it off in `domain-model.md` with the ADR number), **parked** (the human explicitly defers it — leave it open in `domain-model.md` and note *why* and *until when/what* next to it), **reclassified** (it turns out non-architectural, e.g. a pure naming question — leave it for the next `/domain-model` revision and say so), or **factual** (it is not a decision at all but a missing fact — what a regulation actually requires, what an external API actually does — which no amount of Socratic dialogue can settle: **offer** `Skill(dossier)` on the subject, either now as a sanctioned detour or noted for after the session; the hotspot stays open in `domain-model.md`, annotated with the dossier slug, until the facts come back — deciding a factual hotspot by gut feel here would encode a guess as an ADR). A hotspot that maps onto a later topic area can be deferred *within the session* to that item, but must not be dropped: track it until it lands.
1. **Tech stack** — programming language(s), framework(s), runtime environment(s). If the vision implies more than one artifact (e.g. a web frontend *and* a backend service, or a CLI), decide each artifact's stack explicitly rather than assuming one stack covers all.
2. **Persistence / data stores** — what kind of store each aggregate cluster / context needs (relational, document, event store, cache, blob), and whether contexts share a store or each own their own. Tie this back to the aggregates in `domain-model.md`.
3. **Communication & integration between contexts** — for each relationship in the context map, synchronous (REST/gRPC) vs asynchronous (messaging/events), the API style, and where an anticorruption layer or published language the map already calls for lands in the architecture. Integration decisions must respect the context-map relationships, not contradict them. This walk includes the map's **external contexts** — for each, decide the concrete integration mechanics from our side (client/SDK vs raw protocol, webhook vs polling, retry/idempotency posture, sandbox vs production credentials, and where the ACL the map calls for physically lives in the owned facing context). When the mechanics hinge on how the external system *actually behaves* and no dossier covers it, that is a **factual** item — offer `Skill(dossier)` rather than deciding on a guess; a decision with a natural data shape (a webhook payload, an API response) is a candidate for the exemplar offer in Step 3.
4. **Testing principles** — the testing strategy (unit / integration / contract / e2e), what "done" means for tests, and any environment-specific rules.
5. **Cross-cutting concerns** — error handling, logging/observability, authentication/authorization, configuration & secrets, input validation, versioning/compatibility, and build/deploy topology. Decide the ones the project actually needs; don't manufacture concerns it doesn't have.

This list is a **guided menu, not a lock-step script**: let the human skip a topic, return to an earlier one, or raise something not listed. Add any decision the model clearly demands that the menu misses. Keep going until the human is satisfied the foundation is set (or has explicitly parked the rest for later).

### Make scope explicit — every decision

For each decision, pin down its **binding** before recording it:

- **Artifact** — does it apply to the frontend, backend, mobile, CLI, a specific service, or the whole project?
- **Environment** — is it production-only, testing-only, dev-only, or all?
- **Bounded context** — does it govern one context (a slug from `bounded-contexts/`), a few, or all?

If a decision is genuinely project-wide, say so. If it is bound, name the binding — this is what lets the ADR's `Scope:` field and the derived topic summary file the guideline under the right heading instead of over-generalizing it.

## Step 3 — Record each decision as an ADR

The moment a decision is settled (while the reasoning is fresh), record it via `Skill(adr)` — naming the decision and its scope binding explicitly so `/adr` writes the `Scope:` field correctly. You may batch a small cluster of closely related decisions into one `Skill(adr)` call (e.g. the three tech-stack choices together); keep unrelated decisions in separate calls so each summary topic gets a clean record. `/adr` writes the record and index line **and** spawns the `architecture-summarizer`, so the `architecture/<topic>.md` guideline files stay current as the session proceeds — you do not write those summaries yourself.

Do not auto-record — but unlike a hotspot *offer*, here recording the decision **is** the point of the phase: once the human confirms a decision, record it.

### Offer an exemplar where the decision has a data shape

Some decisions have a natural concrete form: a **configuration** decision is a sample config file, an **integration** decision is a sample request/response or event payload, a **persistence** decision may be a sample record or dataset. For those, after recording the ADR, **offer** (never auto-create): *"want to pin this with an exemplar?"* On yes, invoke `Skill(exemplar)` naming the decision and its ADR number(s) as the anchor — the exemplar skill runs its own drafter-then-refine loop and files the result under `exemplars/` as `illustrative`, linked back to the ADR. This is a one-question offer per eligible decision, not a detour: if the human declines or wants to batch exemplars for later, move on — `/exemplar` can be invoked standalone at any time.

## Revision mode (when ADRs and landed tasks both exist)

The foundation's decisions are hypotheses until code exercises them — this mode is where the evidence gets its hearing. Do not re-run the whole agenda; work diff-oriented from what implementation taught:

1. **Ask what prompted the revision.** The human usually has a specific itch — a stack choice that fights every task, an integration style the contexts keep working around. Anchor the session there.
2. **Load the drift worklist.** Run `bash <skills-root>/task-status/tasks.sh deviated` — the `done` tasks whose shipped code departed from their spec (flagged by `/task-cycle`). For each listed id, `tasks.sh get <id>` gives the file path; read **only** that task's `## Closing` section (its `### Deviations from plan` record). This is the workflow's one sanctioned body read: a bounded, id-listed worklist, never a corpus scan. For each deviation, ask whether it implicates an **architectural decision** — the stack, a persistence choice, an integration style, the testing stance, a cross-cutting rule — or the domain model / context map, or nothing foundational at all.
3. **Re-decide what reality contradicted.** For each implicated decision, run it through Step 2's Socratic treatment with the evidence on the table. A reversal is recorded as a **superseding ADR** via `Skill(adr)` (naming the ADR it supersedes and the evidence that forced it) — never by editing the old record. The `architecture-summarizer` keeps the topic summaries current as usual. Decisions the evidence *confirms* need no new ADR — say so and move on. If a re-decided decision has linked exemplars (check `exemplars/exemplars.md` for entries citing its ADR number), they now encode the contradicted answer: invoke `Skill(exemplar)` on each to fold the evidence in as part of this revision — a stale `normative` exemplar is a spec bug tasks will faithfully build against.
4. **Drain the worklist.** When a deviated task's lesson is architectural and has been folded in (superseded or confirmed), clear its flag — edit its frontmatter `deviated: true → false`. If the deviation also implicates the domain model or context map, **leave the flag set** and say so: a `/domain-model` or `/context-mapping` revision is its remaining consumer.

Extending and revising compose: after the evidence pass, the human may open genuinely new topics (Step 2) as in any run.

## When you are done — and the walking skeleton

Summarize what the foundation now says — the stack, the integration posture, the testing stance, and the cross-cutting rules — and list the ADRs recorded, the `architecture/<topic>.md` summaries now in place, and any exemplars pinned (noting they are `illustrative` until a `/spec-sharpener` run promotes them). Account for every hotspot the agenda opened with: which were resolved (and their ADRs), which the human parked (and why), which were reclassified as non-architectural, and which were factual and handed to `/dossier` (and their dossier slugs — those return to the agenda once the facts are in).

**Then propose the walking skeleton.** Every decision just recorded is untested until code exercises it, and the natural backlog rarely does so early — domain-driven prioritization can keep the first dozen tasks inside one context, leaving the integration and persistence ADRs unvalidated until reversing them is expensive. So on a first run (and on any run where the backlog holds no `done` task that already exercises the foundation end-to-end), propose **one first vertical-slice task**: a deliberately thin end-to-end path — trivial domain behavior is fine — that touches each artifact's stack, at least one persistence decision, one relationship from the context map (the integration style *and* any ACL/published language it calls for), and the deploy/test topology. Frame it explicitly as *validating the ADRs recorded today while superseding them is still cheap*, and name the specific ADRs it exercises. On the human's approval, hand it to `Skill(task-append)` with that framing (one call; `/task-refine` will size and wire it) — do not mint ids or write task files yourself. If the human declines, note that `/whats-next` will re-surface the gap.

Point the human at `/task-append` and `/task-refine` next: every task from here is checked against these guidelines. After a **revision**, also name any deviated tasks whose flags you left set for a `/domain-model` or `/context-mapping` revision. Do not run anything further — hand back control.
