---
name: research-audit-cycle
description: >
  Drive `draft` topics through every audit lens to `audited` status by invoking
  research-audit-topic — a context:fork skill that audits one topic across all
  lenses — in parallel batches. One fork per topic; forks run concurrently
  across distinct topics, and each topic's lenses run serially inside its fork.
disable-model-invocation: true
argument-hint: "[max-items][@workers]   (e.g. `8`, `8@4`, `@4`; defaults: no cap, 4 workers)"
model: opus
allowed-tools: Read, Edit, Glob, Grep, Skill, Bash(bash */skills/research-status/research-status.sh *), Bash(git status:*), Bash(git log:*)
---

# Research Audit Cycle — Parallel Whole-Topic Audits

You are the orchestrator for a loop that drives every `draft` topic in the
research project to `audited` status by invoking the **`research-audit-topic`**
skill once per topic. That skill carries `context: fork` and runs as a
`research-audit-worker` subagent — it audits **one topic across every lens**
(consistency, coverage, quality, coherence, graphics) and resolves that topic's
CONFIDENCE markers, all inline, and is discarded on return. Forks run in
parallel **across distinct topics** within a batch, then the next batch fires.

This is the per-item counterpart to running the five standalone `/research-audit-*`
skills by hand: instead of "one lens across all topics," each fork does "all
lenses on one topic," so a topic emerges from its fork fully audited.

The motivation is twofold: **context hygiene** (all lens analysis and CONFIDENCE
verification live inside the forks and are discarded on return) and **wall-clock
speed** (independent topics audit concurrently). The orchestrator stays tiny.

## Prerequisites

1. `research/INDEX.md` exists.
2. At least one topic derives to status `draft`. Status is derived on demand from
   on-disk signals, never stored — run
   `bash <skills-root>/research-status/research-status.sh research --status draft`
   (`<skills-root>` is the `.claude/skills/` directory these skills are installed
   in). If it prints no lines, stop and tell the human (nothing is ready to audit
   — `stub`/`inquiry` topics must be investigated first, and `audited`/`done`
   topics are already done).
3. Working tree must be clean. The output of `git status --porcelain` at skill
   load time is injected below — if the block is non-empty, stop and ask the
   human to commit or stash before proceeding. Do not re-run this command for
   the initial check.

   ```
   !`git status --porcelain`
   ```

## Arguments

`$ARGUMENTS` is optional and has the shape `[<total>][@<workers>]`:

- `<total>` — positive integer; max topics to audit this cycle.
- `<workers>` — positive integer; max parallel forks per batch (the batch-size
  cap in Step 2).

Accepted forms:

- *empty* → no total cap, 4 workers (default).
- `N` → cap at N topics, 4 workers.
- `N@W` → cap at N topics, W workers.
- `@W` → no total cap, W workers.

Anything else (non-integer parts, zero or negative values, extra tokens) → halt
immediately and tell the human the expected shape. Bind the parsed values as
`<total>` and `<workers>` for use in Steps 2 and 5.

## Loop

Repeat the following until a stop condition triggers.

### Step 1: Enumerate draft topics

Run the status helper filtered to `draft` — a filtered run prints no footer, so
its lines are a clean candidate list (first field is the derived status, second
is the topic path relative to `research/content/`):

```
bash <skills-root>/research-status/research-status.sh research --status draft
```

Collect the second field of each line as a candidate topic. The filter already
excludes `stub`/`inquiry` (not ready) and `audited`/`done` (already audited) —
this is what makes the cycle resumable and idempotent: re-deriving `--status
draft` each pass only picks up what still needs auditing.

If the output is empty, exit the loop (success path → Step 6).

### Step 2: Build the next batch

A **batch** is a set of topics with **distinct, non-overlapping paths** — no two
forks may share a file or a directory prefix, since each fork writes AUDIT
comments and status into its topic. Build greedily: walk the enumerated list and
pick topics whose paths don't overlap one already in the batch. Cap batch size at
`<workers>` forks (default 4).

If `<total>` was specified and you're close to it, shrink this batch so you don't
overshoot.

### Step 3: Pre-flight check

Run `git status --porcelain`. The tree **must** be clean. If it isn't (a previous
fork wrote partial state or stray files appeared), halt and report the dirty
paths to the human. Do not clean up yourself.

### Step 4: Spawn the batch in parallel

Issue one `Skill` call per topic in the batch, **all in a single message** so the
forks run concurrently. Each call uses:

```
Skill(skill="research-audit-topic", args="<topic_path>")
```

`research-audit-topic` carries `context: fork` and is dispatched as a
`research-audit-worker` subagent. Its body contains the full audit contract —
all five lenses, CONFIDENCE resolution, the `audit:` frontmatter tracking, and
the required ` ```report ` exit block — so you do not need to inject any extra
prompt content. The worker appends lenses to each file's `audit:` frontmatter;
the topic's derived status becomes `audited` automatically once all four core
lenses are present (there is no status line to flip).

Wait for all forks in the batch to return before continuing.

### Step 5: Post-flight check

For each returned fork, verify in order. Any failure → halt the loop.

1. **Report block present and well-formed.** The fork's final message must end
   with a fenced ` ```report ` block. If missing or malformed, halt with reason
   `fork omitted required report block`.
2. **Fork didn't report HALTED.** Surface the reason verbatim.
3. **AUDIT pass ran.** Re-read the fork's topic file(s). Either AUDIT comments
   were inserted, or the fork's report cleanly states there were no findings —
   both are valid outcomes. A file that is byte-for-byte unchanged **and** whose
   report claims findings is a contradiction → halt.
4. **`audit:` frontmatter advanced.** Each audited file's frontmatter `audit:`
   list must now contain all four core types (`consistency`, `coverage`,
   `quality`, `coherence`). If not, halt with reason `fork did not complete all
   core lenses`. (Once all four are present the topic derives to `audited` on its
   own — there is no INDEX.md status to reconcile.)
5. **Tree state is as expected.** Run `git status --porcelain` — every modified
   path must belong to one of the batch's topics (its file(s) or sibling
   `_references.yaml`). Unexpected paths → halt.
6. **Cap not yet hit.** If `<total>` was specified and you've reached it, exit.

If all checks pass, log a one-line progress note per fork (e.g.
`✓ topic-a.md — audited; 6 AUDIT (2 major), 3 CONFIDENCE resolved`), then loop
back to Step 1.

When you halt mid-loop, the cycle is over for this invocation. Do not retry
inside the same run.

### Step 6: Final summary

When the loop ends — clean exit, cap hit, or halt — print a compact summary:

- Topics audited this cycle (count + a few path examples).
- Draft topics remaining (count).
- AUDIT findings inserted, grouped by type and severity (from the fork reports).
- CONFIDENCE markers resolved vs. left unresolved.
- Whether all eligible topics now derive to `audited` (if so, suggest
  `/research-refine` as the next step to resolve the AUDIT findings).
- The halt reason, if any.

Then remind the human to review the diff and run `/commit` when ready. Do not
commit anything yourself.

## Important Principles

- **Per item, every lens.** The outer loop is over topics; each fork runs all
  lenses on its one topic. This is deliberately the inverse of the standalone
  `/research-audit-*` skills (one lens, all topics). Both reach the same
  `audited` state; use this cycle when you want topics finished one at a time,
  parallelised, and capped.
- **Parallel across topics, serial within a topic.** Two forks must never touch
  the same file or directory — the batch builder in Step 2 enforces this. Within
  a fork the lenses run serially because they all edit the same file.
- **Context hygiene is half the point.** The orchestrator stays tiny. Don't read
  topic content, don't call WebSearch, don't run lens analysis — the forked
  `research-audit-topic` skill does all of that in its own context, discarded on
  return.
- **Trust the fork's halt.** If a fork halts, do not "try again" or "fix it up."
  Halt the loop and hand control back to the human.
- **Missing-worker failure is cheap.** If `research-audit-worker` isn't
  installed, the very first `Skill` call returns a clear, immediate error naming
  the unknown subagent — a fine halt signal, with no batch state to roll back. So
  treat the `Skill` call itself as the verification step; a separate pre-check
  would only duplicate work.
- **No shared-file contention.** Each fork writes only its own topic file(s) and
  their sibling `_references.yaml`, and the batch builder keeps paths
  non-overlapping — there is no INDEX.md status flip to race on, since status is
  derived, never stored. A topic advances to `audited` the moment its fourth core
  lens lands in the `audit:` frontmatter.
- **No commits.** Forks don't commit. You don't commit. The human reviews and
  runs `/commit`.
- **Graphics is supplementary.** A fork may add `graphics` AUDIT comments, but
  `graphics` never gates `audited` status — only the four core lenses do.
