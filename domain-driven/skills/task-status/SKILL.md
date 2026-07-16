---
name: task-status
description: >
  Read-only progress report for the domain-driven backlog. Runs the bundled tasks.sh helper to print a board — counts per status, the ready-set (todo tasks whose dependencies are all done), and what is blocked on what — derived live from the task files' frontmatter, never by scanning their bodies. The human-facing front end to the tasks.sh query surface every other domain-driven skill uses.
argument-hint: "[<context>]   (optional — filter the board to one bounded context)"
model: sonnet
allowed-tools: Read, Bash(bash */skills/task-status/tasks.sh *), Bash(for *), Bash(if *)
---

# Task Status — Backlog Board

You produce a read-only snapshot of the backlog. You never edit anything, and you
never read task bodies — everything comes from the bundled `tasks.sh` helper (in
this skill's own directory), which parses only frontmatter and returns ids/counts.

## Pre-rendered backlog state

The blocks below are the captured stdout of `tasks.sh` queries run **before** this
skill loaded (against the default `./tasks` backlog). They are the source of truth —
do not re-run these same queries; just render them. An empty block means "none in
that category". If the board block shows a `tasks.sh: … not found` error, report
that the backlog tooling (`jq`/`yj`) or the `tasks/` directory is missing and stop.

### Board totals (counts per status)

```
!`bash "${CLAUDE_SKILL_DIR}/tasks.sh" board 2>&1`
```

### Ready-set — todo tasks whose every dependency is `done` (id · [context] · title)

```
!`SH="${CLAUDE_SKILL_DIR}/tasks.sh"; r=$(bash "$SH" ready 2>/dev/null); if [ -z "$r" ]; then echo '(none — no todo has all its deps done)'; else for id in $r; do bash "$SH" get "$id" 2>/dev/null | jq -r '"\(._id)  [\(.context // "")]  \(.title)"'; done; fi`
```

### Blocked todos — todo tasks with at least one unmet dependency (id · title · waiting on)

```
!`SH="${CLAUDE_SKILL_DIR}/tasks.sh"; any=0; for id in $(bash "$SH" by-status todo 2>/dev/null); do b=$(bash "$SH" blockers "$id" 2>/dev/null | tr '\n' ',' | sed 's/,$//'); if [ -n "$b" ]; then any=1; t=$(bash "$SH" get "$id" 2>/dev/null | jq -r '.title'); printf '%s  %s  (waiting on: %s)\n' "$id" "$t" "$b"; fi; done; if [ "$any" = 0 ]; then echo '(none)'; fi`
```

### In progress (id · title) — a task stuck here across runs likely means a crashed `/task-cycle`

```
!`SH="${CLAUDE_SKILL_DIR}/tasks.sh"; ip=$(bash "$SH" by-status "in progress" 2>/dev/null); if [ -z "$ip" ]; then echo '(none)'; else for id in $ip; do bash "$SH" get "$id" 2>/dev/null | jq -r '"\(._id)  \(.title)"'; done; fi`
```

### Drift worklist — done tasks that landed with non-trivial deviations (`deviated: true`), awaiting a `/domain-model` or `/context-mapping` revision

```
!`SH="${CLAUDE_SKILL_DIR}/tasks.sh"; dv=$(bash "$SH" deviated 2>/dev/null); if [ -z "$dv" ]; then echo '(none)'; else for id in $dv; do bash "$SH" get "$id" 2>/dev/null | jq -r '"\(._id)  [\(.context // "")]  \(.title)"'; done; fi`
```

### Split tombstones (id → child ids) — inert; shown for completeness

```
!`SH="${CLAUDE_SKILL_DIR}/tasks.sh"; sp=$(bash "$SH" by-status split 2>/dev/null); if [ -z "$sp" ]; then echo '(none)'; else for id in $sp; do bash "$SH" get "$id" 2>/dev/null | jq -r '"\(._id) -> \(.split_into|join(", "))"'; done; fi`
```

## If a context argument was given

If a `<context>` argument (`$ARGUMENTS`) was supplied, scope the report to that bounded context: run `bash "${CLAUDE_SKILL_DIR}/tasks.sh" by-context <context>` once to get its id set, then present only the pre-rendered rows whose id is in that set. With no argument, report the whole backlog.

## How to present it

Render a compact, human-readable board (a small table is fine; use mermaid, never ASCII art, for any graph). Lead with the totals line, then the ready-set (what to do next), then what's blocked and on what, then anything stuck `in progress` or in a `split` tombstone. Keep it a status report — offer next steps (`/task-refine` if drafts exist, `/task-cycle` if tasks are ready) but do not take them.
