---
name: research-refine-cycle
description: >
  Work through the open AUDIT directives in the research project by spawning
  research-refine-worker subagents in parallel batches — one worker per topic
  file, each resolving that file's AUDITs serially via research-refine. Takes a
  <count|all>@<workers> argument: how many AUDIT directives to resolve and how
  many workers to run per batch. Resumable and idempotent.
disable-model-invocation: true
argument-hint: "[<count>|all][@<workers>]   (e.g. `all`, `12`, `12@3`, `@4`; defaults: all audits, 4 workers)"
model: opus
allowed-tools: Read, Edit, Glob, Grep, Agent, Bash(bash */skills/research-refine-cycle/list-open-audits.sh *), Bash(bash */skills/research-status/research-status.sh *), Bash(git status:*), Bash(git log:*)
---

# Research Refine Cycle — Parallel Workers Over Open AUDIT Directives

You are the orchestrator for a loop that resolves the open `<!-- AUDIT: ... -->`
directives scattered across the research project by spawning
**research-refine-worker** subagents. Each worker owns **one topic file** and
resolves that file's AUDIT directives serially by invoking `research-refine`
once per directive; the worker's web research and prose edits live in its own
context and are discarded on return. Workers run in parallel **across distinct
files** within a batch, then the next batch fires.

Refinement mutates a topic file (and shifts its line numbers) every time it
resolves an AUDIT, so **two workers must never share a file or a directory
prefix** — that would also race on the shared sibling `_references.yaml`. The
batch builder enforces this. Within a file, AUDITs are resolved serially inside
the one worker.

The motivation is the usual pair: **context hygiene** (the orchestrator never
reads topic content, never calls WebSearch, never edits prose) and **wall-clock
speed** (independent files refine concurrently). The orchestrator stays tiny.

## Prerequisites

1. `research/INDEX.md` exists.
2. At least one open AUDIT directive exists (see Step 1). If none, stop and tell
   the human there is nothing to refine.
3. Working tree must be clean. The output of `git status --porcelain` at skill
   load time is injected below — if the block is non-empty, stop and ask the
   human to commit or stash before proceeding. Do not re-run this command for
   the initial check.

   ```
   !`git status --porcelain`
   ```

## Arguments

`$ARGUMENTS` is optional and has the shape `[<count>|all][@<workers>]`:

- `<count>` — positive integer; the max number of AUDIT **directives** to
  resolve this cycle. The literal word `all` (or an empty count) means no cap.
- `<workers>` — positive integer; max parallel workers per batch (also the
  batch-size cap in Step 3).

Accepted forms:

- *empty* → resolve all open AUDITs, 4 workers (default).
- `all` → all open AUDITs, 4 workers.
- `N` → cap at N directives, 4 workers.
- `N@W` → cap at N directives, W workers.
- `all@W` / `@W` → all open AUDITs, W workers.

Anything else (non-integer parts, zero or negative values, extra tokens) → halt
immediately and tell the human the expected shape. Bind the parsed values as
`<count>` (an integer or `all`) and `<workers>` (an integer, default 4).

Track a running **budget** `B`: `<count>` if it is an integer, otherwise
unbounded. Decrement `B` by the number of AUDITs actually resolved after each
batch (from the worker reports).

## Loop

Repeat the following until a stop condition triggers.

### Step 1: Enumerate open AUDIT directives

Run the bundled script to get every open AUDIT directive, ordered by INDEX.md:

```
bash <skill-directory>/list-open-audits.sh research
```

Each output line is `<rel_path>:<lineno>:<type>:<severity>`. Group the lines by
`<rel_path>` — that gives you, per topic file, how many AUDITs are open and of
what type. Keep the INDEX.md order (the script already emits it) so the highest-
priority topics are refined first.

If the output is empty, exit the loop (success path → Step 6).

### Step 2: Confirm the files are refinable

For each candidate file (a `rel_path` with open AUDITs), its **derived** status
must be `draft` or `audited` — those are the only statuses `research-refine`
accepts. Status is derived on demand, never stored; derive a single file's
status by running the helper scoped to it:

```
bash <skills-root>/research-status/research-status.sh research --path <rel_path>
```

(`<skills-root>` is the `.claude/skills/` directory these skills are installed
in; read the first field of the one output line.) Skip (and note) any file whose
derived status is `stub`/`inquiry` (it should not carry AUDITs) so a stray
directive can't wedge the cycle.

### Step 3: Build the next batch

A **batch** is a set of files with **distinct, non-overlapping directory
prefixes** — no two workers may share a file or a directory (they'd race on that
directory's `_references.yaml`). Build greedily over the INDEX-ordered file list,
skipping any file whose directory prefix is already claimed by a file in the
batch. Cap the batch at `<workers>` files (default 4).

Assign each file in the batch a **per-worker cap**: the number of its open
AUDITs, but clamped so the batch's caps don't exceed the remaining budget `B`.
Distribute greedily in INDEX order — give each successive file
`min(its open-AUDIT count, B_remaining_for_this_batch)` and stop adding files
once the batch budget is exhausted. If `B` is unbounded, each file's cap is
simply `all`.

### Step 4: Pre-flight check

Run `git status --porcelain`. The tree **must** be clean. If it isn't (a
previous worker left partial state or stray files appeared), halt and report the
dirty paths to the human. Do not clean up yourself.

### Step 5: Spawn the batch in parallel

Use the `Agent` tool with `subagent_type: research-refine-worker` — one call per
file in the batch, **all in a single message** so the workers run concurrently.
Pass each worker its file and its cap with this prompt template:

```
Resolve the open AUDIT directives in the topic file `<rel_path>`.

cap: <per-worker cap — an integer, or `all`>

Run your standard contract: for each AUDIT (top to bottom, re-scanning after
each), invoke `research-refine` with the file and the operation derived from
the AUDIT's type, up to your cap. Then return your report block. Halt instead
of asking questions — the orchestrator will surface anything you halt on. Do
not commit.
```

Wait for all workers in the batch to return before continuing.

### Step 5b: Post-flight check

For each returned worker, verify in order. Any failure → halt the loop.

1. **Report block present and well-formed.** The worker's final message must end
   with a fenced ` ```report ` block. If missing or malformed, halt with reason
   `worker omitted required report block`.
2. **Worker didn't report HALTED.** Surface the reason verbatim. (A worker that
   resolved some AUDITs before halting still counts those toward `B` — read the
   `Resolved:` line — but the loop stops.)
3. **AUDITs actually cleared.** Re-run `list-open-audits.sh` (or grep the
   worker's file) and confirm the file now has fewer open AUDITs, matching the
   worker's `Resolved:` count. A file byte-for-byte unchanged whose report
   claims resolutions is a contradiction → halt.
4. **DECISIONS.md reconciliation.** Parallel workers may both append to
   `DECISIONS.md` and clobber each other. For every `Decisions:` entry a worker
   reported, confirm it is present in `research/DECISIONS.md`; if a reported
   entry is missing, re-append it yourself with `Edit` (the orchestrator holds
   the verbatim text in the report). Log any re-append. (There is no INDEX.md
   status to reconcile: clearing a file's last AUDIT makes it derive to `done`
   on its own.)
5. **Tree state is as expected.** Run `git status --porcelain` — every modified
   path must belong to one of the batch's files (its topic file or its
   directory's `_references.yaml`), or `DECISIONS.md`. Unexpected paths → halt.
6. **Budget update.** Decrement `B` by the total AUDITs resolved this batch. If
   `B` was an integer and has reached 0, exit the loop (cap hit).

If all checks pass, log a one-line progress note per worker (e.g.
`✓ patterns/human-ai-collaboration.md — 3 AUDIT resolved (2 gap, 1 contradiction); audited → done`),
then loop back to Step 1.

When you halt mid-loop, the cycle is over for this invocation. Do not retry
inside the same run.

### Step 6: Final summary

When the loop ends — clean exit, cap hit, or halt — print a compact summary:

- AUDIT directives resolved this cycle (count + a per-type breakdown).
- Files fully cleared and now deriving to `done` (count + a few path examples).
- Open AUDIT directives remaining across the project (count) — the leftover the
  next `/research-refine-cycle` run will pick up.
- Any `DECISIONS.md` entries you had to re-append.
- Any files skipped because their derived status wasn't `draft`/`audited`.
- The halt reason, if any.

Then remind the human to review the diff and run `/commit` when ready. Do not
commit anything yourself.

## Important Principles

- **The budget counts AUDIT directives; the batch parallelises files.** The
  `<count>` cap is measured in directives resolved, but a worker owns a whole
  file and resolves that file's AUDITs serially. The per-worker caps in Step 3
  are how you keep a directive budget while dispatching whole files.
- **Parallel across files, serial within a file.** Two workers must never touch
  the same file or directory — the batch builder in Step 3 enforces this. Within
  a file the AUDITs resolve serially because each refine rewrites the file and
  shifts line numbers.
- **Context hygiene is half the point.** The orchestrator stays tiny. Don't read
  topic content, don't call WebSearch, don't run refinements — the
  `research-refine-worker` (via `research-refine`) does all of that in its own
  context, discarded on return.
- **Trust the worker's halt.** If a worker halts, do not "try again" or "fix it
  up." Halt the loop and hand control back to the human.
- **Missing-worker failure is cheap.** If `research-refine-worker` isn't
  installed, the first `Agent` call returns a clear, immediate error naming the
  unknown subagent — a fine halt signal, with no batch state to roll back. So
  treat the `Agent` call itself as the verification step; a separate pre-check
  would only duplicate work.
- **DECISIONS.md is the one concurrency hotspot.** There is no INDEX.md status
  flip to race on — status is derived, never stored, so a file advances to `done`
  the moment its last AUDIT is cleared. Parallel decision appends can still race;
  Step 5b.4 catches and repairs that, benign because the orchestrator holds
  enough in the worker reports to re-apply the lost write deterministically.
- **Resumable and idempotent.** The cycle only ever picks up AUDITs that are
  still open (the script re-derives them each Step 1), so re-running after a
  partial run, a cap, or a halt simply continues where it left off.
- **No commits.** Workers don't commit. You don't commit. The human reviews the
  diff and runs `/commit`.
