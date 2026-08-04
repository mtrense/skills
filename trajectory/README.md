# Trajectory Workflow

A milestone-labelled, proof-driven build workflow. Milestones are a means of grouping and labelling tasks — never barriers or synchronization points — and every risky assumption a milestone stands on becomes a decision with an explicit **proof obligation** that only a `done` task can discharge. Scripted helpers do all the mechanical bookkeeping; subagents carry the heavy work off the main thread.

## The story

```
/kickoff (once, re-entrant)   Socratic vision + vocabulary        → VISION.md
/aim                          idea → next milestone               → milestones/NNNN-slug.md
/decide                       settle the milestone's open calls   → documentation/decisions/NNNN-slug.md
/enrich                       milestone → well-shaped tasks       → tasks/NNNN-slug.md
/burn                         parallel TDD workers burn the available set down
/land                         verify vs. goal, clear proofs, update docs
```

`/supplement` sits outside the milestone flow (small milestone-less bugs/chores, same rigor as `/enrich`); `/decide` is also invoked out-of-band whenever a decision is made, challenged, or contradicted.

## The proving loop (the signature move)

`/aim` writes "what needs to be proven" into the milestone → `/decide` turns each item into a decision with `status: accepted, proof: pending`, back-referenced from the milestone item → `/enrich` attaches the decision id to the `proves` list of the task(s) that will demonstrate it (a task in a later milestone may prove an earlier milestone's decision) → when `/land` finds every proving task done, it consults the user and flips the decision to `proof: proven`. Contradicting evidence is never silently edited over — `/land` routes it to `/decide` for revision or supersession. A pending proof with no live proving task is a standing board warning.

## Skills

| Command | What it does |
|---------|-------------|
| `/kickoff` | Socratic interview → `VISION.md` with purpose, users, success, invariants, and a one-line-per-term `## Vocabulary` section (the referent `/enrich` checks every task against). Re-entrant (diff-oriented revision mode). Closes a first run by offering the foundational decisions (stack, persistence, testing) as a `/decide` batch — never smuggled into the vision |
| `/aim` | Idea (or own proposal when empty) → scouted milestone: outcome/benefit, decisions to make before breakdown, what needs proving. Delegates project recon to `aim-scout` |
| `/decide` | One decision, Socratically understood then persisted: record + `DECISIONS.md` index line; milestone-spawned proofs get `proof: pending` + a back-reference. Argless it takes the next open item from the lowest-id open milestone; given an existing id it revises or supersedes. Spawns `decision-summarizer` to rewrite the derived `documentation/<topic>.md` digests |
| `/enrich` | Milestone → tasks, all shaping **before** persistence (tasks are never split after; ids stay live for life): plan with files to touch, decision/doc refs, complexity (`low\|medium\|high`), `depends_on`, acceptance criteria, `proves` links. Hard gate: unresolved decision **or needs-proving** items refuse breakdown → `/decide`. Per-task `task-linker` scan proposes links instead of duplicates; every task is vocabulary-checked against `VISION.md`. Also re-shapes `/burn`'s UNDERESTIMATED hand-backs (narrow in place + mint the remainder) |
| `/supplement` | Small milestone-less task (bug/improvement/chore) with the same rigor — including proposing a multi-task breakdown when the input is bigger than one well-shaped task |
| `/burn` | `<count>@<workers>` burn-down over the available set (`todo`, deps done, ascending id): per task, `burn-worker` (TDD in a worktree, commits via `/commit`, model tier from `complexity` — default `low=sonnet medium=opus high=opus`, overridable via `.workflow-overrides/model-map`) → `grader` (strict vs. acceptance criteria + linked decisions; rejection returns the task to `todo` with feedback appended and one retry a tier up) → serialized `burn-scribe` (writes the closing record — `## Manual testing` + `## Deviations` — into the task file from the worker's report, pre-merge) → sequential `merger` (conflict = bounce to a fresh worker on the updated base; post-merge red suite = escalate once, then break out) → serialized `doc-syncer`. The orchestrator passes pointers, never content: workers/graders self-brief from the task file + decision digests in the worktree, and the worker's full report lives at `.burn/REPORT.md` there (only a compact control block returns to the session). Escalation at most once per task per run, run-state only. Resumable/idempotent (reclaims orphaned `in-progress` tasks) |
| `/land` | Next all-done milestone: compliance check against the original goal, deviations persisted (contradictions with decisions routed to `/decide`, never recorded over), test/demo walk-through synthesized from the closing records, docs updated (dialog if unsure), pending proofs cleared with the user. Cross-milestone proof reported as `blocked on proof: task NNNN (milestone MMMM)` — the one deliberate sync point |

## Asking the user

Every skill here is a dialog skill, and all of them may use `AskUserQuestion`. The split is deliberate and documented once in `skills/_shared/workflow-overview.md`: **closed, option-shaped** turns are posed as options — which candidate milestone to aim at, which alternative a decision picks (with `preview` when the alternatives are concrete artifacts), fold-vs-re-scope on an overlap, approve/defer a pending proof, revise-vs-supersede, land-with-gap vs. reopen, the few points `/burn` stops at mid-run — while **open discovery** (who the users are, why an assumption is risky, what actually went wrong) stays in prose, because options there railroad the user toward the model's framing.

## Project artifacts

```
VISION.md                            # purpose, users, success, invariants, ## Vocabulary
milestones/NNNN-slug.md              # outcome, decisions to make, needs proving, landing record
tasks/NNNN-slug.md                   # plan, acceptance criteria, closing record
documentation/decisions/NNNN-slug.md # full decision records (context/decision/rationale/consequences)
documentation/DECISIONS.md           # one-line-per-decision index
documentation/<topic>.md             # derived per-topic digests — never authored by hand
```

The `NNNN-` filename prefix is the canonical id and is never duplicated into frontmatter (two sources of truth drift, and YAML parses bare `0042` as octal). Frontmatter carries only the mechanical attributes (`status`, `proof`, `complexity`, `milestones`, `depends_on`, `decisions`, `proves`, `documents`, `superseded_by`); statuses like "milestone ready to land" are derived by script wherever possible.

## Deterministic bookkeeping

Every mechanical question goes through `skills/_shared/scripts/backlog.sh` (`new`, `next-id`, `ready`, `by-status`, `by-milestone`, `get`, `blockers`, `dependents`, `provers`, `set-status`, `set-proof`, `set-superseded`, `milestone-ready`, `pending-proofs`, `check`, `board`, `dense`) — no skill or subagent ever scans the backlog; prose bodies are read only by the one agent working that one item. `backlog.sh check` runs after every backlog write: canonical filenames, dangling references, live deps on rejected tasks, and dependency cycles fail hard; a pending proof with no live proving task is a warning the board repeats. `backlog.sh board` doubles as the user's task board (`-c` colors the status column), and `backlog.sh dense` is its at-a-glance twin: one glyph per item with the slot position equal to the id (gaps included), grouped in tens, `-c` colors and `-w N` sets the row width — a whole backlog fits in a few lines, with per-glyph counts in each kind's header and a warning count at the end. Requires `yj` and `jq`.

Task `rejected` is a human tombstone, never a grader verdict — and rejection **ripples**: the skill flipping it rewires every dependent edge in the same session, and re-homes or revisits any proof the task carried.

## Commits

The foreground skills (`/kickoff`, `/aim`, `/decide`, `/enrich`, `/supplement`, `/land`) **never commit** — they write their backlog files, run `backlog.sh check`, name what they wrote, and leave the diff for the user to review and commit (`/commit`). Committing happens only inside `/burn`, which runs unattended: `burn-worker` commits its code via `/commit` (one commit per task, inside its worktree), and `burn-scribe`/`merger`/`doc-syncer` commit the closing record, merge, and doc sync — each with an explicit pathspec (`git commit … -- <files>`), so bookkeeping can never sweep unrelated working-tree changes along.

## Subagents

Eight bundled agents in `trajectory/agents/`: three read-only proposers (`aim-scout` — project recon for `/aim`; `task-linker` — duplicate/link scan for `/enrich`/`/supplement`; `grader` — strict acceptance review, self-briefed from the task file) and five write-side workers (`burn-worker` — one task, TDD in a worktree, self-briefed from pointers, full report parked at `.burn/REPORT.md`, commits via `/commit`, never touches backlog files; `burn-scribe` — serialized closing-record writer, the one delegated backlog write; `merger` — sequential merge-back, bounce-on-conflict; `doc-syncer` — post-merge doc refresh, strictly serialized; `decision-summarizer` — rewrites the derived topic digests for `/decide`). The `/burn` orchestrator owns every status write.

Depends on **`common`** being installed alongside it for `/commit` (the single code-commit point).

## Installation

```bash
./install.sh trajectory                  # global
./install.sh trajectory /path/to/project # per-project
```
