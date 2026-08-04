---
name: aim
description: >
  Define the next milestone of a trajectory project: take an idea, bullet points, or an
  example (or propose the next feature yourself when invoked empty), scout the current
  project state via subagents, and write milestones/NNNN-slug.md covering the outcome, the
  decisions to make before breakdown, and what needs to be proven. Trigger on "/aim", "next
  milestone", "let's aim at…", "what should we build next", or when the user hands over a
  feature idea to target. Do NOT trigger for task-level capture (that's /enrich or
  /supplement) or for questions about existing milestones (answer those with backlog.sh).
argument-hint: <optional idea, bullet points, or example for the next milestone>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent, AskUserQuestion
---

# Aim — The Next Target

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — an idea, a bunch of bullet points, or an example of what the next milestone should achieve. If empty, form your own suggestion for the next feature to go for: read `VISION.md`, run `../_shared/scripts/board.sh`-equivalent `bash ../_shared/scripts/backlog.sh board` (relative to this skill's directory) and `backlog.sh milestone-ready`, and propose the target that most advances the vision from the current state — the user vetoes or redirects before you proceed. Put that proposal up as an `AskUserQuestion` with the 2–4 candidate targets you considered as options (your recommendation first, each description naming what it advances and what it defers) rather than a single take-it-or-leave-it sentence.

A milestone is a **grouping and labelling device** for tasks — never a barrier or synchronization point. Your output is one milestone file that `/decide` and `/enrich` can pick up without re-deriving anything.

## Step 1: Scout

Spawn the `aim-scout` subagent with the idea, the repo root, and the path to `backlog.sh`. It returns the current state relevant to the idea, overlaps with the existing backlog, candidate unknowns (decisions to make), candidate proof items, and blockers — without the raw file reads ever landing in this session. For a trivial or greenfield idea where there is nothing to scout, skip it and say so.

## Step 2: Shape the milestone (brief dialogue)

Synthesize the idea + scout report and confirm with the user — one focused exchange, not a re-interview:

- **Outcome** — what this milestone achieves, its outcome and benefit, in vision vocabulary.
- **Decisions to make** — the decisions the user needs to make before breakdown and implementation can start (from the scout's unknowns + your own reading). Each as a one-line checkbox item.
- **Needs proving** — the risky assumptions this milestone stands on that only running code can demonstrate. Each as a one-line checkbox item. These two lists are the milestone's contract with `/decide` (which turns them into decision records and back-references them) and `/land` (which clears the proofs).

Surface scout-reported overlaps with open milestones/tasks now — the user may want to fold, re-scope, or proceed anyway. That is a closed set: ask it with `AskUserQuestion` (one question per overlap; options *fold into the existing milestone* / *narrow this milestone to the remainder* / *proceed as scoped*), and keep the shaping of outcome, decisions, and proof items themselves in prose — they are open discovery, and options would flatten them. See [Asking the user](../_shared/workflow-overview.md#asking-the-user).

## Step 3: Persist

Create the file: `bash ../_shared/scripts/backlog.sh new milestone <slug> <title>`, then fill the body via Edit:

```markdown
## Outcome
<what it achieves, outcome and benefit>

## Decisions to make
- [ ] <one-line decision item>

## Needs proving
- [ ] <one-line proof item>

## Breakdown
<left empty — /enrich fills it with the coverage map>

## Landing
<left empty — /land fills it>
```

Leave `## Breakdown` empty but present: it is the coverage map `/enrich` writes (one line per element of the outcome → the tasks covering it), and `milestone-ready` treats a milestone that has tasks but no coverage map as OPEN. Do not pre-fill it with guesses — breakdown is `/enrich`'s job.

Run `bash ../_shared/scripts/backlog.sh check`. Do **not** commit — this skill runs in the foreground; leave the written file for the user to review and commit (`/commit`).

## Wrap-up

Show the board (`backlog.sh board`). Point at the next move: `/decide` if the milestone has open decision items (it usually does — that gate blocks `/enrich`), otherwise `/enrich` directly.
