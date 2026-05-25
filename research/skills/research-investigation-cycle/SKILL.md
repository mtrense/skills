---
name: research-investigation-cycle
description: >
  Drive pending RESEARCH directives across the research project to completion
  by invoking the research-investigation skill — which forks into a
  research-investigation-worker subagent — in parallel batches where topic
  files don't collide, sequentially within a topic.
disable-model-invocation: true
argument-hint: "[max-directives]   (optional integer; default: run until done or blocked)"
model: opus
allowed-tools: Read, Edit, Glob, Grep, Skill, Bash(git status:*), Bash(git log:*), Bash(grep:*)
---

# Research Investigation Cycle — Parallel Subagents Over RESEARCH Directives

You are the orchestrator for a loop that drives the research project's pending
RESEARCH directives to completion by invoking the **`research-investigation`**
skill once per directive. That skill carries `context: fork` and runs as a
`research-investigation-worker` subagent — the entire investigation, including
the inline web search-fetch-verify loop, happens inside the fork and is
discarded on return. Forks run in parallel **across distinct topic files**
within a batch, then the next batch fires. Within a single topic file,
directives are always processed sequentially — two forks must never touch the
same file.

The motivation is twofold: **context hygiene** (the full search-fetch-verify
transcript and synthesis live inside the forks and are discarded on return)
and **wall-clock speed** (independent topic files investigate concurrently).
The orchestrator stays tiny.

## Prerequisites

1. `research/INDEX.md` exists.
2. At least one topic file under `research/content/` contains a
   `<!-- RESEARCH: ... -->` marker. If none, stop and tell the human.
3. Working tree is clean. Run `git status --porcelain` (plain form — never
   `git -C <path>`, which bypasses the Claude Code permission allowlist). If
   dirty, stop and ask the human to commit or stash first.

## Arguments

`$ARGUMENTS` is optional. If it parses as a positive integer, treat it as the
**maximum number of directives** to attempt this cycle. Otherwise, run until no
pending directives remain or a halt condition fires.

## Loop

Repeat the following until a stop condition triggers.

### Step 1: Enumerate pending directives

Find every `<!-- RESEARCH: ... -->` marker across `research/content/`. Use
**two `Grep` calls only** — no Bash, no `awk`, no `for` loops, no shell
glue:

1. `Grep` for `<!-- RESEARCH:` over `research/content/` with `output_mode:
   content` and `-n: true`. This gives you `(file, line_number)` for every
   pending directive.
2. `Grep` for `^#+ ` over the same path with `output_mode: content` and
   `-n: true`. This gives you `(file, line_number, heading_text)` for every
   markdown heading.

In-context, for each directive match, find the heading from the same file
with the largest `line_number` strictly less than the directive's line
number. That heading is the directive's section.

The result is a list of `(topic_file, section_heading)` tuples. If empty,
exit the loop (success path → Step 5).

Do **not** invent shell pipelines (`awk`, `sed`, per-file `for` loops, etc.)
to compute this — the two Grep calls above contain everything you need.

### Step 2: Build the next batch

A **batch** is a set of `(topic_file, section_heading)` pairs where every
`topic_file` is distinct. Build it greedily: walk the enumerated list and pick
the first pending directive from each topic file you haven't seen yet in this
batch. Cap batch size at **4 forks** (concurrency limit; raise only if the
human asks).

If `$ARGUMENTS` capped the total directive count and you're close to it, shrink
this batch so you don't overshoot.

### Step 3: Pre-flight check

Run `git status --porcelain`. The tree **must** be clean. If it isn't (a
previous fork wrote partial state or stray files appeared), halt and report
the dirty paths to the human. Do not clean up yourself.

Also re-read `research/DECISIONS.md` and note the highest existing `DEC-NNN`
number. You'll use it after the batch to verify monotonic numbering.

### Step 4: Spawn the batch in parallel

Issue one `Skill` call per directive in the batch, **all in a single message**
so the forks run concurrently. Each call uses:

```
Skill(skill="research-investigation",
      args="<topic_file> \"<section_heading>\"")
```

`research-investigation` carries `context: fork` in its frontmatter and is
dispatched as a `research-investigation-worker` subagent. The skill body
contains the full investigation contract — including the inline web loop, the
section-heading scope rule, and the required ` ```report ` exit block — so you
do not need to inject any extra prompt content.

Wait for all forks in the batch to return before continuing.

### Step 5: Post-flight check

For each returned fork, verify in order. Any failure → halt the loop.

1. **Report block present and well-formed.** The fork's final message must end
   with a fenced ` ```report ` block. If missing or malformed, halt with reason
   `fork omitted required report block`.
2. **Fork didn't report HALTED.** Surface the reason verbatim.
3. **Directive removed.** Re-read the fork's `topic_file`. The
   `<!-- RESEARCH: ... -->` marker under `section_heading` must be gone. If it
   still exists, halt.
4. **Prose present.** Some content must exist under the heading (more than just
   a `### References` subheading).
5. **No cross-file collateral damage.** Run `Grep` for the fork's reported
   citation keys — they should appear only in the fork's own topic file and
   its sibling `_references.yaml`. (Cheap sanity check; skip if it gets noisy.)

After all forks in the batch pass:

6. **DECISIONS.md numbering is monotonic.** Read DECISIONS.md and confirm every
   new `DEC-NNN` ID is unique and contiguous with the pre-batch maximum.
   Concurrent forks occasionally race on numbering; if duplicates exist, halt
   with reason `DECISIONS.md numbering collision — manual reconciliation
   needed` and surface the offending IDs to the human. Do not auto-renumber.
7. **Tree state is as expected.** Run `git status --porcelain` — every modified
   path must belong to one of the batch's topic files, its sibling
   `_references.yaml`, `DECISIONS.md`, or `INDEX.md`. Unexpected paths → halt.
8. **Cap not yet hit.** If `$ARGUMENTS` specified a max and you've reached it,
   exit.

If all checks pass, log a one-line progress note for the human per fork
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

- **Parallel across topics, serial within a topic.** Two forks must never open
  the same topic file or its `_references.yaml`. The batch builder in Step 2
  enforces this.
- **Context hygiene is half the point.** The orchestrator should stay tiny.
  Don't read topic content, don't call WebSearch, don't synthesise prose — the
  forked `research-investigation` skill does all of that inside its own
  subagent context, which is discarded on return.
- **Trust the fork's halt.** If a fork halts, do not "try again" or "fix it
  up." Halt the loop and hand control back to the human.
- **Missing-worker failure is cheap.** If `research-investigation-worker`
  isn't installed, the very first `Skill` call returns a clear, immediate
  error naming the unknown subagent — and that's a perfectly fine halt
  signal. There is no batch state to roll back at that point, no wasted web
  fetches, and the human gets an unambiguous error to act on. So treat the
  `Skill` call itself as the verification step; a separate pre-check would
  only duplicate work.
- **DECISIONS.md is a known concurrency hotspot.** Contradictions are rare, so
  in practice batches rarely write to DECISIONS.md at all. When they do, Step 5
  catches numbering collisions and asks the human to reconcile. Don't attempt
  automatic renumbering — DEC IDs may already be referenced from AUDIT comments.
- **No commits.** Forks don't commit. You don't commit. The human reviews
  and runs `/commit`.
- **One topic per fork per batch.** Even if a topic has ten pending
  directives, only one of them appears in any given batch. The next directive
  from that topic ships in the next batch.
