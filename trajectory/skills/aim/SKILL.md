---
name: aim
description: >
  Define the next demo of a trajectory project — the next point where something can really
  be shown working to a human: take an idea, bullet points, or an example (or propose the
  next demo yourself when invoked empty), scout the current project state via subagents,
  and write demos/NNNN-slug.md covering the outcome, the scenario a human will walk
  through, what only a human can judge, the decisions to make before breakdown, and what
  needs to be proven. Trigger on "/aim", "next demo", "next milestone", "let's aim at…",
  "what should we build next", "what can we show next", or when the user hands over a
  feature idea to target. Do NOT trigger for task-level capture (that's /enrich or
  /supplement) or for questions about existing demos (answer those with backlog.sh).
argument-hint: <optional idea, bullet points, or example for the next demo>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent, AskUserQuestion
---

# Aim — The Next Demo

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — an idea, a bunch of bullet points, or an example of what the next demo should show. If empty, form your own suggestion: read `VISION.md`, run `bash ../_shared/scripts/backlog.sh board` and `backlog.sh demo-state` (relative to this skill's directory), and propose the demo that most advances the vision from the current state — the user vetoes or redirects before you proceed. Put that proposal up as an `AskUserQuestion` with the 2–4 candidate demos you considered as options (your recommendation first, each description naming what the user would be able to see and what it defers) rather than a single take-it-or-leave-it sentence.

**The aiming question is "what can I show next?"** A demo is a checkpoint worth calling the human over for — something that visibly works end to end, not every small feature. It is not a container for tasks and not a barrier: tasks flow through one dependency graph and only *list* the demos they serve. Size it so the scenario is a handful of steps through the real entry point; if you need a page of steps, it is two demos. Your output is one demo file that `/decide` and `/enrich` can pick up without re-deriving anything.

## Step 1: Scout

Spawn the `aim-scout` subagent with the idea, the repo root, and the path to `backlog.sh`. It returns the current state relevant to the idea, the real entry points a scenario could drive, overlaps with existing demos and tasks, candidate unknowns (decisions to make), candidate proof items, and blockers — without the raw file reads ever landing in this session. For a trivial or greenfield idea where there is nothing to scout, skip it and say so.

## Step 2: Shape the demo (brief dialogue)

Synthesize the idea + scout report and confirm with the user — one focused exchange, not a re-interview:

- **Outcome** — what this demo shows and why it matters, in vision vocabulary.
- **Scenario** — numbered steps a person (or the check) performs through the real entry point, each with the observation that proves it: `1. <action> → <what you see>`. Concrete commands, requests, or clicks, with concrete expected output. Example-first: a step with a real sample value beats an abstract description. This is the contract the check command will automate and the script `/land` will walk the user through.
- **Human check** — what only a person can judge (does the flow feel right, is the wording clear, is it fast enough to not annoy). Short; it may be empty for a purely mechanical demo.
- **Gate** — `flag` (default: a green demo is queued for the human while burning continues) or `hold` (an unattended run stops when it turns green, because the next work depends on the human's verdict — a UX direction, an architecture bet). Ask this as a closed question only when the answer is not obvious.
- **Decisions to make** — the decisions the user needs to make before breakdown can start (from the scout's unknowns + your own reading). Each as a one-line checkbox item. Keep this to forks that would genuinely change what gets built; a choice an agent can make sensibly and the user would rubber-stamp is not an item.
- **Verdict items** — does this demo build on a direction the user has not yet *seen*? If an earlier demo is still red or green (not `shown`) and what this demo builds depends on how the user judges it — the UX direction it tries out, the architecture bet it exercises — that judgment is a decision nobody can make yet. Write it as a decision item marked with the demo it waits on: `- [ ] <what the verdict settles> — after: NNNN`. Until demo NNNN is shown, `/decide` will not take the item, `/enrich` will not break this demo down, and the board reports it as **WAITING** rather than stalled — work is held back on exactly the thing that is unknown, nothing else. Ask the user explicitly when the scout reports an unshown demo the idea builds on; don't add verdict items for demos the idea merely follows in time.
- **Needs proving** — the risky assumptions this demo stands on that only running code can demonstrate. Each as a one-line checkbox item. These two lists are the demo's contract with `/decide` (which turns them into decision records and back-references them) and `/land` (which clears the proofs).

Surface scout-reported overlaps with existing demos/tasks now — the user may want to fold, re-scope, or proceed anyway. That is a closed set: ask it with `AskUserQuestion` (one question per overlap; options *fold into the existing demo* / *narrow this demo to the remainder* / *proceed as scoped*), and keep the shaping of outcome, scenario, decisions, and proof items themselves in prose — they are open discovery, and options would flatten them. See [Asking the user](../_shared/workflow-overview.md#asking-the-user).

## Step 3: Persist

Create the file: `bash ../_shared/scripts/backlog.sh new demo <slug> <title>`, set `gate:` in the frontmatter if it is `hold`, then fill the body via Edit:

```markdown
## Outcome
<what it shows, and why it matters>

## Scenario
1. <action through the real entry point> → <observable result>
2. …

## Human check
- <what only a person can judge>

## Decisions to make
- [ ] <one-line decision item>
- [ ] <what the verdict on an unshown demo settles> — after: NNNN

## Needs proving
- [ ] <one-line proof item>

## Showing
<left empty — /land fills it>
```

Leave `check:` empty when the check does not exist yet — which is the normal case: `/enrich` names the command when it mints the check task, and an empty check keeps the demo red (the board says so). If an existing command can already drive the scenario (a test target, a script), set it now.

Run `bash ../_shared/scripts/backlog.sh check`. Do **not** commit — this skill runs in the foreground; leave the written file for the user to review and commit (`/commit`).

## Wrap-up

Show the board (`backlog.sh board`). Point at the next move: `/decide` if the demo has open decision items (that gate blocks `/enrich`), otherwise `/enrich` directly. If it carries verdict items, say what it waits on: `/land NNNN` for the awaited demo comes first, and the items decidable now can be settled meanwhile.
