# Trajectory – 

## The Mechanics
Milestones are stored as `milestones/NNNN-slug.md`, tasks as `tasks/NNNN-slug.md`, decisions are encoded in `documentation/decisions/NNNN-slug.md` and summarized twice: a one-line-per-decision index in `documentation/DECISIONS.md` (the "this exists" lookup) and derived per-topic digests in `documentation/<topic>.md` (e.g. `tech-stack.md`, `testing.md`) — the crisp "what the rules are" form agents read instead of paging full records. The per-topic summaries are never authored by hand: after any decision is recorded or revised, `/decide` spawns a summarizer subagent (the `architecture-summarizer` pattern) that rewrites the affected topic files. The `NNNN-` filename prefix is the canonical id — it is never duplicated into frontmatter (two sources of truth drift, and YAML parses bare `0042` as octal). Each file has a frontmatter for the mechanical attributes:
- title           # all
- status          # task (todo|in-progress|done|rejected), decision (proposed|accepted|rejected|superseded), milestone (open|landed)
- proof           # decision (none|pending|proven) — orthogonal to status: an accepted decision can still await proof
- superseded_by   # decision (id of the superseding record — set when status flips to superseded)
- complexity      # task (low|medium|high)
- milestones      # task (list of milestones)
- depends_on      # task (list of dependencies)
- decisions       # task (list of decisions)
- proves          # task (list of decisions whose proof this task delivers)
- documents       # task (list of documents, examples, ...)

Task `rejected` means the human decided not to do it — it is a terminal tombstone. Grader rejection of a worker's output is not a task status; it returns the task to `todo` (see The Burn-down). Tasks are never split after persistence: `/enrich` and `/supplement` shape the breakdown *before* writing files — either may propose several tasks where the human offered one — so a persisted task is by definition clear and well shaped, and its id stays live for its whole life.

Rejection ripples. Whenever a task becomes `rejected`, the orchestrating skill queries its dependents (via the helper) and rewires each `depends_on` edge in the same session — to a replacement, or by dropping the edge; a live task whose `depends_on` points at a rejected task is a check-script failure, not a silent deadlock. If the rejected task was on a decision's `proves` side, the proof is re-homed (a new proving task via `/enrich`) or the decision revisited via `/decide` — a `proof: pending` decision with no live proving task is a board-level warning, never silently dropped.

Scripted helpers are used to do the mechanical parts of listing or retrieving from the backlog, and other mechanical duties. Check scripts (including dependency-cycle detection) are run every time files are created or updated. The scripted helper for listing the backlog doubles as a task board for the user (colored when `stdout` is a TTY).

Status (eg. milestone ready to land) is derived by scripts from the frontmatter where possible. A milestone is ready to land when every task listing it is `done` or `rejected` and every decision it spawned with `proof: pending` is proven by a `done` task. A task shared by several milestones counts toward each, but its outcome is written once — landing the second milestone must not re-process it.

Milestones are a means of grouping and labelling tasks. Tasks may contribute to more than one milestone. Milestones are not barriers or synchronization points.

Subagents are used where possible to parallelize work and save tokens on the main thread.

**The proving loop** (the workflow's signature move, wired end to end): `/aim` writes "what needs to be proven" into the milestone → `/decide` turns each item into a decision with `status: accepted, proof: pending` and back-references it from the milestone item → `/enrich` attaches the decision id to the `proves` list of the task(s) that will demonstrate it (a task in a later milestone may prove an earlier milestone's decision) → when `/land` finds every `proves`-task done, it consults the user and flips the decision to `proof: proven`. A decision whose proving task surfaces contradicting evidence is not silently edited — `/land` routes it back to `/decide <id>` for revision or supersession.

**Commits:** workers commit their own code changes via the common `/commit` skill (one commit per task, inside their worktree). The orchestrator commits every backlog-file change (task/milestone/decision files) it writes, separately from code commits — always with an explicit pathspec (`git commit … -- <files>`, only the backlog files it just wrote), so a bookkeeping commit can never sweep unrelated working-tree changes along.

## The story
Each phase of the story corresponds to a dedicated skill.

### 1. Kickoff
Using `/kickoff`, we start a project by gathering the vision and purpose that the project serves. To get to that shared understanding, you do a socratic interview with me. We're interested in:
- who are the potential users, what are their needs and how can the project solve them?
- how does success look like?
- what are hard constraints or invariants that must never fail?
- what is the vocabulary/the domain language?

But don't just verbatimly ask for those topics, the aim is real understanding. The resulting `VISION.md` wraps up the gained understanding and carries an explicit `## Vocabulary` section — one line per term — because `/enrich` checks every task against it and a prose-only vision is too thin to serve as that referent. Re-entrant: with `VISION.md` present it runs in revision mode — diff-oriented, updating only what changed rather than re-interviewing from scratch.

Foundational decisions (tech stack, persistence, testing approach — everything that predates any milestone) are not smuggled into the vision: `/kickoff` closes a first run by listing them and offering a first `/decide` batch, so they land in the decision log with the same rigor as every later decision.

### 2. The next aim
`/aim` gives us the next target to build towards. Seeded with an idea, a bunch of bullet points, an example or (when left empty) your suggestion for the next feature to go for. You take this idea and launch subagents to understand the current state of the project, unknowns or blockers to surface. Using this information, you write down a milestone in `milestones/NNNN-slug.md`, covering:
- what this milestone achieves, its outcome and benefit
- which decisions I need to make before breakdown and implementation can start
- what needs to be proven

### 3. Decisions
`/decide` takes a statement or, when called without argument, the next open decision item from the lowest-id open milestone, and starts a brief socratic dialog to gain a shared understanding of the decision before persisting it. When called with a reference to an already existing decision, the socratic dialog should identify what needs to change and why, ending in a revision or a superseding record.
A decision created from a milestone's "what needs to be proven" list is persisted with `proof: pending` and back-referenced from that milestone item, so `/land` can clear it after consulting the user (see the proving loop above).

### 4. Enrichment
`/enrich` starts a dialog to tick the boxes of the next milestone (or the one given as argument) and you provide a breakdown into tasks (persisting them as `tasks/NNNN-slug.md`), giving each task
- a plan (including the files to touch if possible)
- a set of relevant decisions or other documentation references
- an estimation of its complexity
- a list of identified dependencies to other tasks
- a list of acceptance criteria
- the `proves` link for any `proof: pending` decision this task will demonstrate

For each task, an agent scans existing open tasks, and proposes links instead of duplicating the original task. Open decisions are a hard gate: `/enrich` refuses to break down a milestone whose "decisions I need to make" items are still unresolved, routing them to `/decide` first — a task written against an unmade decision just encodes a guess.

Every task is checked against the domain language captured in `VISION.md`'s `## Vocabulary` section: names, terms, and acceptance criteria must use the established vocabulary, and a task that needs a term the vision doesn't have surfaces that gap (extend the vocabulary via `/kickoff` revision, or fix the wording) instead of quietly coining a synonym.

### 5. Supplement
`/supplement` adds a small task without a milestone. This can be bugs, small improvements or chores to be carried out. Utilizes the same rigor as `/enrich` to ensure the task is workable and detailed — including proposing a breakdown into several tasks before anything is persisted, when the input turns out bigger than one well-shaped task.

### 6. The Burn-down
`/burn` starts parallel subagents to work on the next tasks that are available (using the same `<count>@<workers>` mechanic my other skills use). Available = `status: todo` with every `depends_on` done; among available tasks the pick order is simply ascending id. Workers never own the task list — changes to the task files are only written by the orchestrator. Workers use a model corresponding to the estimated complexity of the task (default `low=sonnet, medium=opus, high=opus`, project-overridable via the `.workflow-overrides/model-map` file).

The per-task sequence is: worker implements in its own git worktree and commits via `/commit` → grader → merge → doc-update → closing record. The worker's contract is strict TDD: tests first, implementation until the full suite passes, then `/commit`; it returns a report carrying its manual-testing notes and any deviations from the task's plan — the raw material of the closing record.

**Grading.** A `grader` agent grades the worker's output strictly against the task's acceptance criteria and its linked decisions — nothing else. It reviews the diff and the worker's report; it does not re-run tests (the worker owns tests pre-commit, the merge step re-runs them post-merge). On rejection, the task returns to `todo` with the grader's feedback appended to the task file, and gets one retry by a fresh worker at the next model tier up (a `high` task retries at the same top tier — there is nothing above). A second rejection surfaces to the user and the task stays in `todo` (excluded from this run's later passes, so the run can't loop on it). Escalation happens at most once per task per run, whatever triggered it (grader rejection or post-merge test failure), and the bumped tier is run-state only: after a crash, resume restarts the task at its base tier, with the appended grader feedback still guiding the fresh worker.

**Merging.** A specialized subagent merges accepted results into the workspace sequentially. A textual merge conflict is a bounce, not a quality problem: the task is re-queued for a fresh worker on the updated base at the same model tier. Tests failing after a clean merge escalate to a worker at the next tier up; if that doesn't succeed, the workflow breaks out and surfaces the problem to the user.

**Doc updates.** After a task's merge lands, a `doc-updater` agent updates any documentation that might be stale. Doc-updaters run serialized (one at a time, in landing order), never in parallel — parallel workers exist, parallel doc edits to the same files don't.

**Closing record.** When a task lands, the orchestrator writes the worker's report into the task file: a `## Manual testing` section (how a human can see it working) and a `## Deviations` section (where the implementation departed from the plan). This is the once-written outcome a multi-milestone task shares — every `/land` that covers the task reads this record instead of re-deriving anything from code.

**Oversized tasks.** A worker that discovers its task was underestimated does not push through: it returns an UNDERESTIMATED report with what it learned, and the orchestrator hands the task back to `/enrich` for re-shaping instead of burning tokens on a doomed attempt. Tasks are never split after persistence: `/enrich` narrows the original in place (its id, dependents, and `proves` links stay live) and mints fresh tasks for the carved-off remainder, wiring their `depends_on` and moving any `proves` link the narrowed original no longer delivers.

**Resume.** `/burn` is resumable and idempotent: on start it re-derives the available set, and any task left `in-progress` with no live worktree behind it (a crashed or killed prior run) is reclaimed to `todo`.

### 7. The Landing
`/land` checks the next milestone that has all its tasks done for compliance with its original goal, persists any deviations or oddities in the milestone file, and describes how the outcome can be tested and demoed. Takes the outcomes of all tasks and updates the documentation when necessary (engage in dialog if unsure). Clears the milestone's `proof: pending` decisions after consulting the user (see the proving loop). A milestone whose remaining proof lives in a later milestone's task is reported as exactly that — "blocked on proof: task NNNN (milestone MMMM)" — rather than looking stuck; this cross-milestone wait is the one deliberate synchronization point milestones have. A deviation that contradicts an existing decision is never just recorded — `/land` routes it to `/decide <id>` so the decision is revised or superseded, keeping the decision log truthful.
