---
name: supplement
description: >
  Add a small milestone-less task to a trajectory backlog — a bug, a small improvement, a
  chore — with the same rigor as /enrich: plan, decision/doc references, complexity,
  dependencies, acceptance criteria, duplicate/link scan, and vocabulary check, including
  proposing a breakdown into several tasks when the input turns out bigger than one
  well-shaped task. Trigger on "/supplement", "file a bug task", "small task:", "add a chore",
  or when the user hands over a fix/improvement that doesn't warrant a milestone. Do NOT
  trigger for milestone-scoped breakdown (that's /enrich) or for feature-sized ideas (route
  those to /aim).
argument-hint: <the bug, improvement, or chore to capture>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent
---

# Supplement — Small Tasks, Same Rigor

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument: `$ARGUMENTS` — the bug, improvement, or chore. If empty, ask what needs capturing.

A supplement task differs from an enriched one in exactly one way: `milestones: []`. Everything else — the shaping rigor, the checks, the gates — is identical, because `/burn` and the `grader` treat both the same.

## Shape before persisting

Assess the input first. **If it is bigger than one well-shaped task** (multiple independent outcomes, a hidden design decision, "and also…" chains), propose a breakdown into several tasks — or, when it is actually feature-sized, route it to `/aim` instead. Nothing persists until the shape is agreed; tasks are never split after persistence.

Per task, assemble the same material as `/enrich`:

- **Plan** — concrete steps, files to touch where possible (grounded in the codebase, not guessed).
- **References** — relevant decision ids (`decisions:`; read the `documentation/<topic>.md` digests, and never encode a change that contradicts an accepted decision — route that to `/decide`) and documents (`documents:`).
- **Complexity** — `low | medium | high` (abstract reasoning difficulty; `/burn`'s routing hint).
- **Dependencies** — `depends_on` edges to open tasks where ordering is real.
- **Acceptance criteria** — externally observable, testable; the grader's referent. For a bug: the reproduction that must stop reproducing.

**Duplicate/link scan:** spawn the `task-linker` subagent per task — an open task may already cover the fix; fold its verdict in.

**Vocabulary check:** names, terms, and acceptance criteria must use `VISION.md`'s `## Vocabulary`; a missing term is surfaced (extend via `/kickoff` revision or fix the wording), never a quietly coined synonym.

## Persist

Per task: `bash ../_shared/scripts/backlog.sh new task <slug> <title>` (relative to this skill's directory), Edit frontmatter (`milestones: []`) and body, then `bash ../_shared/scripts/backlog.sh check`, then commit with an explicit pathspec: `git add <files> && git commit -m "supplement: <title>" -- <files>`.

## Wrap-up

Show the board; note where the new task(s) sit in `backlog.sh ready` order (available supplements burn in plain ascending-id order alongside milestone tasks — milestones are labels, not queues).
