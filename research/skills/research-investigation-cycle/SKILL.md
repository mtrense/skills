---
name: research-investigation-cycle
description: >
  Drive pending RESEARCH directives across the research project to completion
  by spawning research-investigation-worker subagents — in parallel batches
  where topic files don't collide, sequentially within a topic.
disable-model-invocation: true
argument-hint: "[max-directives]   (optional integer; default: run until done or blocked)"
model: opus
allowed-tools: Read, Edit, Glob, Grep, Agent, Bash(git status:*), Bash(git log:*), Bash(grep:*)
---

# Research Investigation Cycle — Parallel Subagents Over RESEARCH Directives

You are the orchestrator for a loop that drives the research project's pending
RESEARCH directives to completion by spawning **research-investigation-worker**
subagents. Workers run in parallel **across distinct topic files** within a
batch, then the next batch fires. Within a single topic file, directives are
always processed sequentially — two workers must never touch the same file.

The motivation is twofold: **context hygiene** (the full search-fetch-verify
transcript, merged source reports, and synthesis live in the workers and are
discarded on return) and **wall-clock speed** (independent topic files
investigate concurrently). The orchestrator stays tiny.

## Prerequisites

1. `research/INDEX.md` exists.
2. At least one topic file under `research/content/` contains a
   `<!-- RESEARCH: ... -->` marker. If none, stop and tell the human.
3. Working tree is clean. Run `git status --porcelain` (plain form — never
   `git -C <path>`, which bypasses the Claude Code permission allowlist). If
   dirty, stop and ask the human to commit or stash first.
4. Do **not** pre-check whether the `research-investigation-worker` subagent is
   installed. Don't glob, don't read agent files, and don't `ls` the agents
   directory via `Bash` either — any form of "verify the agent exists first"
   is forbidden. Just invoke it by name via the `Agent` tool; if it isn't
   installed, the tool call itself will fail with a clear error and you can
   halt then.

## Arguments

`$ARGUMENTS` is optional. If it parses as a positive integer, treat it as the
**maximum number of directives** to attempt this cycle. Otherwise, run until no
pending directives remain or a halt condition fires.

## Loop

Repeat the following until a stop condition triggers.

### Step 1: Enumerate pending directives

Find every `<!-- RESEARCH: ... -->` marker across `research/content/` (use
`Grep` for `<!-- RESEARCH:` with `output_mode: content` and `-n`). For each
match, capture:

- The topic file path (relative to `research/content/`).
- The nearest preceding heading (the directive's section).

The result is a list of `(topic_file, section_heading)` pairs. If empty, exit
the loop (success path → Step 5).

### Step 2: Build the next batch

A **batch** is a set of `(topic_file, section_heading)` pairs where every
`topic_file` is distinct. Build it greedily: walk the enumerated list and pick
the first pending directive from each topic file you haven't seen yet in this
batch. Cap batch size at **4 workers** (concurrency limit; raise only if the
human asks).

If `$ARGUMENTS` capped the total directive count and you're close to it, shrink
this batch so you don't overshoot.

### Step 3: Pre-flight check

Run `git status --porcelain`. The tree **must** be clean. If it isn't (a
previous worker wrote partial state or stray files appeared), halt and report
the dirty paths to the human. Do not clean up yourself.

Also re-read `research/DECISIONS.md` and note the highest existing `DEC-NNN`
number. You'll use it after the batch to verify monotonic numbering.

### Step 4: Spawn the batch in parallel

Use the `Agent` tool with `subagent_type: research-investigation-worker` —
one call per directive in the batch, **all in a single message** so they run
concurrently. The worker subagent carries its own contract; you only need to
pass the topic file and section heading via the standard prompt below.

Use this prompt template per worker:

```
Investigate the RESEARCH directive in `<topic_file>` under section heading:

    <section_heading>

Run your standard contract: invoke `research-investigation` with these
arguments, then return your report block. Halt instead of asking questions —
the orchestrator will surface anything you halt on. Do not commit.
```

Wait for all workers in the batch to return before continuing.

### Step 5: Post-flight check

For each returned worker, verify in order. Any failure → halt the loop.

1. **Report block present and well-formed.** The worker's final message must
   end with a fenced ` ```report ` block. If missing or malformed, halt with
   reason `worker omitted required report block`.
2. **Worker didn't report HALTED.** Surface the reason verbatim.
3. **Directive removed.** Re-read the worker's `topic_file`. The
   `<!-- RESEARCH: ... -->` marker under `section_heading` must be gone. If it
   still exists, halt.
4. **Prose present.** Some content must exist under the heading (more than just
   a `### References` subheading).
5. **No cross-file collateral damage.** Run `Grep` for the worker's reported
   citation keys — they should appear only in the worker's own topic file and
   its sibling `_references.yaml`. (Cheap sanity check; skip if it gets noisy.)

After all workers in the batch pass:

6. **DECISIONS.md numbering is monotonic.** Read DECISIONS.md and confirm every
   new `DEC-NNN` ID is unique and contiguous with the pre-batch maximum.
   Concurrent workers occasionally race on numbering; if duplicates exist, halt
   with reason `DECISIONS.md numbering collision — manual reconciliation
   needed` and surface the offending IDs to the human. Do not auto-renumber.
7. **Tree state is as expected.** Run `git status --porcelain` — every modified
   path must belong to one of the batch's topic files, its sibling
   `_references.yaml`, `DECISIONS.md`, or `INDEX.md`. Unexpected paths → halt.
8. **Cap not yet hit.** If `$ARGUMENTS` specified a max and you've reached it,
   exit.

If all checks pass, log a one-line progress note for the human per worker
(e.g. `✓ topic-a.md § "Foo bar" — 412 words, 3 cites`), then loop back to
Step 1.

When you halt mid-loop, the cycle is over for this invocation. Do not retry
inside the same run.

### Step 6: Final summary

When the loop ends — clean exit, cap hit, or halt — print a compact summary:

- Directives completed this cycle (count + a few `topic_file § section` examples).
- Directives remaining (count, grouped by topic file).
- Topic files whose INDEX.md status advanced (`inquiry → draft`, etc.).
- New `DEC-NNN` entries appended to DECISIONS.md.
- Whether all topic files are now at `draft` or beyond (if so, suggest the
  audit skills: `/research-audit-consistency`, `/research-audit-coverage`,
  `/research-audit-quality`, `/research-audit-coherence`).
- The halt reason, if any.

Then remind the human to review the diff and run `/commit` when ready. Do not
commit anything yourself.

## Important Principles

- **Parallel across topics, serial within a topic.** Two workers must never
  open the same topic file or its `_references.yaml`. The batch builder in
  Step 2 enforces this.
- **Context hygiene is half the point.** The orchestrator should stay tiny.
  Don't read topic content, don't call WebSearch, don't synthesise prose — that
  is what the workers (and their `source-investigator` subagents) are for.
- **Trust the worker's halt.** If a worker halts, do not "try again" or
  "fix it up." Halt the loop and hand control back to the human.
- **DECISIONS.md is a known concurrency hotspot.** Contradictions are rare, so
  in practice batches rarely write to DECISIONS.md at all. When they do, Step 5
  catches numbering collisions and asks the human to reconcile. Don't attempt
  automatic renumbering — DEC IDs may already be referenced from AUDIT comments.
- **No commits.** Workers don't commit. You don't commit. The human reviews
  and runs `/commit`.
- **One topic per worker per batch.** Even if a topic has ten pending
  directives, only one of them appears in any given batch. The next directive
  from that topic ships in the next batch.
