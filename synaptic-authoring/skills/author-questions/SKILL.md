---
name: author-questions
description: Draft multiple-choice questions for a node with tight reference lists, honoring "assessment is feedback, never a gate", then mint ids via `synaptic scaffold question` and write the option/frontmatter. Trigger after a node is drafted, or when the user says "write questions for <node>", "quiz this", "add assessment", "challenge questions", or "/author-questions". Spawns question-smith. Prefers many narrow questions over few sprawling ones; never writes a gating or ranking question.
---

# author-questions — assessment that is feedback, never a gate

You create the multiple-choice **questions** that test a node, honoring Synaptic's assessment
philosophy to the letter. You *propose* via `question-smith`, then mint ids with `cli scaffold`
and write the files. You never invent ids.

## The credo (README.md, AUTHORING_SKILLS.md §3) — non-negotiable
- **Feedback, never a gate.** Clearing a node = answering *all* presented questions at *any*
  correctness. Never write a question, option, or explanation that blocks, ranks, or records a
  pass/fail verdict. A wrong answer only flags the referenced nodes for an optional revisit.
- **Tight reference lists.** A missed question flags **every** node in its `references` for
  revisit, so broad questions cause heavy re-visits. Prefer **one** node per question; two only
  when the question genuinely tests their interaction. Never sprawl across many nodes.
- **Many narrow > few broad.** Distractors are plausible misconceptions, not absurd throwaways.

## Procedure
1. **Spawn `question-smith`** with the node body and its already-cleared prerequisites. It returns
   draft questions with tight `references`, `select`, options + per-distractor rationale, and a
   `breadth_flag` on any list wider than two nodes.
2. **Review**: split or drop any breadth-flagged question. Confirm `select: single` has exactly
   one `correct: true`; `select: multi` scores correct only on exact-set match (design distractors
   accordingly).
3. **Mint + write** — one scaffold call per accepted question:
   ```bash
   synaptic scaffold question <track-dir> <kebab-name>
   ```
   The skeleton has a minted ULID and `TODO` options. Fill `references` (the **minted node ids**),
   `select`, the `options[]` (`text` + `correct`), and the prompt body. **Note:** a question's
   changelog carries **no `significance`** (TRACK_STRUCTURE.md §5.2) — leave the scaffold's plain
   `summary` entry; do not add significance.
4. **Self-check.** Run `author-selfcheck` / `synaptic validate --json`: every `references` id must
   resolve to a real, active node (a question can't reference a retired node). Fix and re-check.

## Hard rules
- Never gate, rank, or record a verdict; clearing is all-answered, any correctness.
- Keep reference lists tight; split anything broad.
- Always `scaffold` for ids; never push or commit.
