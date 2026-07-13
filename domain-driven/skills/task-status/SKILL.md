---
name: task-status
description: >
  Read-only progress report for the domain-driven backlog. Runs the bundled
  tasks.sh helper to print a board — counts per status, the ready-set (todo tasks
  whose dependencies are all done), and what is blocked on what — derived live from
  the task files' frontmatter, never by scanning their bodies. The human-facing
  front end to the tasks.sh query surface every other domain-driven skill uses.
argument-hint: "[<context>]   (optional — filter the board to one bounded context)"
model: sonnet
allowed-tools: Read, Bash(bash */skills/task-status/tasks.sh *)
---

# Task Status — Backlog Board

You produce a read-only snapshot of the backlog. You never edit anything, and you
never read task bodies — everything comes from the bundled `tasks.sh` helper (in
this skill's own directory), which parses only frontmatter and returns ids/counts.

## What to run

Let `SH = <this-skill-dir>/tasks.sh` and default the tasks dir to `./tasks`.

1. **Board totals:** `bash "$SH" board` → counts per status.
2. **Ready-set:** `bash "$SH" ready` → the tasks that could be worked right now
   (todo with all deps done). For each, you may `bash "$SH" get <id>` for its title.
3. **Blocked todos:** the `todo` ids (`bash "$SH" by-status todo`) not in the
   ready-set are blocked; for each, `bash "$SH" blockers <id>` names the unmet
   dependencies.
4. **In progress:** `bash "$SH" by-status "in progress"` (a task stuck here across
   runs likely means a crashed `/task-cycle` — flag it).
5. If a `<context>` argument was given, additionally run `bash "$SH" by-context
   <context>` and scope the report to those ids.

## How to present it

Render a compact, human-readable board (a small table is fine; use mermaid, never
ASCII art, for any graph). Lead with the totals line, then the ready-set (what to
do next), then what's blocked and on what, then anything stuck `in progress` or in
a `split` tombstone. Keep it a status report — offer next steps (`/task-refine`
if drafts exist, `/task-cycle` if tasks are ready) but do not take them.
