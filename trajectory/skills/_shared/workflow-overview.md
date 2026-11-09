# Trajectory Workflow — Shared Overview

Read this to understand where the current skill sits in the family. Trajectory is a demo-driven, proof-driven build workflow: the human checkpoints are **demos** — executable scenarios that turn green when the code actually runs them — tasks are one flat dependency graph burned down without any grouping, decisions carry an explicit proof obligation, and a scripted helper answers every mechanical question so no skill ever scans the backlog.

## The story

| Step | What it does | Produces |
|------|--------------|----------|
| `/kickoff` (once, re-entrant) | vision + vocabulary | `VISION.md` (+ `## Vocabulary`) |
| `/aim` | idea → next demo | `demos/NNNN-slug.md` (scenario + check command) |
| `/decide` | settle the demo's open decisions | `documentation/decisions/NNNN-slug.md` |
| `/enrich` | demo → well-shaped tasks, the check task first | `tasks/NNNN-slug.md` |
| `/burn` | TDD workers burn the available set down; demo checks run after merges | code, closing records, demo red/green |
| `/land` | the human test cycle on a green demo: show, collect feedback, clear proofs | `## Showing` record, new tasks, demo `shown` |

A stalled demo loops `/burn` back to `/enrich`; test-cycle feedback loops `/land` back to `/burn`.

`/supplement` captures small tasks that serve no demo (bugs, chores, improvements) with the same rigor as `/enrich`. `/decide` is also invoked out-of-band whenever a decision is made, challenged, or contradicted by evidence.

## Demos, not milestones

A demo is a point worth calling the human over for: something that can really be shown working, not every small feature. It has two jobs a milestone used to blur, and does only the first:

- **It is a checkpoint.** A `## Scenario` (numbered steps, each with the observation that proves it), a `## Human check` (what only a person can judge — feel, wording, flow), and a `check:` command in the frontmatter that runs the automatable part end-to-end against the real entry point (binary, HTTP, CLI). The check is written as a task of its own, first, so every demo starts red by construction: outside-in TDD at the scale of the whole outcome.
- **It is not a container.** Tasks list the demos they are known to serve (`demos: [...]`) as a scheduling hint, never as a definition of done. Work flows through one flat dependency graph at whatever speed the agents manage; nothing waits for a group to complete.

**The code decides, not the bookkeeping.** A demo's `red`/`green` status is written only by `backlog.sh demo-check`, which runs the check command (`set-status demo … green` is refused). `/burn` runs it after merging a task that lists the demo and over every open demo at the end of a run. So "all tasks done" never stands in for "the outcome works" — the failure mode where every task lands and the thing still does not run.

**A stalled demo is the gap signal.** A demo that is red while no live (`todo`/`in-progress`) task lists it is **STALLED**: everything known was built and the outcome still fails, so the missing work was never written down. `check` and the board warn about it, and `/enrich <demo>` reads the failing check's log and mints the tasks for the step that fails. This replaces any up-front coverage bookkeeping — the running check finds the uncovered ground.

**Gates.** A demo's `gate` sets what a green flip does to an unattended run: `flag` (default) — record it, queue it for `/land`, keep burning other work; `hold` — finish the in-flight tasks, dispatch nothing new, and stop so the human sees it before more is built on top (use it where later work depends on the verdict: a UX direction, an architecture bet).

Demo statuses: `red` (being built) → `green` (ready for the human test cycle) → `shown` (the human ran `/land` and accepted it); `dropped` is the human tombstone. Showing a demo never reopens finished tasks: feedback from the test cycle becomes new tasks (and, when an expectation changed, new scenario steps plus an extended check — which turns the demo red again until they land).

## The proving loop (the signature move)

`/aim` writes "what needs to be proven" into the demo → `/decide` turns each item into a decision with `status: accepted, proof: pending`, back-references it from the demo item (a `decision: NNNN` marker on the item line), and decomposes it into a **`## Proof` claim list** — one checklist line per thing running code has to demonstrate → `/enrich` attaches the decision id to the `proves` list of the task(s) that will demonstrate it, wiring *per claim* → `/land` walks the claims one at a time against the closing records and the green demo, ticks each on the evidence, and flips the decision to `proof: proven` once they all hold. A decision whose proving task surfaces contradicting evidence is never silently edited — `/land` routes it back to `/decide <id>` for revision or supersession. A `proof: pending` decision with no live proving task is a board-level warning, never silently dropped. Proofs never hold a demo's status hostage: a green demo is shown, and a claim it does not yet demonstrate stays open and is named.

**Why claims and not one boolean.** A decision statement usually carries several claims, and they get demonstrated by different tasks through different surfaces — commonly one through the library API and another only through the actual entry point. With one `proves` edge per decision, a task delivering four claims out of five reads as a complete proof. `backlog.sh set-proof <id> proven` therefore refuses while any claim is unticked. A claim that names the demo's own surface is best evidenced by the green check itself.

## Records are evidence, so records are verified

A task's closing record (`## Manual testing`) is not a note — it is evidence `/land` ticks proof claims against and raw material for the walk-through the user will follow literally. Its failure mode is quiet and durable: a worker composes a plausible walk-through from the code it just wrote instead of running it, the quoted output was never what shipped, and because nothing downstream re-derives the record from the code, the fiction survives every later read. So the record is **observed at every point it is touched**: `burn-worker` runs each step it writes (failure paths included) and pastes real output, marking `[unverified]` anything it genuinely could not run; `grader` checks each command and quoted literal against the shipped code and rejects an unsupported one even when every criterion is met; `burn-scribe` transcribes quoted output as bytes, markers intact; `doc-syncer` runs a command before writing what it prints; and `/land` re-runs the demo check and re-verifies the records it relies on, since the tree has moved since the grader saw it. An `[unverified]` step is an expectation, never evidence. The demo check is the one piece of evidence nobody composes — it either exits 0 at a recorded commit or it does not.

## Project artifacts

| Path | Role | Owner |
|------|------|-------|
| `VISION.md` | Purpose, users, success, hard invariants, `## Vocabulary` (one line per term — the referent `/enrich` checks every task against) | `/kickoff` |
| `demos/NNNN-slug.md` | One demo: outcome, scenario, human check, decisions to make, needs proving, showing record; frontmatter `check` command and `gate` | `/aim` creates, `/decide` back-references, `/enrich` sets the check command, `demo-check` flips red/green, `/land` shows |
| `tasks/NNNN-slug.md` | One task: plan, acceptance criteria, refs; closing record after landing | `/enrich`/`/supplement`/`/land` create, `/burn` orchestrator updates |
| `documentation/decisions/NNNN-slug.md` | One decision record (context, decision, rationale, consequences, and a `## Proof` claim list when it carries a proof obligation) | `/decide` writes, `/land` ticks the claims |
| `documentation/DECISIONS.md` | One-line-per-decision index (the "this exists" lookup) | `/decide` |
| `documentation/<topic>.md` | Derived per-topic digests (e.g. `tech-stack.md`, `testing.md`) — the crisp "what the rules are" form agents read instead of paging full records. **Never authored by hand**: the `decision-summarizer` agent rewrites them after every decision change | `decision-summarizer` (spawned by `/decide`) |
| `.trajectory/demo-NNNN.log` | The last `demo-check` output per demo — what `/enrich` reads for a stalled demo and `/land` for a green one. Scratch state: keep `.trajectory/` in `.gitignore` | `backlog.sh demo-check` |

## Identity and frontmatter

An item's canonical id is the 4-digit `NNNN-` **filename prefix** — never duplicated into frontmatter (two sources of truth drift, and YAML parses bare `0042` as octal). Frontmatter carries only the mechanical attributes:

```yaml
# task                              # demo                         # decision
title: …                            title: …                       title: …
status: todo|in-progress|done|      status: red|green|shown|       status: proposed|accepted|
        rejected                            dropped                        rejected|superseded
complexity: low|medium|high         gate: flag|hold                proof: none|pending|proven
demos: ["0001", …]                  check: "<shell command>"       superseded_by: "0007"|null
depends_on: []                      checked_at: "<short sha>"|null
decisions: []
proves: []        # decisions whose proof this task delivers
documents: []     # docs, examples, …
```

Task `rejected` means the human decided not to do it — a terminal tombstone. Grader rejection during `/burn` is NOT a status; it returns the task to `todo`. Tasks are never split after persistence: `/enrich` and `/supplement` shape the breakdown before writing files, so a persisted task is by definition clear and well shaped, and its id stays live for its whole life.

**Rejection ripples.** Whenever a task becomes `rejected`, the skill flipping it queries its dependents (`backlog.sh dependents <id>`) and rewires each `depends_on` edge in the same session — to a replacement, or by dropping the edge; a live task depending on a rejected one is a check failure, not a silent deadlock. If the rejected task was on a decision's `proves` side, the proof is re-homed (a new proving task via `/enrich`) or the decision revisited via `/decide`. Dropping a demo ripples the same way: its live tasks are rejected, re-pointed to another demo, or kept as plain tasks (`check` warns about live tasks serving a dropped demo).

## Asking the user

Every trajectory skill is a dialog skill, and `AskUserQuestion` is available in all of them. Use it for the **closed, option-shaped** turns — where you can put 2–4 concrete choices on the table (which candidate to pursue, which alternative wins, approve / defer / reject, fold vs. re-scope vs. proceed, revise vs. supersede, shown vs. not yet). A question posed as options is a Socratic "it sounds like this might be X" with a built-in escape hatch (the user can always answer freely), and it is usually sharper than the same question in prose. Several such decisions can go in one call; lead with your own recommendation as the first option, and let each option's description carry the trade-off.

Do **not** force **open discovery** through multiple choice: who the users are, what the situation is, why an assumption is risky, what actually went wrong in a test cycle. Options there railroad the user toward your framing — the exact failure the Socratic style exists to prevent. Ask those in prose, and follow up in prose whenever an answer is shallow or contradicts an earlier one, however it was asked. Never let the tool's structure cut a grilling short, and never present a fabricated option just to reach four.

## Deterministic bookkeeping

Every mechanical question — listing, retrieval, status flips, demo checks, structural checking — goes through `_shared/scripts/backlog.sh` (next to the skills; requires `yj` and `jq`). No skill or subagent ever scans the backlog files; prose bodies are read only by the one agent working that one item. Run `backlog.sh check` **every time backlog files are created or updated** — it gates canonical filenames, dangling references, demo field values, live-dependency-on-rejected, and dependency cycles, and prints board-level warnings (a stalled demo, a demo without a check command, a pending proof with no live proving task). `backlog.sh board` doubles as the user's board (`-c` colors when stdout is a TTY; a demo checked at an older commit shows `(stale)`); `backlog.sh dense` is the scannable twin — one glyph per item, slot position = id, the whole backlog in a few lines (`-c` colors, `-w N` sets row width). `backlog.sh demo-state [<id>]` is the per-demo report: check freshness, open items, open and done tasks, pending proofs, and the verdict (`GREEN` / `RED` / `STALLED`).

**`demo-check` runs project code.** The check command executes from the project root with the session's permissions — under a sandbox, a check that binds a port or reaches the network fails for reasons that have nothing to do with the code. Keep checks hermetic where possible (ephemeral port, temp dirs, local fixtures); when a red result is the sandbox and not the code, say so instead of minting tasks against it.

## Commits

**The foreground skills never commit.** `/kickoff`, `/aim`, `/decide`, `/enrich`, `/supplement`, and `/land` run interactively with the user present: they write their backlog files, run `backlog.sh check`, name what they wrote, and stop — the user reviews the diff and commits it themselves (`/commit`). Committing on the user's behalf in a session they are watching takes the review step away from them.

Committing only happens inside `/burn`, where the work runs unattended and a landed task must be a durable unit: `burn-worker` commits its code via the common `/commit` skill (one commit per task, inside its worktree), and `burn-scribe` / `merger` / `doc-syncer` commit the closing record, the merge, and the doc sync respectively; the orchestrator commits status flips, including the demo files `demo-check` rewrites. Each of those always uses an explicit pathspec (`git add <files> && git commit -m "…" -- <files>`, only the files it just wrote), so a bookkeeping commit can never sweep unrelated working-tree changes along.

## Subagents

Subagents are used wherever possible to parallelize work and keep tokens off the main thread: `aim-scout` (read-only project recon for `/aim`), `task-linker` (read-only duplicate/link scan for `/enrich`/`/supplement`), `decision-summarizer` (rewrites the `documentation/<topic>.md` digests for `/decide`), and the `/burn` crew — `burn-worker` (TDD in a worktree, self-briefed from the task file, full report parked at `.burn/REPORT.md`, commits via `/commit`), `grader` (strict acceptance-criteria review, self-briefed), `burn-scribe` (serialized closing-record writer), `merger` (sequential merge-back, bounce on conflict), `doc-syncer` (post-merge doc refresh, serialized).
