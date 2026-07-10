---
name: research-inquiry-cycle
description: >
  Drive all stub topics in the research project to `inquiry` status by spawning
  research-inquiry-worker subagents in parallel batches — one worker per stub
  topic, since inquiry never collides at the topic-file level.
disable-model-invocation: true
argument-hint: "[max-topics]   (optional integer; default: run until done or blocked)"
model: opus
allowed-tools: Read, Edit, Glob, Grep, Agent, Bash(bash */skills/research-status/research-status.sh *), Bash(git status:*), Bash(git log:*)
---

# Research Inquiry Cycle — Parallel Subagents Over Stub Topics

You are the orchestrator for a loop that drives every `stub` topic in the
research project to `inquiry` status by spawning **research-inquiry-worker**
subagents. Workers run **fully in parallel within a batch** — each worker owns
exactly one topic file, so there is no within-topic serialisation to worry
about (unlike the investigation cycle).

The motivation is twofold: **context hygiene** (the outline-design reasoning
and any preliminary research lives in the workers and is discarded on return)
and **wall-clock speed** (independent stub topics inquire concurrently). The
orchestrator stays tiny.

## Prerequisites

1. `research/INDEX.md` exists.
2. At least one topic derives to status `stub`. Status is derived on demand from
   on-disk signals, never stored — run
   `bash <skills-root>/research-status/research-status.sh research --status stub`
   (`<skills-root>` is the `.claude/skills/` directory these skills are installed
   in). If it prints no lines, stop and tell the human.
3. Working tree is clean. Run `git status --porcelain` (plain form — never
   `git -C <path>`, which bypasses the Claude Code permission allowlist). If
   dirty, stop and ask the human to commit or stash first.

## Arguments

`$ARGUMENTS` is optional. If it parses as a positive integer, treat it as the
**maximum number of topics** to attempt this cycle. Otherwise, run until no
stub topics remain or a halt condition fires.

## Loop

Repeat the following until a stop condition triggers.

### Step 1: Enumerate stub topics

Run the status helper filtered to `stub` — a filtered run prints no footer, so
its lines are a clean candidate list (first field is the derived status, second
is the topic path relative to `research/content/`):

```
bash <skills-root>/research-status/research-status.sh research --status stub
```

Collect the second field of each line as a candidate topic file.

If the output is empty, exit the loop (success path → Step 5).

### Step 2: Build the next batch

A **batch** is a set of stub topic files, each owned by exactly one worker.
Inquiry writes only to the topic file itself (its headings + RESEARCH
directives), and no two workers share a topic file, so there is no shared-file
contention within a batch.

Cap batch size at **4 workers** (concurrency limit; raise only if the human
asks). If `$ARGUMENTS` capped the total topic count and you're close to it,
shrink this batch so you don't overshoot.

### Step 3: Pre-flight check

Run `git status --porcelain`. The tree **must** be clean. If it isn't (a
previous worker wrote partial state or stray files appeared), halt and report
the dirty paths to the human. Do not clean up yourself.

### Step 4: Spawn the batch in parallel

Use the `Agent` tool with `subagent_type: research-inquiry-worker` — one call
per topic in the batch, **all in a single message** so they run concurrently.
The worker subagent carries its own contract; you only need to pass the topic
file and the standard prompt below.

Use this prompt template per worker:

```
Produce the section outline for the stub topic `<topic_file>`.

Run your standard contract: invoke `research-inquiry` with this argument,
then return your report block. Halt instead of asking questions — the
orchestrator will surface anything you halt on. Do not commit.
```

Wait for all workers in the batch to return before continuing.

### Step 5: Post-flight check

For each returned worker, verify in order. Any failure → halt the loop.

1. **Report block present and well-formed.** The worker's final message must
   end with a fenced ` ```report ` block. If missing or malformed, halt with
   reason `worker omitted required report block`.
2. **Worker didn't report HALTED.** Surface the reason verbatim.
3. **Outline present.** Re-read the worker's `topic_file`. It must contain at
   least 3 `##` headings, each followed by exactly one `<!-- RESEARCH: ... -->`
   directive. If the file looks unchanged or the directives are missing, halt.
4. **No leftover prose.** Inquiry produces headings + directives only. If the
   worker accidentally wrote prose under headings, halt with reason
   `worker wrote prose during inquiry phase`.

After all workers in the batch pass:

5. **Tree state is as expected.** Run `git status --porcelain` — every modified
   path must be one of the batch's topic files. (There is no INDEX.md status to
   reconcile: once a worker writes its outline, that topic derives to `inquiry`
   automatically on the next helper run.) Unexpected paths → halt.
6. **Cap not yet hit.** If `$ARGUMENTS` specified a max and you've reached it,
   exit.

If all checks pass, log a one-line progress note for the human per worker
(e.g. `✓ topic-a.md — 5 sections, 12 directives`), then loop back to Step 1.

When you halt mid-loop, the cycle is over for this invocation. Do not retry
inside the same run.

### Step 6: Final summary

When the loop ends — clean exit, cap hit, or halt — print a compact summary:

- Topics inquired this cycle (count + a few `topic_file` examples).
- Stub topics remaining (count — re-derive with `--status stub`).
- Whether all topics now derive to `inquiry` or beyond (if so, suggest
  `/research-investigation-cycle` as the next step).
- The halt reason, if any.

Then remind the human to review the diff and run `/commit` when ready. Do not
commit anything yourself.

## Important Principles

- **One topic per worker, fully parallel within a batch.** Unlike the
  investigation cycle, there is no within-topic serialisation: inquiry runs
  exactly once per topic file.
- **Context hygiene is half the point.** The orchestrator should stay tiny.
  Don't read topic content, don't design outlines, don't call WebSearch — that
  is what the workers (and `research-inquiry`) are for.
- **Trust the worker's halt.** If a worker halts, do not "try again" or
  "fix it up." Halt the loop and hand control back to the human.
- **Missing-worker failure is cheap.** If `research-inquiry-worker` isn't
  installed, the very first `Agent` call returns a clear, immediate error
  naming the unknown subagent — and that's a perfectly fine halt signal. There
  is no batch state to roll back at that point and the human gets an
  unambiguous error to act on. So treat the `Agent` call itself as the
  verification step; a separate pre-check would only duplicate work.
- **No shared-file contention.** Each worker writes only its own topic file, so
  there is no INDEX.md status flip to race on — status is derived, never stored.
  A topic advances to `inquiry` the moment its outline lands on disk.
- **Resumable and idempotent.** The cycle re-derives the `stub` set each pass
  (Step 1's `--status stub` run), so re-running after a partial run, a cap, or a
  halt simply picks up whatever still derives to `stub`.
- **No commits.** Workers don't commit. You don't commit. The human reviews
  and runs `/commit`.
- **Inquiry only.** Do not let workers write prose, investigate sources, or
  touch DECISIONS.md / glossary.md. Those belong to later phases.
