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
sync: ~                     # intake only: upstream | detached (see Step 0); ~ when drafted in-session
---

## What this pins down
## Pinned facts              # the grounded values, distilled: terms, fields, enum values, workflow steps — most consumers read this and never open the artifact
## Map                       # large artifacts: one line per screen/section/file — durable anchor → what it shows, what it pins
## Deliberately left open
## Fix upstream              # sync: upstream only — corrections agreed but NOT applied to the bytes
```

**Status semantics — the load-bearing distinction:**

- **`illustrative`** — a strawman that exists to be argued with. It shapes thinking and may be wrong; nothing binds to it. Everything this skill produces starts here.
- **`normative`** — binding. Tasks may cite it in acceptance criteria, `task-worker` lifts it as a first test fixture, and contradicting it is a spec bug. **Only `/spec-sharpener` promotes** — an exemplar becomes normative by surviving a sharpening sweep, never by being freshly brainstormed. Do not set `normative` in this skill.

Linking is **one-way**: the exemplar's `related_adrs` points at the ADRs it makes concrete. Never edit an ADR to point back — decision records are append-only, and the index line carries the ADR numbers for discovery in the other direction.

**`NOTES.md` is the consumption surface.** Downstream agents (`task-analyzer`, `task-worker`) read `NOTES.md` *instead of* the artifact: **Pinned facts** answers most questions (which terms, fields, and steps the exemplar commits to), and **Map** lets the rare consumer that needs actual bytes — a task-worker lifting a test fixture — grep for one anchor and read that fragment only, never the whole file. Map anchors must be **durable**: visible headings, labels, field names, ubiquitous-language terms — never generated ids or selector paths (`#div-3847`), which a re-export regenerates. For a small artifact (a one-screen config, a single payload) the Map may be omitted — the file *is* the fragment.

## Step 0 — Establish the intent (and the mode)

What artifact is being exemplified, and what should it pin down?

- **`$ARGUMENTS` given:** that is the intent (e.g. "a sample pipeline config for the ingestion context").
- **An existing artifact is provided** — a file path, pasted content, or an export dropped into the repo (a sample HTML, a Claude Design output, a Figma frame export/screenshot, a captured payload): this is **intake mode**. The artifact's bytes are the given; establish only what it should *pin down* (which context, which decision, which slice of the spec) — ask if that isn't obvious.
- **Invoked from a session** (typically `/architecture-foundation` after recording an ADR): the anchor is the decision just settled — name it back to the human in one line, with the ADR number(s), so the scope is shared.
- **Neither is clear:** ask one question — *what artifact, pinning what?* — before spawning anything.

**Intake is repo-local.** A live URL to a design tool (a Figma link, a hosted prototype) is not an artifact — it's a moving reference that can't be diffed, grounded, or handed to a task-worker. Ask the human for an export, screenshot, or file instead; the repo copy is what the exemplar pins.

**Intake: never pull the artifact's bytes into your own context.** A design export or capture can be enormous; your session holds the interview, not the file. Settle the slug up front (derive it from the intent; one question to the human if it isn't obvious) and land the bytes at `exemplars/<slug>/` immediately — `cp` provided file(s) in, or `Write` pasted content to disk once, verbatim. From then on the artifact is referenced only by path: pass the path to the drafter, do not `Read` the file yourself, and never quote it back to the human wholesale — they brought it, they've seen it.

**Intake: settle the sync mode.** One question, asked once per exemplar: *will you keep iterating on this artifact in its source tool (Claude Design, Figma, …) and re-export?*

- **`sync: upstream`** — the source tool stays the editing surface. The repo copy is a **byte-exact snapshot** of the export and must stay that way, so a later re-intake is a clean replace-and-diff. Corrections the interview settles are *recorded, not applied*: they go into `NOTES.md` under **Fix upstream** (each with its anchor and the agreed value), the human fixes them in the source tool, and the next export closes them. Known-wrong bytes in the interim are tolerable precisely because the exemplar is `illustrative` — nothing binds to it, and open Fix-upstream items block promotion.
- **`sync: detached`** — the export was a one-time handoff; the repo copy is now the truth and the source tool a scratchpad. Corrections are applied to the bytes (Step 3, via the scribe).

Record the answer as `sync:` in the `NOTES.md` frontmatter. If the human is unsure, default to `upstream` — detaching later is trivial (flip the field, apply the accumulated Fix-upstream list via the scribe); un-detaching is not.

Then read `exemplars/exemplars.md` if it exists. If an exemplar with the same purpose already exists, this run is a **revision** of it, not a duplicate — say so and work on the existing one. (Intaking a fresh export of a design that already has an exemplar is a revision: the new bytes replace the old, the annotations are re-argued where they changed. For a `sync: upstream` exemplar, replace the bytes verbatim and walk the **Fix upstream** list first — tick off the items the new export fixed, keep the rest open. On any re-intake, also have the drafter re-verify the **Map** anchors against the new bytes — a stale pointer is worse than none, because a consumer trusts it.)

## Step 1 — Seed the strawman (subagent)

Spawn the **exemplar-drafter** subagent (`subagent_type: exemplar-drafter`) with: the intent, the project root, any anchoring ADR number(s) or architecture topic, the target bounded context slug(s) if known, and — on a revision — the existing exemplar directory path.

- **Draft mode:** it returns a proposed slug, native format, a **complete draft artifact with every value filled in** (no placeholders), and an annotation table splitting the values into **grounded** (dictated by vision / domain model / context language / an ADR, with the source named) and **invented** (the drafter had to choose — each one an open question for the interview).
- **Intake mode:** additionally pass the repo path where Step 0 landed the artifact — the path only, never inline content. Tell the drafter to **annotate, not draft** — it returns the same slug + annotation structure computed *over the provided artifact*, plus any **conflicts** between the artifact and the strategic artifacts (a label that isn't the context's ubiquitous-language term, a field an ADR forecloses, a workflow step the domain model doesn't have).

Its reading stays in the subagent; you receive only the proposal.

## Step 2 — Refine it Socratically, one value at a time

Show the human the draft artifact **first, whole** — the point of an exemplar is the gestalt reaction ("that's not what I meant at all" is the most valuable sentence this skill can elicit). Then work through the **invented** values one at a time: for each, say what the drafter chose and why, offer 1–3 alternatives where they genuinely exist, and let the human pick, correct, or generalize ("that field shouldn't exist"). Grounded values need no interview — but if the human contradicts one, stop: that is a conflict with the vision, the model, the context language, or an ADR, and it must not be silently encoded. Name the conflicting source and route it — uphold it (adjust the exemplar) or take the conflict to its owner (`/adr` supersession, a `/domain-model` or `/context-mapping` revision, `/architecture-foundation`) before the exemplar encodes the new answer.

In intake mode the human has usually already seen the artifact, so the gestalt pass is quick — lead with the **conflicts** instead (they are the intake's whole payoff: the mock saying "Submit Order" where the context says "Place Order" is a spec bug caught before a task encodes it), then work the invented values as usual. Discuss each value by the drafter's anchor (the label, field, section, or file it names) — never by quoting stretches of the artifact — and collect the agreed corrections as a running list; Step 3 applies them (`sync: detached`) or records them as Fix-upstream items (`sync: upstream`) — you don't edit as you go. For UI artifacts, the grounded/invented split falls along a natural line: terms, fields, and workflow steps are grounded in the owning context's language and the domain model; layout, spacing, and visual treatment are the designer's choices — batch the purely visual ones into one *deliberately left open* group rather than interviewing pixel by pixel, unless a design-system ADR makes them binding.

Also settle what the exemplar **deliberately leaves open** — realistic-looking values that are *not* commitments (a sample dataset's row count, an arbitrary hostname). These go in `NOTES.md` under *Deliberately left open* so a later reader doesn't treat incidental detail as binding.

Keep going until the human is happy with every value. This may take several turns — that's the point.

## Step 3 — Write it

1. **Draft mode:** `mkdir -p exemplars/<slug>` and write the artifact file in its native format from the settled draft. **Intake mode:** the file(s) already landed at `exemplars/<slug>/` in Step 0 (a multi-file artifact like an HTML mock with CSS/assets keeps all its files; binary files such as screenshots are copied, never transcribed). What happens to the settled corrections depends on the sync mode:
   - **`sync: detached`** — spawn the **exemplar-scribe** subagent (`subagent_type: exemplar-scribe`) with the exemplar directory and the correction list — each correction carrying its anchor and the agreed change — and relay any `BLOCKED` corrections back to the human. Do not apply the corrections yourself; reading the artifact to edit it is exactly the context toll the scribe exists to absorb.
   - **`sync: upstream`** — touch nothing: the bytes stay a verbatim snapshot of the export. The corrections become the **Fix upstream** list in `NOTES.md` (one line each: anchor → agreed value), for the human to carry back into the source tool. No scribe.
2. Write `NOTES.md` with the frontmatter above (`status: illustrative`; in intake mode fill `source:` with where the artifact came from and when, and `sync:` with the Step 0 answer) and the sections: *What this pins down* (one tight paragraph, naming the ADRs/contexts by number/slug); *Pinned facts* (the settled **grounded** values distilled from the drafter's annotation table plus the interview's outcomes — terms, fields, enum values, workflow steps, each with its source); *Map* (large artifacts: the drafter's manifest lines — durable anchor → what that screen/section/file shows and pins; assemble it from the drafter's report, never by reading the artifact); *Deliberately left open*; and — `sync: upstream` with corrections outstanding — *Fix upstream*. In upstream mode, write Pinned facts as the *agreed* values even where the bytes still say otherwise — the Fix-upstream list records the delta, and a consumer of NOTES.md must see the truth, not the typo.
3. Add (or update) the index line in `exemplars/exemplars.md`, creating the file with a `# Exemplars` heading if missing:

   ```
   - `pipeline-config` — [illustrative] sample ingestion pipeline config; pins ADR 7 — contexts: ingestion
   ```

On a revision of a `normative` exemplar, keep its status — normativity survives revision; only a sharpening sweep or a foundation revision changes what is binding.

## When you are done

Report the exemplar written (slug, path, status) in a sentence; for `sync: upstream`, also list the open Fix-upstream items so the human can carry them into the source tool. Point at the promotion path: `/spec-sharpener` sweeps `exemplars/` alongside the spec docs, and an illustrative exemplar that survives with no findings gets promoted to `normative` — only then may tasks bind to it (acceptance criteria, fixtures). An open Fix-upstream item is a finding, so an upstream exemplar cannot be promoted until a re-export closes the list. Do not run the sharpener yourself; hand back control.
