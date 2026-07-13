---
name: task-append
description: >
  Capture a task into the backlog as a new `draft`, from human input of ANY
  quality — a polished spec or a half-formed brain-dump both welcome. Mints the
  next id via the tasks.sh helper, writes tasks/NNNN-slug.md with minimal
  frontmatter, and does NOT interview or refine (that is /task-refine's job). The
  low-friction front door to the domain-driven backlog.
disable-model-invocation: true
argument-hint: "<the idea, in any form — a sentence, a paragraph, a dump>"
model: sonnet
allowed-tools: Read, Write, Bash(mkdir -p tasks), Bash(bash */skills/task-status/tasks.sh *), Bash(date *)
---

# Task Append — Capture a Draft

You capture one task into the backlog as a `draft`. **This is a capture step, not
a design step.** Do not interview, do not assess completeness, do not add
dependencies or a context — `/task-refine` does all of that. Your job is to get
the human's idea onto disk faithfully and with the least friction, so nothing is
lost in the moment it occurs to them.

Raw, incomplete, or unpolished input is explicitly fine. If the human hands you a
one-liner, capture the one-liner. If they hand you a rambling brain-dump, preserve
it. Never demand more before saving.

## Steps

1. **Ensure the backlog exists:** `mkdir -p tasks`.
2. **Mint the id:** run `bash <skills-root>/task-status/tasks.sh next-id` (the
   helper is a sibling skill directory; `<skills-root>` is the directory this
   skill lives in). Use the returned 4-digit id.
3. **Derive a title and slug.** Make a short imperative title from the input
   (invent a reasonable one if the input is a raw dump). The slug is the title
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

## Why this matters
<if the human said; otherwise leave a TODO for /task-refine>

## Acceptance criteria
<if the human gave any; otherwise leave a TODO for /task-refine>

## Notes
<the raw input, verbatim, if it was unstructured>
```

Write `id`, `status`, and `context` as quoted strings; keep `depends_on`,
`related_adrs`, `related_documents`, and `split_into` as JSON-style lists (the
tasks.sh helper normalizes either form, but quoting ids avoids YAML octal
surprises).

## After writing

Confirm in one line: the id, the title, and that it is a `draft`. Remind the human
that `/task-refine` will turn it into a ready `todo` (interviewing them, sizing it,
wiring dependencies, and checking it against the domain). Do not refine it now.
