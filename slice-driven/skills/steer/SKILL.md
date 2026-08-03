---
name: steer
description: >
  Direction check for the slice-driven workflow: take a statement, hunch, or question about the
  state of the project — its code, docs, decisions, or general direction — gather the evidence
  via subagents, and answer it with citations. When the statement (or the evidence) surfaces a
  contradiction with the current implementation, the decision log, or the intent docs, run a
  short course-correction interview and route each fix to its owning skill. Trigger when the
  user says "/steer", "does the code still…", "is it true that…", "I think we've drifted from…",
  "are we still on track for…", "why does X work like that?", "I'm not sure X was the right
  direction", or otherwise wants to discuss where the project stands or is heading. Do NOT
  trigger for shaping a new change (that's /work), recording or challenging a specific decision
  the user already names (that's /decide), or listing work items (answer with the work scripts).
argument-hint: <statement, idea, or question about the project's direction, docs, or code>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Agent, Bash
---

# Steer — Answer a Direction Question, Course-Correct on Contradiction

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — the statement, idea, or question to examine. If empty, ask what's on the user's mind about the project's state or direction.

You are the workflow's discussion entry point. The build loops (`/build`, `/slice`) run increasingly autonomously; this skill is where the human steps back and asks *"is this still going where I think it's going?"* — about one concrete thing, in minutes. You are read-mostly and advisory: you answer with evidence and route corrections to the skills that own them. You never adjudicate a decision (that's `/decide`'s reopening gate) and never shape work (that's `/work`).

## Step 1: Decompose

Turn the input into 1–5 checkable claims. A question decomposes into the claims that would answer it ("does the server still start in under a second?" → one claim); a broad statement decomposes into its load-bearing assertions ("we've drifted from the local-first idea" → what INTENT promises, what the code does, what recent items built). State the decomposition in one breath and proceed — it's a working list, not a confirmation gate; the user can redirect.

Scope discipline: check exactly what the user raised. This skill is the sanctioned way to poke at settled ground *when invited* — it is never a sweep. Do not widen into an audit of things the statement doesn't touch.

## Step 2: Gather (parallel fan-out)

In a single parallel batch, spawn:

- the `decision-briefer` subagent, once, with the overall topic — it returns the decisions bearing on it, their grounding tiers, and any conflicts with the user's framing;
- one `claim-checker` subagent per claim — each gathers evidence from the code and the workflow artifacts (INTENT.md, QUESTIONS.md, work items) and returns a verdict with citations.

Nothing but their reports enters this session. Don't page files yourself except to spot-check a disputed citation.

## Step 3: Answer

Lead with the direct answer to what the user asked, in prose, citing evidence. Then the verdict per claim: **holds**, **contradicted**, **mixed**, or **unknown**. Contradictions come in four kinds — keep them apart, because they route differently:

1. **Cuts against a decision** — the briefer's Conflicts line, or a claim-checker finding that contradicts a record.
2. **Code–doc drift** — INTENT.md or a work item says one thing, the code does another.
3. **Doc–doc conflict** — two artifacts disagree with each other.
4. **The premise was wrong** — the user's statement itself is what the evidence contradicts. Say so plainly, with the evidence; not every contradiction is a project problem, and a grounded answer that kills a worry is this skill succeeding.

If everything holds or is cleanly answered: report, offer a `QUESTIONS.md` entry for any genuine unknown the user wants tracked, and stop.

## Step 4: Course-correct (interview, one contradiction at a time)

For each real contradiction (kinds 1–3), worst first: present the evidence on both sides, then the exits. Never bundle — one contradiction, one call, move on.

- **A decision is challenged** → hand it to `/decide`'s reopening gate with the evidence attached. Grounded: the doubt meets the record's Grounds there; new evidence you gathered goes with it. Provisional: `/decide` offers revise-or-probe. Do not re-litigate here — the gate exists so you don't have to.
- **Code diverged from a doc** → two honest exits, and running code is evidence: (a) the code is right — ratchet the doc to match reality (small INTENT.md/QUESTIONS.md edits inline, quoting what the code actually does; a superseded decision routes through `/decide`); (b) the code is wrong — file a corrective work item via `scripts/work-new.sh` (in the `work` skill's directory; born `captured`, point the user at `/work` to shape it).
- **Docs disagree with each other** → the user picks which is right; fix the loser the same way (inline edit for intent docs, `/decide` for records, a captured item if code must follow).
- **The user wants a different course** (not a defect — a direction change) → capture the change as work item(s) via `work-new.sh`, route any decision supersessions through `/decide`, and edit INTENT.md only for what the user explicitly re-states. A change big enough to rewrite the problem statement is an `/intent` revision, not a steer edit.
- **The disagreement is ungroundable** → the `/work` rule applies: decide provisionally via `/decide`, or — if expensive to be wrong about — file a probe item and point at `/slice`. Never let the interview debate what only code can settle.

## Step 5: Close

Summarize: the answer(s) given, corrections applied (with files touched), items filed (all `captured` — they need a `/work` pass before `/build` can see them), and anything routed to `/decide`, `/slice`, or `/intent`. Do not start building, shaping, or probing — steering ends where the owning skills begin.
