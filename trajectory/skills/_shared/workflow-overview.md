# Trajectory Workflow — Shared Overview

Read this to understand where the current skill sits in the family. Trajectory is a milestone-labelled, proof-driven build workflow: milestones group and label tasks (they are never barriers or synchronization points), decisions carry an explicit proof obligation, and a scripted helper answers every mechanical question so no skill ever scans the backlog.

## The story

```
/kickoff (once, re-entrant)                → VISION.md (+ ## Vocabulary)
   ↓
/aim        idea → milestone               → milestones/NNNN-slug.md
   ↓
/decide     settle the milestone's open decisions   → documentation/decisions/NNNN-slug.md
   ↓
/enrich     milestone → well-shaped tasks  → tasks/NNNN-slug.md
   ↓
/burn       parallel TDD workers burn the available set down
   ↓
/land       verify the milestone against its goal, clear proofs, update docs
```

`/supplement` sits outside the milestone flow: it captures small milestone-less tasks (bugs, chores, improvements) with the same rigor as `/enrich`. `/decide` is also invoked out-of-band whenever a decision is made, challenged, or contradicted by evidence.

## The proving loop (the signature move)

`/aim` writes "what needs to be proven" into the milestone → `/decide` turns each item into a decision with `status: accepted, proof: pending` and back-references it from the milestone item (a `decision: NNNN` marker on the item line) → `/enrich` attaches the decision id to the `proves` list of the task(s) that will demonstrate it (a task in a later milestone may prove an earlier milestone's decision) → when `/land` finds every proving task done, it consults the user and flips the decision to `proof: proven`. A decision whose proving task surfaces contradicting evidence is never silently edited — `/land` routes it back to `/decide <id>` for revision or supersession. A `proof: pending` decision with no live proving task is a board-level warning, never silently dropped.

## Project artifacts

| Path | Role | Owner |
|------|------|-------|
| `VISION.md` | Purpose, users, success, hard invariants, `## Vocabulary` (one line per term — the referent `/enrich` checks every task against) | `/kickoff` |
| `milestones/NNNN-slug.md` | One milestone: outcome, decisions to make, needs proving, landing record | `/aim` creates, `/decide` back-references, `/land` closes |
| `tasks/NNNN-slug.md` | One task: plan, acceptance criteria, refs; closing record after landing | `/enrich`/`/supplement` create, `/burn` orchestrator updates |
| `documentation/decisions/NNNN-slug.md` | One decision record (context, decision, rationale, consequences) | `/decide` |
| `documentation/DECISIONS.md` | One-line-per-decision index (the "this exists" lookup) | `/decide` |
| `documentation/<topic>.md` | Derived per-topic digests (e.g. `tech-stack.md`, `testing.md`) — the crisp "what the rules are" form agents read instead of paging full records. **Never authored by hand**: the `decision-summarizer` agent rewrites them after every decision change | `decision-summarizer` (spawned by `/decide`) |

## Identity and frontmatter

An item's canonical id is the 4-digit `NNNN-` **filename prefix** — never duplicated into frontmatter (two sources of truth drift, and YAML parses bare `0042` as octal). Frontmatter carries only the mechanical attributes:

```yaml
# task                              # milestone            # decision
title: …                            title: …               title: …
status: todo|in-progress|done|      status: open|landed    status: proposed|accepted|
        rejected                                                   rejected|superseded
complexity: low|medium|high                                 proof: none|pending|proven
milestones: ["0001", …]                                     superseded_by: "0007"|null
depends_on: []
decisions: []
proves: []        # decisions whose proof this task delivers
documents: []     # docs, examples, …
```

Task `rejected` means the human decided not to do it — a terminal tombstone. Grader rejection during `/burn` is NOT a status; it returns the task to `todo`. Tasks are never split after persistence: `/enrich` and `/supplement` shape the breakdown before writing files, so a persisted task is by definition clear and well shaped, and its id stays live for its whole life.

**Rejection ripples.** Whenever a task becomes `rejected`, the skill flipping it queries its dependents (`backlog.sh dependents <id>`) and rewires each `depends_on` edge in the same session — to a replacement, or by dropping the edge; a live task depending on a rejected one is a check failure, not a silent deadlock. If the rejected task was on a decision's `proves` side, the proof is re-homed (a new proving task via `/enrich`) or the decision revisited via `/decide`.

## Asking the user

Every trajectory skill is a dialog skill, and `AskUserQuestion` is available in all of them. Use it for the **closed, option-shaped** turns — where you can put 2–4 concrete choices on the table (which candidate to pursue, which alternative wins, approve / defer / reject, fold vs. re-scope vs. proceed, revise vs. supersede). A question posed as options is a Socratic "it sounds like this might be X" with a built-in escape hatch (the user can always answer freely), and it is usually sharper than the same question in prose. Several such decisions can go in one call; lead with your own recommendation as the first option, and let each option's description carry the trade-off.

Do **not** force **open discovery** through multiple choice: who the users are, what the situation is, why an assumption is risky, what actually went wrong. Options there railroad the user toward your framing — the exact failure the Socratic style exists to prevent. Ask those in prose, and follow up in prose whenever an answer is shallow or contradicts an earlier one, however it was asked. Never let the tool's structure cut a grilling short, and never present a fabricated option just to reach four.

## Deterministic bookkeeping

Every mechanical question — listing, retrieval, status flips, readiness derivation, structural checking — goes through `_shared/scripts/backlog.sh` (next to the skills; requires `yj` and `jq`). No skill or subagent ever scans the backlog files; prose bodies are read only by the one agent working that one item. Run `backlog.sh check` **every time backlog files are created or updated** — it gates canonical filenames, dangling references, live-dependency-on-rejected, and dependency cycles, and prints board-level warnings (e.g. a pending proof with no live proving task). `backlog.sh board` doubles as the user's task board (`-c` colors when stdout is a TTY).

Status is derived where possible: a milestone is **ready to land** when at least one task lists it, every task listing it is `done` or `rejected`, and every `proof: pending` decision back-referenced from its body is proven by a `done` task (`backlog.sh milestone-ready`). A task shared by several milestones counts toward each, but its outcome (closing record) is written once — landing the second milestone reads that record, never re-processes the task.

## Commits

Workers commit their own code changes via the common `/commit` skill (one commit per task, inside their worktree). The orchestrating skill commits every backlog-file change (task/milestone/decision files) it writes, separately from code commits — always with an explicit pathspec (`git add <files> && git commit -m "…" -- <files>`, only the backlog files it just wrote), so a bookkeeping commit can never sweep unrelated working-tree changes along.

## Subagents

Subagents are used wherever possible to parallelize work and keep tokens off the main thread: `aim-scout` (read-only project recon for `/aim`), `task-linker` (read-only duplicate/link scan for `/enrich`/`/supplement`), `decision-summarizer` (rewrites the `documentation/<topic>.md` digests for `/decide`), and the `/burn` crew — `burn-worker` (TDD in a worktree, self-briefed from the task file, full report parked at `.burn/REPORT.md`, commits via `/commit`), `grader` (strict acceptance-criteria review, self-briefed), `burn-scribe` (serialized closing-record writer), `merger` (sequential merge-back, bounce on conflict), `doc-syncer` (post-merge doc refresh, serialized).
