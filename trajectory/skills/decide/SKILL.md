---
name: decide
description: >
  Record, revise, or supersede one decision in a trajectory project's decision log. Takes a
  statement to decide on, a reference to an existing decision (to revise or supersede), or —
  when invoked empty — the next open decision item from the lowest-id open milestone. Runs a
  brief Socratic dialog to a shared understanding, persists
  documentation/decisions/NNNN-slug.md (+ the DECISIONS.md index line), back-references
  milestone-spawned decisions with proof: pending, and spawns the decision-summarizer to
  refresh the derived documentation/<topic>.md digests. Trigger on "/decide", "let's decide",
  "record this decision", "we need to settle…", or when another trajectory skill routes a
  decision here (a /land contradiction, an /enrich gate, a /kickoff foundational batch). Do
  NOT trigger for read-only lookups of existing decisions.
argument-hint: <statement to decide | existing decision id | empty for the next open item>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent, AskUserQuestion
---

# Decide — One Decision, Understood Then Persisted

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS`. Three entry modes:

- **A statement** ("use SQLite", "we should decide how errors surface") → new decision, start the dialog from it.
- **An existing decision reference** (an id, filename, or "revisit the storage decision") → revision mode (below).
- **Empty** → pick up the next open decision item: find the lowest-id open milestone (`bash ../_shared/scripts/backlog.sh by-status milestone open`, relative to this skill's directory), read its `## Decisions to make` list, and take the first unchecked item (one without a `decision: NNNN` back-reference). If several milestones have open items, stay with the lowest id unless the user redirects; if none exist anywhere, say so and stop.

## The dialog (kept brief)

The point is shared understanding *before* persistence, not ceremony. A few focused exchanges:

1. **What is actually being decided?** State the decision as a single sentence the user confirms. If the statement hides several decisions, split them — one record each, worked serially.
2. **What does it depend on?** Read `documentation/DECISIONS.md` and the relevant `documentation/<topic>.md` digests first — never re-open what an accepted decision already settles; a conflict with an existing record is revision/supersession territory, name it.
3. **What are the real alternatives, and why this one?** Ground rationale in what was actually discussed — never fabricate alternatives for the record's sake.
4. **Consequences** — what this forecloses, what it commits the project to, what it makes cheap.

**How to ask** (see [Asking the user](../_shared/workflow-overview.md#asking-the-user)): step 3 is this skill's natural `AskUserQuestion` moment — once the alternatives are on the table, put them up as the options (your recommendation first, each description carrying its trade-off) and let the user pick. The **`preview` field** earns its keep here when the alternatives are concrete artifacts — competing schema shapes, config layouts, API signatures — so the user compares the actual bytes side by side rather than two adjectives. Only ever offer alternatives that were genuinely surfaced: padding the list to four fabricates rationale for the record, which is exactly what step 3 forbids. Steps 1, 2, and 4 stay in prose — framing what is being decided, and drawing out consequences, is open work.

## Persist

Create the record: `bash ../_shared/scripts/backlog.sh new decision <slug> <title>`, fill `## Context`, `## Decision`, `## Rationale`, `## Consequences` (and `## Proof` when the decision carries a proof obligation — see below) via Edit, and set the status the dialog earned — normally `backlog.sh set-status decision <id> accepted` (leave `proposed` only when the user explicitly wants it parked).

**Milestone-spawned decisions:** when the decision came from a milestone's list —

- From `## Decisions to make`: tick the item and append the back-reference: `- [x] <item> — decision: NNNN`.
- From `## Needs proving`: the record is persisted with **`proof: pending`** (`backlog.sh set-proof <id> pending`) and the milestone item gets the same `— decision: NNNN` back-reference. This wires the proving loop: `/enrich` will attach the id to a proving task's `proves` list, and `/land` clears it after consulting the user.

### The proof claims

Every `proof: pending` decision gets a **`## Proof` claim list** — one checklist line per thing a running system has to demonstrate before the obligation is discharged:

```markdown
## Proof
- [ ] <claim, in the observable terms someone could check> — <how it will be demonstrated>
```

**Decompose the decision statement clause by clause.** A decision sentence almost always carries several claims ("*the CLI reads layered config, binds both ports, and serves; port 443 terminates TLS…*" is four or five), and they usually get demonstrated by *different* tasks at *different* times — commonly one through the library API and another only through the actual entry point. One claim per clause, and where a clause could be satisfied through more than one surface, say which surface counts. Claims phrased so a reader can only answer yes/no are the point; a claim that restates the whole decision proves nothing.

The claim list is what `/enrich` wires tasks against and what `/land` ticks one at a time. `backlog.sh set-proof <id> proven` refuses while any claim is unticked, and `milestone-ready` reports a decision whose proving task is done but whose claims are open as a blocker — so a part-proven decision cannot be closed wholesale. A `proof: pending` record with no claims is a standing `check`/board warning.

On **supersession**, the new record carries the old one's *unticked* claims (the ticked ones were demonstrated and stay demonstrated on the historical record); on **revision**, re-check the claim list against the revised statement — a revision that widens the decision usually adds claims.

Update the index: add/refresh the one-liner in `documentation/DECISIONS.md` (`- NNNN-slug.md — [status] <one-sentence summary>`).

## Revision mode

For an existing decision, the dialog identifies **what needs to change and why** — new evidence, a contradiction surfaced by a proving task (routed here by `/land`), or drifted context. Understand the *why* in prose; then settle the outcome with `AskUserQuestion`, since it is a clean closed set (*revise the record in place* / *supersede with a new decision* / *the record stands, no change*) with materially different consequences per branch. Two outcomes:

- **Revision** — the decision stands, its record was wrong or incomplete: edit the record in place, note the revision and its trigger in the body, refresh the index line.
- **Supersession** — the decision itself changes: create the new record (as above, carrying the old one's proof obligation if evidence hasn't settled it), then `backlog.sh set-superseded <old-id> <new-id>` and update both index lines. Never edit the superseded record's content — it stays as the historical account.

If tasks link the old decision (`backlog.sh` — check `decisions`/`proves` via `get` on ids the user suspects, or grep DECISIONS.md discussion), point open ones out so the user can decide whether their plans still hold.

## Derived digests + wrap-up

Spawn the `decision-summarizer` subagent with the documentation directory and the id(s) just recorded/revised/superseded — the per-topic digests are never authored by hand. Then run `bash ../_shared/scripts/backlog.sh check`. Do **not** commit — this skill runs in the foreground; name the files touched (decision file(s), `DECISIONS.md`, topic digests, the milestone file if back-referenced) and leave them for the user to review and commit (`/commit`).

Close by naming what unblocked: if the milestone's `## Decisions to make` list is now fully ticked, `/enrich` is open; if more items remain, offer the next one (`/decide` argless continues).
