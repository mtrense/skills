---
name: author-questions-cycle
description: Draft questions for every drafted-but-unquestioned node in a track by fanning question-smith subagents across nodes in parallel batches, then centrally minting question ids and writing the files. The batch counterpart to author-questions — the same drafter contract, run many-at-once, honoring "assessment is feedback, never a gate". Trigger after a batch of nodes is drafted, or when the user says "write questions for the whole track", "quiz everything", "add assessment to all nodes", "question the remaining nodes", or "/author-questions-cycle". Resumable and idempotent — each pass only picks up nodes that have no questions yet.
argument-hint: "[max-nodes][@workers]   (e.g. `10`, `10@6`, `@6`; defaults: no cap, 4 workers)"
model: opus
allowed-tools: Read, Write, Edit, Glob, Grep, Agent, Bash(synaptic scaffold:*), Bash(synaptic validate:*), Bash(git status:*)
---

# author-questions-cycle — parallel question authoring

You drive a track's **drafted-but-unquestioned nodes** to having assessment by invoking the
`question-smith` subagent once per node, in parallel batches across distinct nodes. Each smith drafts
tight-referenced multiple-choice questions inside its own context and returns them; **you** mint the
question ids via `synaptic scaffold question` and write the files. Minting is centralized here — never
inside the parallel smiths — so the id space stays clean and no two smiths race to scaffold.

Same motivation as `author-questions`, at scale: **context hygiene** (each node's body + prereqs and
the question drafts live in the forks) and **wall-clock speed** (independent nodes are questioned
concurrently). The orchestrator stays small.

## Prerequisites
1. A track directory containing `track.toml` (ask if ambiguous). Bind it as `<track-dir>`.
2. At least one node that is **drafted** (no `TODO:` body/grounding) but has **no question**
   referencing it yet. If none, stop and say so.
3. Clean working tree — the `git status --porcelain` at load time is injected below; if non-empty,
   stop and ask the human to commit or stash first. Do not re-run it for the initial check.

   ```
   !`git status --porcelain`
   ```

## Arguments — `$ARGUMENTS`
Shape `[<total>][@<workers>]`, same grammar as the other cycles:
- *empty* → no cap, 4 workers.  `N` → cap N nodes, 4 workers.  `N@W` → cap N, W workers.
  `@W` → no cap, W workers.

Anything else → halt and state the expected shape. Bind `<total>` and `<workers>`.

## Loop
Repeat until a stop condition triggers.

### Step 1 — Enumerate unquestioned nodes
Identify **drafted** nodes (id'd node files with no `TODO:` body/grounding placeholder) that no
existing question `references`. `Grep` the track's question files for each node's `id`; a node absent
from every question's `references` is unquestioned. Produce the list of `(node_id, node_path)`. If
empty, exit the loop (success → Step 5).

### Step 2 — Build the next batch
A batch is a set of **distinct** nodes. Take the first `<workers>` unquestioned nodes (default 4). If
`<total>` is set and you're near it, shrink the batch so you don't overshoot.

### Step 3 — Spawn the batch in parallel
Issue one `Agent` call per node **in a single message** so the smiths run concurrently:
`Agent(subagent_type="question-smith", …)` passing the node's body and its **already-cleared
prerequisites** (question-smith needs both). Wait for all to return.

### Step 4 — Vet, mint, and write
For each returned proposal (halt the loop on structural failure):
1. **Honor the credo.** Reject any question, option, or explanation that gates, ranks, or records a
   pass/fail verdict. Split or drop any question whose `breadth_flag` fired (reference list wider
   than two nodes) — keep reference lists tight.
2. **Shape check.** `select: single` has exactly one `correct: true`; `select: multi` scores only on
   exact-set match (its distractors must be designed for that).
3. **Mint + write, centrally and sequentially** — one scaffold call per accepted question:
   ```bash
   synaptic scaffold question <track-dir> <kebab-name>
   ```
   Fill `references` (the **minted node ids**), `select`, `options[]` (`text` + `correct`), and the
   prompt body. A question's changelog carries **no `significance`** — leave the scaffold's plain
   `summary` entry.

If `<total>` is set and you've reached it, exit after this batch. Otherwise log a one-line note per
node (e.g. `✓ err-retry-basics — 3 questions`) and loop to Step 1.

### Step 5 — Validate and summarize
1. Run `synaptic validate <track-dir> --json` (or invoke `author-selfcheck`): every question's
   `references` id must resolve to a real, active node (a question can't reference a retired node).
   Report validity in the CLI's own terms; name any failures and don't hand off a broken tree.
2. Print a compact summary: nodes questioned this cycle (count + example question counts), any
   questions **split or dropped** for breadth, nodes still unquestioned (count), and any halt reason.
3. Suggest next steps: `author-gap-scan` and `author-selfcheck` before hand-off.

Remind the human to review the diff and run `/commit`. Never commit or push.

## Hard rules
- **Never gate, rank, or record a verdict** — clearing a node is all-answered, any correctness.
- **Reference lists stay tight** — one node per question, two only for a genuine interaction; split
  anything broader.
- **Minting is centralized.** The parallel smiths only *propose*; the orchestrator scaffolds every
  question id. This is why questioning fans out safely.
- **Context hygiene is half the point.** Don't draft questions yourself — the smiths do that in
  discarded contexts. You hold proposals, the mint calls, and the write loop.
- **Idempotent.** Re-running re-derives the unquestioned set, so a node already covered is skipped
  and a partial run resumes cleanly.
- **No commits.** The human reviews and runs `/commit`.
