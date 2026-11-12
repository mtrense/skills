---
name: example
description: >
  Pin a piece of a trajectory project's spec down in bytes: draft (or take in) one concrete
  example artifact — a sample workflow/config definition, a payload, a data file, a CLI
  transcript — and settle its invented values with the user one at a time, routing the
  decision-worthy ones to /decide. Writes documentation/examples/NNNN-slug.md (the record:
  what it pins, pinned facts, open values) plus the artifact bytes in
  documentation/examples/NNNN-slug/. Demos list the examples their scenario drives, and the
  demo check reads the bytes in place, so a settled example is the spec the code is checked
  against. Trigger on "/example", "sketch a sample config", "what would the file actually
  look like", "draft an example workflow definition", "write down the CLI as a transcript",
  "pin this down with an example", "take this file in as an example", or when /aim offers
  to pin a scenario's input or surface with an example. Do NOT trigger for code examples in
  user-facing docs (doc-syncer keeps those) or for test fixtures inside a task.
argument-hint: <what to exemplify | path to an existing artifact to take in | example id to revise>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent, Skill, AskUserQuestion
---

# Example — The Spec in Bytes

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument: `$ARGUMENTS` — what to exemplify ("a minimal workflow definition with one escalation", "the CLI for starting and resuming a run"), a path to an artifact that already exists, or an example id to revise. If empty, ask *what artifact, pinning what?* — one question — before spawning anything.

An example is the **data twin of a decision**: a decision says it in prose, an example shows it in bytes. People react far better to a filled-in strawman than to a blank page, so the job is to put a concrete, deliberately opinionated draft on the table and then go through it value by value. Every value ends up either **agreed**, **decided** (a `/decide` record), or **left open** on purpose — never silently assumed.

Write no code and no tasks. One invocation produces or revises one example.

## The convention

```
documentation/examples/
  NNNN-slug.md          # the record — frontmatter is the metadata of record, body is what consumers read
  NNNN-slug/            # the artifact bytes, in their NATIVE format (.json/.yaml/.toml/.md/.csv/…)
    <artifact>          # one or more files; multi-file artifacts stay together here
```

Frontmatter (`backlog.sh new example` writes the skeleton): `title`, `status: draft|settled|retired`, `decisions: []` (decisions this example makes concrete or that settled its values), `artifacts: []` (file names inside the artifact directory — `check` fails if one is missing), `source: null` (intake only: where the artifact came from, and when).

Body:

- `## What this pins down` — one tight paragraph: which part of the spec, which vocabulary terms, which decisions.
- `## Pinned facts` — the settled values distilled, one line each, with where they come from: `- <anchor>: <value> — VISION vocabulary | decision NNNN | agreed`. **This is the consumption surface**: `/enrich`, `burn-worker`, and `grader` read it instead of the artifact. An anchor is durable — a field name, a heading, a command, a vocabulary term — never a line number.
- `## Open values` — the invented values nobody has agreed to yet, as a checklist: `- [ ] <anchor>: <question> (drafted: <value>)`. Settled lines are ticked with how they were settled: `— agreed` or `— decision: NNNN`. `backlog.sh set-status example <id> settled` refuses while any line is unticked.
- `## Left open` — realistic-looking values that are **not** commitments (a sample name, a hash, a timestamp, a row count), so nobody later treats incidental detail as binding. For a transcript, name the output that will vary between runs; the check masks exactly these.
- `## Map` — only for a large artifact: one line per section/file — anchor → what it shows. Small artifacts skip it; the file *is* the fragment.

**Status, and what makes an example binding.** `draft` is a strawman to argue with. `settled` means every value was agreed, decided, or explicitly left open. Binding comes from a demo: a demo lists the examples its scenario drives (`examples: [...]` in its frontmatter), and the demo's check reads the artifact bytes **in place** — never a copy. So the example binds exactly as far as running code is checked against it, and the board shows it as **demonstrated** once a demo listing it is green. A draft example listed by a red demo is an open item: `/enrich` will not break that demo down until the example is settled. `retired` is the tombstone.

## Step 0: Intent and mode

- **Draft mode** — nothing exists yet; the drafter invents a strawman.
- **Intake mode** — the user points at an existing artifact (a hand-written workflow file, a CLI help text, a captured payload, a spec excerpt). Nothing is invented; the drafter annotates the given bytes.
- **Revision** — an example id, or an intent that matches an existing example (check `backlog.sh board`'s EXAMPLES section and the records' titles). Never mint a duplicate: work on the existing one.

Settle the slug (derive it from the intent; ask only if it isn't obvious). In intake mode, land the bytes immediately: `backlog.sh new example <slug> <title>` (relative to this skill's directory: `bash ../_shared/scripts/backlog.sh`), then `cp` the file(s) into the artifact directory — or Write pasted content there once, verbatim. From then on refer to the artifact by path; don't read a large artifact into this session, the drafter does that.

**Pick the artifact form that a check can drive.** The example will be read by a demo check, so prefer forms the check can consume as-is:

- **Definitions, configs, payloads** — the file in its real format, exactly what the entry point will read (`collimator run documentation/examples/0001-hello/hello.json`). If the project has a schema, the example is also its first fixture.
- **CLI surface** — a **transcript**, not a prose reference: a markdown file of `$ <command>` blocks, each followed by the expected output and exit code, in the order a user would run them. A transcript is the spec *and* the assertion — the check replays it and diffs the output (a golden-transcript test; varying output is masked per `## Left open`). A flag/option reference table can sit beside it, but only the transcript is checked.

## Step 1: Seed (subagent)

Spawn the `example-drafter` subagent with: the intent, the project root, the path to `backlog.sh`, the artifact directory, any anchoring decision ids or demo id, and the mode (draft / annotate / revise). It reads `VISION.md` (vocabulary and invariants), `documentation/DECISIONS.md` and the relevant topic digests, existing examples, and the code where the surface already exists — and returns a complete artifact with **every value filled in** (draft mode), plus an annotation table splitting the values into **grounded** (dictated by vocabulary, an invariant, a decision, existing code — source named) and **invented** (it had to choose — each an open question), plus **conflicts** (intake: given bytes that contradict the vocabulary or a decision). Its reading stays in the subagent.

## Step 2: Settle it with the user, one value at a time

Show the draft artifact **whole first** — the gestalt reaction ("that's not what I meant at all") is the most valuable thing this skill can elicit. In intake mode lead with the conflicts instead (a command called `start` where the vocabulary says *run*: a spec bug caught before a task encodes it).

Then work through the invented values one at a time, by anchor. For each, say what was drafted and why, and settle it — the alternatives are a closed set, so pose them with `AskUserQuestion` (the drafted value first, `preview` showing the competing snippets when they are bytes):

- **Agreed** — local to this artifact, cheap to change later: tick it `— agreed`, move the value into `## Pinned facts`.
- **A decision** — the value commits more than this example: other examples, the schema, the code's architecture would have to follow it, or it forecloses an alternative that would be expensive to reverse (canonicalization rules, an id scheme, exit naming conventions, an error model). Invoke `Skill(decide)` with the question and this example's id; on return tick `— decision: NNNN`, add the id to the example's `decisions:` list, and pin the decided value.
- **Left open** — the value is incidental: move it to `## Left open`.
- **Not yet** — the user can't answer now: leave it unticked under `## Open values`. The example stays `draft`.

Grounded values need no interview — but if the user contradicts one, stop: it conflicts with the vocabulary, an invariant, or an accepted decision, and must not be silently encoded. Name the source and route it — keep the source (adjust the example), or take the conflict to its owner (`/kickoff` revision for vocabulary or invariants, `/decide <id>` for a decision) before the example encodes the new answer. Asking *why* a value should be what it is stays in prose; only the pick among concrete alternatives is a closed question (see [Asking the user](../_shared/workflow-overview.md#asking-the-user)).

Collect the agreed changes as a list; apply them to the artifact at the end, not as you go.

## Step 3: Write

1. Draft mode: `backlog.sh new example <slug> <title>` (intake already did), then Write the artifact file(s) into the artifact directory. Apply the agreed changes by anchor (intake: edit only what was agreed; never reformat the given bytes).
2. Fill the record: frontmatter `artifacts:`, `decisions:`, `source:` (intake); the body sections above.
3. If every open value is ticked: `backlog.sh set-status example <id> settled`.
4. **Wire it to a demo** when one is in play: add the id to the demo's `examples:` frontmatter list and reference the artifact path in the scenario step it drives (`1. collimator run documentation/examples/0001-hello/hello.json → …`). If the demo already has tasks, the check task must read the example too — say so and point at `/enrich <demo>`.
5. Run `backlog.sh check`.

## Revising a settled example

A settled example a demo lists is a **scenario contract**, so changing it is a scenario change and goes through the user. Run `backlog.sh by-example <id>` and show which demos drive it, with their status:

- Ask before touching it: *revise it (the demos listing it will be re-checked against the new bytes)* / *keep it, and mint a new example beside it* / *leave it as it is*.
- On revision: `set-status example <id> draft` while the values are open again (that holds back `/enrich` on the red demos listing it), settle as above, then `settled` again. The checks read the bytes in place, so the next `demo-check` decides: a green demo turning red on the new bytes, with no live task to fix it, shows up **STALLED** — `/enrich <demo>` mints the work. That is the honest state; never edit a check to match.
- A **shown** demo is history: it was accepted against the old bytes, and its `## Showing` record stays. If the old behavior must keep working, that is a new task (`/supplement`), not a re-opened demo.
- To abandon an example: `set-status example <id> retired`; `check` warns about red/green demos still listing it.

## Wrap-up

Do **not** commit — this skill runs in the foreground; name the files written (record, artifacts, demo file, any decision files) and leave them for the user to review and commit (`/commit`). Report the example's id, status, and open values; point at the next move — `/decide` for a value parked as a decision, `/aim` to give the example a demo that drives it, or `/enrich <demo>` when the demo it settles was waiting on it.
