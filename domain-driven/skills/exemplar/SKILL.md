---
name: exemplar
description: >
  Brainstorm or ingest a concrete exemplar — a sample config file, dataset, API payload, CLI transcript, UI mock, or similar artifact that pins a piece of the spec down in actual bytes. Trigger whenever the user wants to sketch, draft, brainstorm, or pin down a concrete example artifact — e.g. "let's sketch a sample config", "draft an example dataset", "pin this decision with an example", "what would this payload actually look like", or /exemplar — AND whenever the user brings an artifact that already exists and wants it captured as an exemplar: "ingest this mock", "bring in this design", "pin down this Figma export / Claude Design output / sample HTML", "make this file an exemplar". Also invoked by /architecture-foundation when the human accepts its offer to pin a freshly recorded ADR with an exemplar. Draft mode seeds a fully filled-in strawman via the exemplar-drafter subagent; intake mode annotates the provided artifact instead. Both refine Socratically one open value at a time and write under exemplars/ as `illustrative` — promotion to `normative` (binding for tasks) happens later via /spec-sharpener. Do NOT trigger for code examples in documentation prose or for test fixtures inside an implementation task — those belong to the docs and the task-worker.
argument-hint: "[what to exemplify — e.g. 'a sample pipeline config for the ingestion context' — or a path/paste of an existing artifact to ingest]"
model: opus
allowed-tools: Read, Write, Edit, Glob, Agent, Bash(mkdir -p exemplars*), Bash(cp *)
---

# Exemplar — Pin the Spec Down in Bytes

You brainstorm one **exemplar** with the human: a concrete sample artifact — a config file, a dataset, a request/response payload, an event, a CLI transcript, a UI mock — that makes a piece of the specification falsifiable. An exemplar is the **data twin of an ADR**: an ADR records a decision in prose, an exemplar shows it in bytes. The reason it works is that the human reacts far better to a filled-in strawman than to a blank page — so your job is to put a deliberately opinionated concrete draft on the table and then argue about it, value by value.

The skill has two modes that share everything after the seed:

- **Draft mode** — no artifact exists yet; the `exemplar-drafter` invents an opinionated strawman.
- **Intake mode** — the artifact already exists (a sample HTML page, a Claude Design or Figma export, a screenshot, a captured payload, a file the human points at); nothing is invented — the drafter *annotates* the provided bytes instead, and the interview argues about what's in them.

Write no code and no tasks. One invocation produces one exemplar (or revises an existing one).

## The exemplar convention

```
exemplars/
  exemplars.md            # index: one line per exemplar (slug, status, what it pins, links)
  <slug>/
    <artifact>            # the sample itself, in its NATIVE format (.yaml/.json/.csv/.txt/.html/.png/…)
    …                     # multi-file artifacts (an HTML mock with CSS/assets) keep their files together here
    NOTES.md              # why this shape — frontmatter is the metadata of record
```

`NOTES.md` frontmatter (the metadata of record; the index line mirrors it):

```markdown
---
slug: pipeline-config
status: illustrative        # illustrative | normative
contexts: [ingestion]       # bounded-context slugs, [] if project-wide
related_adrs: [7]           # ADR numbers this exemplar makes concrete, [] if none
source: ~                   # intake only: where the artifact came from (e.g. "Figma frame 'Checkout', exported 2026-07-21"); ~ when drafted in-session
---

## What this pins down
## Deliberately left open
```

**Status semantics — the load-bearing distinction:**

- **`illustrative`** — a strawman that exists to be argued with. It shapes thinking and may be wrong; nothing binds to it. Everything this skill produces starts here.
- **`normative`** — binding. Tasks may cite it in acceptance criteria, `task-worker` lifts it as a first test fixture, and contradicting it is a spec bug. **Only `/spec-sharpener` promotes** — an exemplar becomes normative by surviving a sharpening sweep, never by being freshly brainstormed. Do not set `normative` in this skill.

Linking is **one-way**: the exemplar's `related_adrs` points at the ADRs it makes concrete. Never edit an ADR to point back — decision records are append-only, and the index line carries the ADR numbers for discovery in the other direction.

## Step 0 — Establish the intent (and the mode)

What artifact is being exemplified, and what should it pin down?

- **`$ARGUMENTS` given:** that is the intent (e.g. "a sample pipeline config for the ingestion context").
- **An existing artifact is provided** — a file path, pasted content, or an export dropped into the repo (a sample HTML, a Claude Design output, a Figma frame export/screenshot, a captured payload): this is **intake mode**. The artifact's bytes are the given; establish only what it should *pin down* (which context, which decision, which slice of the spec) — ask if that isn't obvious.
- **Invoked from a session** (typically `/architecture-foundation` after recording an ADR): the anchor is the decision just settled — name it back to the human in one line, with the ADR number(s), so the scope is shared.
- **Neither is clear:** ask one question — *what artifact, pinning what?* — before spawning anything.

**Intake is repo-local.** A live URL to a design tool (a Figma link, a hosted prototype) is not an artifact — it's a moving reference that can't be diffed, grounded, or handed to a task-worker. Ask the human for an export, screenshot, or file instead; the repo copy is what the exemplar pins.

Then read `exemplars/exemplars.md` if it exists. If an exemplar with the same purpose already exists, this run is a **revision** of it, not a duplicate — say so and work on the existing one. (Intaking a fresh export of a design that already has an exemplar is a revision: the new bytes replace the old, the annotations are re-argued where they changed.)

## Step 1 — Seed the strawman (subagent)

Spawn the **exemplar-drafter** subagent (`subagent_type: exemplar-drafter`) with: the intent, the project root, any anchoring ADR number(s) or architecture topic, the target bounded context slug(s) if known, and — on a revision — the existing exemplar directory path.

- **Draft mode:** it returns a proposed slug, native format, a **complete draft artifact with every value filled in** (no placeholders), and an annotation table splitting the values into **grounded** (dictated by vision / domain model / context language / an ADR, with the source named) and **invented** (the drafter had to choose — each one an open question for the interview).
- **Intake mode:** additionally pass the artifact's path (or its content, if pasted and not yet on disk). Tell the drafter to **annotate, not draft** — it returns the same slug + annotation structure computed *over the provided artifact*, plus any **conflicts** between the artifact and the strategic artifacts (a label that isn't the context's ubiquitous-language term, a field an ADR forecloses, a workflow step the domain model doesn't have).

Its reading stays in the subagent; you receive only the proposal.

## Step 2 — Refine it Socratically, one value at a time

Show the human the draft artifact **first, whole** — the point of an exemplar is the gestalt reaction ("that's not what I meant at all" is the most valuable sentence this skill can elicit). Then work through the **invented** values one at a time: for each, say what the drafter chose and why, offer 1–3 alternatives where they genuinely exist, and let the human pick, correct, or generalize ("that field shouldn't exist"). Grounded values need no interview — but if the human contradicts one, stop: that is a conflict with the vision, the model, the context language, or an ADR, and it must not be silently encoded. Name the conflicting source and route it — uphold it (adjust the exemplar) or take the conflict to its owner (`/adr` supersession, a `/domain-model` or `/context-mapping` revision, `/architecture-foundation`) before the exemplar encodes the new answer.

In intake mode the human has usually already seen the artifact, so the gestalt pass is quick — lead with the **conflicts** instead (they are the intake's whole payoff: the mock saying "Submit Order" where the context says "Place Order" is a spec bug caught before a task encodes it), then work the invented values as usual. For UI artifacts, the grounded/invented split falls along a natural line: terms, fields, and workflow steps are grounded in the owning context's language and the domain model; layout, spacing, and visual treatment are the designer's choices — batch the purely visual ones into one *deliberately left open* group rather than interviewing pixel by pixel, unless a design-system ADR makes them binding.

Also settle what the exemplar **deliberately leaves open** — realistic-looking values that are *not* commitments (a sample dataset's row count, an arbitrary hostname). These go in `NOTES.md` under *Deliberately left open* so a later reader doesn't treat incidental detail as binding.

Keep going until the human is happy with every value. This may take several turns — that's the point.

## Step 3 — Write it

1. `mkdir -p exemplars/<slug>` and write the artifact file in its native format. In intake mode, copy the provided file(s) in (`cp` — a multi-file artifact like an HTML mock with CSS/assets keeps all its files; binary files such as screenshots are copied, never transcribed) and apply any corrections the interview settled directly to the repo copy.
2. Write `NOTES.md` with the frontmatter above (`status: illustrative`; in intake mode fill `source:` with where the artifact came from and when), *What this pins down* (one tight paragraph, naming the ADRs/contexts by number/slug), and *Deliberately left open*.
3. Add (or update) the index line in `exemplars/exemplars.md`, creating the file with a `# Exemplars` heading if missing:

   ```
   - `pipeline-config` — [illustrative] sample ingestion pipeline config; pins ADR 7 — contexts: ingestion
   ```

On a revision of a `normative` exemplar, keep its status — normativity survives revision; only a sharpening sweep or a foundation revision changes what is binding.

## When you are done

Report the exemplar written (slug, path, status) in a sentence. Point at the promotion path: `/spec-sharpener` sweeps `exemplars/` alongside the spec docs, and an illustrative exemplar that survives with no findings gets promoted to `normative` — only then may tasks bind to it (acceptance criteria, fixtures). Do not run the sharpener yourself; hand back control.
