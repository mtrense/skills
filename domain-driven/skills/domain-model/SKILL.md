---
name: domain-model
description: >
  Run a big-picture EventStorming session over the project vision and produce a single `domain-model.md` at the project root: a chronological domain-event timeline, the commands/actors that trigger them, policies and external systems, the aggregates that own consistency, and a hotspots list of unresolved decisions. Seeds the first pass with the domain-seed-extractor subagent, then refines it Socratically with the human. Offers to turn hotspots into ADRs. The second phase of the domain-driven workflow — its clusters feed /context-mapping.
disable-model-invocation: true
argument-hint: "(no argument — starts or resumes the domain-model session)"
model: opus
allowed-tools: Read, Write, Edit, Glob, Agent, Skill
---

# Domain Model — Big-Picture EventStorming

You are facilitating the **second** phase of the domain-driven workflow. You turn the vision into a shared model of *what happens in the domain, in what order, and what owns each decision* — an EventStorming pass — and record it in `./domain-model.md`. This model is the raw material `/context-mapping` draws bounded contexts around, and it is the **referent** every later task is checked against for domain-compliance. Write no code and no tasks.

## Precondition

Read `./vision.md`. If it is missing, stop and tell the human to run `/grounding` first — you model the domain the vision describes, you do not invent one.

## Step 1 — Seed the storm (subagent)

Spawn the **domain-seed-extractor** subagent (`subagent_type: domain-seed-extractor`) with the path to `vision.md`. It reads the vision and returns a *first-pass* event storm: candidate domain events (past-tense facts), the commands/actors it can infer, obvious external systems, candidate aggregates, and an initial hotspots list. This is a starting point to react to — **not** the answer. The subagent's full reasoning stays in the subagent; you receive only its structured proposal.

If `domain-model.md` already exists, skip the seed and read the existing model instead — this run is a **revision**.

## Step 2 — Storm it out with the human (Socratic)

Work the seed into a real model **one question at a time**, in roughly this order (the canonical big-picture EventStorming flow). Reflect back, don't lecture:

1. **Chaotic exploration → domain events.** Confirm/prune/add the past-tense events (`OrderPlaced`, `PaymentSettled`, `ShipmentDispatched`). Events are *facts that already happened*, named in the domain's own words. **Not every event happens inside the software** — big-picture EventStorming deliberately includes events that originate *outside* the system: real-world happenings (`CustomerChangedTheirMind`), emissions from systems you don't own (`PaymentAuthorized` from a gateway), and the clock (`SubscriptionExpired`). Include them — they show the full flow and reveal where the software's boundary actually falls. Mark each event's **origin** (in-software vs external) as you go; it will not always be obvious, and disagreement there is itself a hotspot worth surfacing.
2. **Enforce the timeline.** Order the events chronologically and hunt the gaps — *"what happens between OrderPlaced and PaymentSettled?"* Missing events hide here. For each event, also capture **the situation it happens in** — the trigger or circumstance: *"under what conditions does this occur?"* An in-software event's trigger is usually a command; an external event's is a real-world condition, a schedule, or another system acting. Noting the situation stops events from floating free of *why* they fire.
3. **Commands & actors.** For each *in-software* event, what command caused it and who issued that command (a human role or another system). External events have **no command you own** — record their triggering situation instead (see the timeline above), so it is clear the software only *learns of* them rather than causing them.
4. **Policies & external systems.** The reactive rules — *"whenever X happens, then Y"* — and the systems you don't own that you send to or receive from.
5. **Aggregates.** Cluster commands+events into consistency boundaries: the thing that accepts a command, enforces its invariants, and emits the events. These clusters are what `/context-mapping` will draw boundaries around. Only in-software events belong to an aggregate; an external event has no owning aggregate — instead note which aggregate *reacts to* it (often via a policy).
6. **Hotspots.** Mark every contested term, unknown, conflict, or "we haven't decided this yet". Hotspots are the honest edge of the model.

Keep asking until the timeline reads as a coherent story and each event has a plausible command, actor, and owning aggregate — or is explicitly parked as a hotspot.

## Step 3 — Hotspots → ADRs (offer)

A hotspot is precisely *a decision not yet made*. For each hotspot that is a real architectural or directional choice (not just a naming quibble), **offer** to record it as an ADR via `Skill(adr)` — so the decision has a durable home and later `/task-refine` can reference it. Never auto-create ADRs; the human chooses which hotspots deserve one. Naming quibbles and small unknowns stay in the hotspots list.

## Producing `domain-model.md`

Write `./domain-model.md`. Keep it a working model, not an essay:

```markdown
# Domain Model: <project name>

## Event timeline
<domain events in chronological order; group into phases if it helps. mark external-origin events with (external) — real-world happenings, emissions from systems you don't own, or the clock. give each event its triggering situation.>
1. **OrderPlaced** — <what it means> · _when:_ <situation/trigger>
2. **PaymentAuthorized** (external) — gateway approved the charge · _when:_ card cleared upstream
3. **PaymentSettled** — ... · _when:_ ...

## Commands & actors
<in-software events only; external events are triggered by a situation, not a command you own>
| command | actor | emits event(s) |
|---|---|---|
| PlaceOrder | Customer | OrderPlaced |

## Policies
- Whenever **PaymentSettled**, then **DispatchShipment** (issues DispatchShipment command).
- Whenever **PaymentAuthorized** (external) arrives, then **SettlePayment**.

## External systems
- <system you don't own> — <what crosses the boundary, which direction, which external events it emits>

## Aggregates
### <AggregateName>
- **Owns:** <invariants / consistency it guarantees>
- **Accepts:** <commands>  **Emits:** <events>

## Hotspots
- [ ] <unresolved question or conflict>  <!-- ADR-0007 if one was recorded -->
```

If the model already existed, edit in place; open by reflecting the prior model back before changing it.

## When you are done

Summarize the model in a few sentences — especially the aggregate clusters, since those become candidate contexts. Point the human at `/context-mapping` next. Do not run it — hand back control.
