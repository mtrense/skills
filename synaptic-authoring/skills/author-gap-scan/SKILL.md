---
name: author-gap-scan
description: Audit an existing or proposed track DAG for foundational gaps — concepts referenced but never taught, orphan roots that assume prior knowledge, prerequisite leaps, redundant nodes, and dangling supplementary references. Produces a prioritized gap report and an authoring plan to close them. Trigger after author-structure, before a milestone hand-off, or when the user says "gap scan", "coverage check", "what's missing", "any foundational gaps", or "/author-gap-scan". Spawns coverage-auditor. Read-only analysis — proposes fixes, edits nothing.
---

# author-gap-scan — foundational-gap audit

You find the gaps that make self-teaching fail — the exact failure the product exists to prevent
(README.md: a learner uses something for months yet can't explain a foundational concept it rests
on). You analyze and report; you do not edit the graph or draft nodes.

## Procedure
1. **Spawn `coverage-auditor`** on the track directory (or a `concept-mapper` proposal). It
   returns findings keyed to node ids/handles: untaught concepts, orphan roots, prerequisite
   leaps, redundancy, dangling supplementary refs, and motivation gaps.
2. **Prioritize.** Rank by learner impact — **untaught-concept** and **prereq-leap** findings are
   top priority (they are the silent gaps); redundancy and dead-weight glossary terms are lower.
3. **Turn findings into an authoring plan**, not just a list:
   - untaught concept → "add a root/intermediate node teaching X; wire it as a prerequisite of Y".
   - orphan root assuming prior knowledge → "either add the missing prerequisite node, or confirm
     this is a legitimate entry point."
   - prereq leap → "insert an intermediate node between src and dst."
   - redundancy → route to `author-restructure` (merge is a restructure, not an ad-hoc delete —
     the directory only grows; pieces are tombstoned, never removed).
   - motivation gap → route to `author-snippet` to add *why it matters / what it unlocks*.
4. **Draw the boundary with the CLI.** The deterministic `synaptic validate` catches *structural*
   breakage (unresolved ids/slugs, cycles). This skill catches the *pedagogical* gaps validate
   cannot see — a graph can be perfectly valid and still teach a concept it never grounded. Say
   which findings the CLI would also catch and which are yours alone.

## Output
A prioritized gap report + a concrete authoring plan (which nodes to add and where to wire them),
handed to the human. Loop back to `author-structure` to add the missing nodes, then re-scan.

## Hard rules
- Read-only: propose fixes; never edit the DAG, mint ids, or delete anything.
- Never push or commit.
