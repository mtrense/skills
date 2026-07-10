---
name: author-structure
description: Propose the track DAG — a node list, prerequisite edges, and priority ordering — from a corpus of reference/ material plus a track goal, then mint ids for the accepted nodes via `synaptic scaffold node`. Enforces acyclic, AND-semantics, single-track structure and explains each edge's rationale. Trigger after author-ingest, or when the user says "structure the track", "build the DAG", "propose nodes/prerequisites", "outline the track", or "/author-structure". Spawns concept-mapper. Proposes only until the human approves; then scaffolds.
---

# author-structure — the prerequisite DAG

You design the track's **directed acyclic graph of prerequisites** — the product's core
differentiator (README.md). You *propose* the graph, the human *approves*, and only then do you
call `cli scaffold` to mint ids. You never invent ids and never write final node prose here.

## Procedure
1. **Spawn `concept-mapper`** with the `reference/` corpus (and the units manifest from
   `author-ingest`) plus the track goal. It returns a proposed node list, edges with per-edge
   rationale, a priority ordering, an acyclicity self-check, and `missing_foundations`.
2. **Review the proposal against the rules** (TRACK_STRUCTURE.md, README.md):
   - **Acyclic** — if concept-mapper reports a cycle, resolve it *with the human* before minting.
   - **AND-semantics** — every prerequisite gates the learner until *all* are cleared. Keep the
     prerequisite set of each node **minimal**; drop "related but not required" edges.
   - **Single track, no cross-track edges**; multi-root is fine.
   - **Priority is a whisper** — it only orders the available set on the dashboard, never gates.
     Never encode required order as priority; encode it as an edge.
   - **Every node must state why it matters and what it unlocks** — reject nodes that don't.
   - **Close `missing_foundations`** — add root nodes for concepts depended on but not taught.
     This is the whole point: no silent prerequisite gaps.
3. **Render for approval.** Present the node list + an edge table (`src -> dst — rationale`) + a
   text rendering of the graph. (`synaptic visualize` is not implemented yet — render the graph
   as a mermaid `flowchart` or an indented tree by hand; do not call a nonexistent command.)
4. **On approval, mint ids** — one scaffold call per accepted node:
   ```bash
   synaptic scaffold node --kind <knowledge|exercise> <track-dir> <topic/kebab-name>
   ```
   This writes a skeleton with a freshly minted ULID and `TODO:` placeholders (title, grounding
   ref, body). Then set each node's `prerequisites:` to the **minted ids** of its prereqs, and set
   `priority`. Prerequisite edges carry no id of their own — they are just the `prerequisites`
   list on the dependent node.
5. **Hand off to drafting.** The nodes now exist as valid skeletons *except* their grounding ref
   and body are still `TODO` — so `synaptic validate` will fail until `author-snippet` fills them.
   That is expected. Point the user at `author-gap-scan` (to confirm no gaps) then `author-snippet`.

## Hard rules
- Never hand-write an id; always `scaffold`. Never push or commit.
- Keep edges minimal and justified; the DAG stays acyclic and single-track.
- Do not draft learner prose here — only structure + scaffolded skeletons.
