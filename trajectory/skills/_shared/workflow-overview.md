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

`/aim` writes "what needs to be proven" into the milestone → `/decide` turns each item into a decision with `status: accepted, proof: pending`, back-references it from the milestone item (a `decision: NNNN` marker on the item line), and decomposes it into a **`## Proof` claim list** — one checklist line per thing running code has to demonstrate → `/enrich` attaches the decision id to the `proves` list of the task(s) that will demonstrate it, wiring *per claim* (a task in a later milestone may prove an earlier milestone's decision) → `/land` walks the claims one at a time against the closing records, ticks each on the evidence, and flips the decision to `proof: proven` once they all hold. A decision whose proving task surfaces contradicting evidence is never silently edited — `/land` routes it back to `/decide <id>` for revision or supersession. A `proof: pending` decision with no live proving task is a board-level warning, never silently dropped.

**Why claims and not one boolean.** A decision statement usually carries several claims, and they get demonstrated by different tasks through different surfaces — commonly one through the library API and another only through the actual entry point. With one `proves` edge per decision, a task delivering four claims out of five reads as a complete proof, the milestone reads READY, and the undelivered fifth surfaces only when someone tries to use the thing. `backlog.sh set-proof <id> proven` therefore refuses while any claim is unticked, and `milestone-ready` reports a done prover with open claims as a blocker.

## Records are evidence, so records are verified

A task's closing record (`## Manual testing`) is not a note — it is the evidence `/land` ticks proof claims against and the source of the demo walk-through the user will follow literally. Its failure mode is quiet and durable: a worker composes a plausible walk-through from the code it just wrote instead of running it, the quoted output was never what shipped, and because nothing downstream re-derives the record from the code, the fiction survives every later read. So the record is **observed at every point it is touched**: `burn-worker` runs each step it writes (failure paths included) and pastes real output, marking `[unverified]` anything it genuinely could not run; `grader` checks each command and quoted literal against the shipped code and rejects an unsupported one even when every criterion is met; `burn-scribe` transcribes quoted output as bytes, markers intact; `doc-syncer` runs a command before writing what it prints; and `/land` re-verifies the records carrying the landing before demoing or ticking a claim on them, since the tree has moved since the grader saw it. An `[unverified]` step is an expectation, never evidence.

## Project artifacts

| Path | Role | Owner |
|------|------|-------|
| `VISION.md` | Purpose, users, success, hard invariants, `## Vocabulary` (one line per term — the referent `/enrich` checks every task against) | `/kickoff` |
| `milestones/NNNN-slug.md` | One milestone: outcome, decisions to make, needs proving, `## Breakdown` coverage map, landing record | `/aim` creates, `/decide` back-references, `/enrich` writes the coverage map, `/land` closes |
| `tasks/NNNN-slug.md` | One task: plan, acceptance criteria, refs; closing record after landing | `/enrich`/`/supplement` create, `/burn` orchestrator updates |
| `documentation/decisions/NNNN-slug.md` | One decision record (context, decision, rationale, consequences, and a `## Proof` claim list when it carries a proof obligation) | `/decide` writes, `/land` ticks the claims |
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

Every mechanical question — listing, retrieval, status flips, readiness derivation, structural checking — goes through `_shared/scripts/backlog.sh` (next to the skills; requires `yj` and `jq`). No skill or subagent ever scans the backlog files; prose bodies are read only by the one agent working that one item. Run `backlog.sh check` **every time backlog files are created or updated** — it gates canonical filenames, dangling references, live-dependency-on-rejected, and dependency cycles, and prints board-level warnings (e.g. a pending proof with no live proving task). `backlog.sh board` doubles as the user's task board (`-c` colors when stdout is a TTY); `backlog.sh dense` is the scannable twin — one glyph per item, slot position = id, the whole backlog in a few lines (`-c` colors, `-w N` sets row width). Show the board when the user needs titles and detail, `dense` when they only need the shape of progress.

Status is derived where possible: a milestone is **ready to land** (`backlog.sh milestone-ready`) when every one of these holds — every `## Decisions to make` / `## Needs proving` item is ticked *and* back-referenced; its `## Breakdown` coverage map exists and every line resolves to `tasks:` or `deferred:`; at least one task lists it and every task listing it is `done` or `rejected`; and every back-referenced `proof: pending` decision has a `done` proving task *and* all its `## Proof` claims ticked. A task shared by several milestones counts toward each, but its outcome (closing record) is written once — landing the second milestone reads that record, never re-processes the task.

**Task statuses alone cannot see work that was never written down.** The first two conditions exist because the dangerous state is not a task that failed, it is ground that never became a task — an item `/decide` never settled, so `/enrich` could not break it down, so nothing lists the milestone for it. Everything that did get minted then lands, and readiness derived from task status alone says READY while the outcome is undelivered. So an unsettled item and an unresolved coverage line are *first-class blockers*, and the map is written even when the breakdown is knowingly partial. `check` and the board additionally warn about partial breakdowns (tasks exist, items still open) and pending decisions with no claim list.

## Commits

**The foreground skills never commit.** `/kickoff`, `/aim`, `/decide`, `/enrich`, `/supplement`, and `/land` run interactively with the user present: they write their backlog files, run `backlog.sh check`, name what they wrote, and stop — the user reviews the diff and commits it themselves (`/commit`). Committing on the user's behalf in a session they are watching takes the review step away from them.

Committing only happens inside `/burn`, where the work runs unattended and a landed task must be a durable unit: `burn-worker` commits its code via the common `/commit` skill (one commit per task, inside its worktree), and `burn-scribe` / `merger` / `doc-syncer` commit the closing record, the merge, and the doc sync respectively. Each of those always uses an explicit pathspec (`git add <files> && git commit -m "…" -- <files>`, only the files it just wrote), so a bookkeeping commit can never sweep unrelated working-tree changes along.

## Subagents

Subagents are used wherever possible to parallelize work and keep tokens off the main thread: `aim-scout` (read-only project recon for `/aim`), `task-linker` (read-only duplicate/link scan for `/enrich`/`/supplement`), `decision-summarizer` (rewrites the `documentation/<topic>.md` digests for `/decide`), and the `/burn` crew — `burn-worker` (TDD in a worktree, self-briefed from the task file, full report parked at `.burn/REPORT.md`, commits via `/commit`), `grader` (strict acceptance-criteria review, self-briefed), `burn-scribe` (serialized closing-record writer), `merger` (sequential merge-back, bounce on conflict), `doc-syncer` (post-merge doc refresh, serialized).
