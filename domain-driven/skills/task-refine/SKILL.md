---
name: task-refine
description: >
  Refine a draft task into a ready `todo`: assess it for spec completeness,
  domain-compliance (against its bounded context's ubiquitous language and
  relationships), and implementation size; interview the human until goal and
  success criteria are shared; split it if it is too big to land in one go; wire
  its dependencies; document the interfaces (HTTP/gRPC/protocols/traits/…) it
  touches and a detailed implementation plan with the files to be touched; and
  surface decisions, offering ADRs and recording the ones
  that affect it. Delegates the read-heavy assessment to the task-analyzer
  subagent. Advances the task(s) draft -> todo (or the original -> split).
disable-model-invocation: true
argument-hint: "[<id>]   (default: the lowest-id draft task)"
model: opus
allowed-tools: Read, Write, Edit, Glob, Agent, Skill, Bash(bash */skills/task-status/tasks.sh *), Bash(date *)
---

# Task Refine — Draft → Todo

You turn a `draft` task into a ready-to-implement `todo`. A `todo` is a task whose
goal and success criteria you and the human both understand, that is small enough
to land in one implementation pass, that fits the domain, and whose dependencies
are wired. Getting there is an **interview**, not a rewrite.

## Step 1 — Pick the task

- If an id was given, refine that one.
- Otherwise, run `bash <skills-root>/task-status/tasks.sh by-status draft` and take
  the lowest id. If there are no drafts, say so and stop.

## Step 2 — Assess (subagent)

Spawn the **task-analyzer** subagent (`subagent_type: task-analyzer`) with the task
file path and the project root. It reads the task, the relevant
`context-map/<context>.md` (and `context-map/INDEX.md` for relationships),
`domain-model.md`, and the decision index (`decisions/INDEX.md` by default, or the
`decision-path:` directory set in `CLAUDE.md`), then returns a structured
assessment:

- **Completeness** — what the spec is missing (unclear outcome, no success
  criteria, hidden ambiguity).
- **Domain-compliance** — does the task fit a bounded context? Does it use that
  context's ubiquitous language correctly? Does it leak across a boundary in a way
  the relationship pattern forbids? Is it phrased as an outcome, or has it slipped
  into premature implementation detail?
- **Size** — does this look like one implementation pass, or several? If several,
  a suggested split.
- **Dependencies** — other tasks (by id) or unbuilt prerequisites this needs.
- **Interfaces** — the interface surfaces the task touches or must introduce
  (HTTP/REST endpoints, gRPC services, message topics/event schemas, and
  in-process contracts: interfaces, traits, protocols), each tagged as *defined*
  (new/changed) or *consumed* (existing).
- **Implementation plan** — a proposed ordered sequence of steps and the concrete
  files to be touched (existing vs new), scouted from the codebase.
- **Decisions** — choices the human must make, and which existing ADRs
  (from the index) already bear on this task.

The subagent reads the corpus so you don't — you receive only its report.

## Step 3 — Interview the human (Socratic, one question at a time)

Work through the assessment with the human, **one question at a time**, reflecting
back what you hear. Drive to:

- A **clear outcome** and concrete **acceptance criteria** you could verify.
- **Domain fit.** If the analyzer flagged a domain conflict, surface it plainly:
  a task that violates the domain means *either the task has the wrong shape / is
  too implementation-oriented* (reshape it) *or the map itself is wrong* (note it
  and tell the human to revisit `/domain-model` or `/context-mapping` — do not
  silently "fix" the task around a broken map).
- The right **context** for the task's frontmatter.
- The **interfaces** the task touches. Confirm the analyzer's list with the human
  and settle, for each, whether the task *defines* the contract (a new/changed
  endpoint, service, topic, event schema, interface/trait/protocol) or merely
  *consumes* an existing one. Note the contract at the granularity known now —
  route + method + shape, service + method, topic + payload, trait/protocol +
  signatures — without designing the implementation. If the task defines a
  contract that crosses a bounded-context boundary, it is often the published
  language of that relationship; if that surfaces a real decision, treat it under
  Step 5 (offer an ADR).
- The **implementation plan**. Walk the analyzer's proposed steps and file list
  with the human, correct anything its scout got wrong (files that don't exist, a
  seam it missed), and settle on an ordered plan the implementer can start from.
  Keep it a plan — steps and files, not code. If refining the plan reveals the task
  is bigger than one pass after all, go back to Step 4 and split.

**Capture what you scope out.** Refinement narrows: to make the task land in one
pass you will often cut functionality out of it — an edge case deferred, a
follow-on capability pushed to "later", a nice-to-have set aside. Anything cut
this way must not evaporate. For each piece of scoped-out functionality, create a
new `draft` task so it stays on the backlog: mint an id (`tasks.sh next-id`, one
at a time) and write `tasks/NNNN-slug.md` in `status: draft` with a short body
capturing the deferred outcome (a later `/task-refine` pass will flesh it out).
Do **not** interview on these drafts now — a draft is a placeholder, not a ready
task. This is different from a **split** (Step 4): a split divides *all* of an
oversized task's work among `todo` children and tombstones the original; scoping-out
*keeps* this task and merely spins off the bits you deliberately dropped as fresh
drafts. If the human isn't sure whether a cut piece is worth keeping, ask — but
default to capturing it.

## Step 4 — Split if too big

If the task can't land in one implementation pass, propose a split and get the
human's agreement on the pieces. When you present the proposed pieces, name each
by its **outcome / slug** (or "child 1 / child 2") — **never** as `0007a` / `0007b`
or any suffix of the original id. That suffix wrongly implies the original id
survives the split; it does not (see below). The `a`/`b` labels also tend to leak
straight into the minted filenames, so keep them out of the conversation entirely.

**Never** derive child ids by suffixing the original (no `0007a` / `0007b`, no
`0007-1`). A split produces genuinely new, top-level tasks: the original becomes an
inert `split` tombstone and each child is minted a fresh sequential id via
`tasks.sh next-id`. This is not a style preference: a file named `0007a-slug.md`
does not match the loader's `NNNN-slug.md` glob, so it is **invisible** to every
`tasks.sh` command — it would never schedule, never count, never check. (The
`check-dag` you run at the end of this step flags any such malformed filename, but
the point is not to create one.) Then, as **two passes**:

**Pass A — create children and tombstone the original.**
1. For each child, mint an id (`tasks.sh next-id`, one at a time) and write a new
   `tasks/NNNN-slug.md` in `status: todo` with its own outcome/criteria and any
   dependency ordering *among the children*.
2. Rewrite the original task to a **tombstone**: set `status: split` and
   `split_into: ["NNNN", ...]` listing the children; leave its body as the record
   of what it was. A tombstone is inert — it schedules nothing.

**Pass B — rewire dependents.** Run
`bash <skills-root>/task-status/tasks.sh dependents <original-id>` to find every
task that had `depends_on: [<original>]`. For each, with the human decide **which
child** (or children) it should now depend on — do not blindly repoint to all
children — and edit its `depends_on` accordingly. Leaving a dependent pointing at
the split tombstone is a bug (`check-dag` will flag it as dangling).

## Step 5 — Decisions & ADRs

For each genuine decision surfaced: if it is significant and expensive to reverse,
**offer** to record it via `Skill(adr)` (never auto-create). For every ADR — newly
recorded or pre-existing — that constrains the task, add its number to the task's
`related_adrs` frontmatter so the implementer inherits it. Add any strategic docs
the implementer needs (e.g. the context file) to `related_documents`.

## Step 6 — Finalize to `todo`

For each resulting task (the single refined task, or each split child), set
`status: todo`, `context: <slug>`, and wire `depends_on` to the ids the interview
identified. The task body must have exactly these sections, in this order and at
these heading levels:

1. `## Outcome` — what is true when the task is done (the shared goal).
   - `### Why this matters` — the value the outcome delivers.
   - `### Acceptance criteria` — concrete, verifiable checks.
2. `## Implementation plan` — ordered steps + files to be touched (see below).
   - `### Interfaces` — the interface surfaces touched (see below).
3. `## Notes` — what the refinement settled (decisions, scoped-out drafts, domain
   fit, anything the implementer should know).
4. `## Closing` — the post-implementation record; leave its subsections as
   placeholders — `/task-cycle` fills them at implementation.
   - `### Manual testing` — placeholder; `/task-cycle` fills it.
   - `### Deviations from plan` — placeholder; `/task-cycle` fills it.

Fill sections 1–3 and their subsections; leave `## Closing` and its subsections as
their placeholders.

In `### Interfaces`, record the interface surfaces the task touches, one per line,
each tagged **define** or **consume** — e.g. `- define — POST /orders (HTTP): {…}
→ 201`, `- define — trait OrderRepository: save, findById`, `- consume — gRPC
PaymentService.Authorize`. This is the contract the implementer must honor, not the
implementation. If the task genuinely touches no interface, write `- None.` so the
absence is explicit rather than an oversight.

In `## Implementation plan`, record the ordered steps the implementer will follow
(TDD-friendly: the test to write, then the change to make it pass) and a **Files**
list naming each file to be touched with its path and a phrase on the change,
marking new files as such — e.g. `- src/orders/api.rs (edit) — add POST /orders
handler`, `- src/orders/repository.rs (new) — OrderRepository trait + impl`. This
is the plan settled in the interview, kept at plan granularity — enough for
`/task-cycle` to start without re-deriving the layout, not line-level code. Note any
file the analyzer marked tentative so the implementer confirms it.

Then **guard the graph:** run `bash <skills-root>/task-status/tasks.sh check-dag`.
If it reports a cycle or a dangling reference, you introduced it — fix the offending
`depends_on` before finishing. Do not leave the backlog with a failing check-dag.

## When you are done

Report: which task(s) are now `todo`, any tombstoned split, any new `draft` tasks
you spun off for scoped-out functionality, the dependencies wired, and any ADRs
recorded or attached. If drafts remain, mention that `/task-refine`
can take the next one. Do not implement anything — `/task-cycle` does that.
