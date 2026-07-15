---
name: task-append
description: >
  Capture one or more tasks into the domain-driven backlog as new `draft`s from
  human input of ANY quality — a polished spec or a half-formed brain-dump both
  welcome. Trigger whenever the user wants to record, capture, add, jot down, or
  "note for later" a task, idea, feature, or piece of work into the backlog — e.g.
  "add a task to…", "capture this…", "put this on the backlog", "we should also…",
  "remember to…", "new task:", or /task-append. Accepts several tasks at once when
  the input is split by markdown document delimiters (a line containing only `---`)
  — each block becomes its own draft. Mints the next id per task via tasks.sh,
  writes tasks/NNNN-slug.md with minimal frontmatter, and does NOT interview,
  size, or wire dependencies (that is /task-refine's job). The low-friction front
  door to the backlog. Requires a tasks/ backlog (domain-driven workflow); do NOT
  trigger for read-only backlog questions ("what's next?", "what's the status?" —
  those are /whats-next and /task-status), for refining an existing task, or for
  ad-hoc code edits.
argument-hint: "<the idea(s), in any form — one dump, or several separated by --- lines>"
model: sonnet
allowed-tools: Read, Write, Bash(mkdir -p tasks), Bash(bash */skills/task-status/tasks.sh *), Bash(date *)
---

# Task Append — Capture Draft(s)

You capture one or more tasks into the backlog as `draft`s. **This is a capture
step, not a design step.** Do not interview, do not assess completeness, do not add
dependencies or a context — `/task-refine` does all of that. Your job is to get
the human's idea(s) onto disk faithfully and with the least friction, so nothing is
lost in the moment it occurs to them.

Raw, incomplete, or unpolished input is explicitly fine. If the human hands you a
one-liner, capture the one-liner. If they hand you a rambling brain-dump, preserve
it. Never demand more before saving.

## Splitting the input into tasks

First decide how many tasks the input holds. **A line containing only `---`
(a markdown document delimiter) separates one task from the next.** Split the input
on such lines into blocks, trim surrounding blank lines from each block, and drop
any empty blocks. Each remaining block is one task. Input with no `---` delimiter
is a single task — the common case.

Then run the steps below **once per block**, minting a fresh id for each (mint →
write → mint the next), so each task lands in its own `tasks/NNNN-slug.md`.

## Steps (per task block)

1. **Ensure the backlog exists:** `mkdir -p tasks` (only needed once).
2. **Mint the id:** run `bash <skills-root>/task-status/tasks.sh next-id` (the
   helper is a sibling skill directory; `<skills-root>` is the directory this
   skill lives in). Use the returned 4-digit id. Because `next-id` is derived from
   the files on disk (max existing id + 1), always mint the id *after* the previous
   task's file has been written, so each task gets a distinct id.
3. **Derive a title and slug.** Make a short imperative title from the block
   (invent a reasonable one if the block is a raw dump). The slug is the title
   lowercased, non-alphanumerics collapsed to single hyphens.
4. **Get the timestamp:** `date -u +%Y-%m-%dT%H:%M:%SZ`.
5. **Write** `tasks/NNNN-slug.md` with exactly this shape:

```markdown
---
id: "NNNN"
title: <title>
status: draft
context: ""
created: <ISO8601 UTC>
completed: ""
depends_on: []
related_adrs: []
related_documents: []
split_into: []
---

## Outcome
<what the human wants to be true when this is done — restate their input; if it
was a raw dump, capture it verbatim under a "Raw capture" note below rather than
polishing it away>

### Why this matters
<if the human said; otherwise leave a TODO for /task-refine>

### Acceptance criteria
<if the human gave any; otherwise leave a TODO for /task-refine>

## Notes
<the raw input, verbatim, if it was unstructured>

## Closing
<filled at implementation by /task-cycle — leave as-is>

### Manual testing
<filled at implementation by /task-cycle — leave as-is>

### Deviations from plan
<filled at implementation by /task-cycle — leave as-is>
```

Write `id`, `status`, and `context` as quoted strings; keep `depends_on`,
`related_adrs`, `related_documents`, and `split_into` as JSON-style lists (the
tasks.sh helper normalizes either form, but quoting ids avoids YAML octal
surprises).

## After writing

Confirm each captured task in one line: its id, its title, and that it is a
`draft` (one line per task when several were captured). Then remind the human once
that `/task-refine` will turn each into a ready `todo` (interviewing them, sizing
it, wiring dependencies, and checking it against the domain). Do not refine them
now.
