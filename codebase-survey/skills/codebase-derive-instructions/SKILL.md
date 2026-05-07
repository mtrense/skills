---
name: codebase-derive-instructions
description: >
  Read the assembled codebase survey (CODEBASE.md files, docs/codebase/*.md,
  assessment findings) and produce a lean, source-anchored CLAUDE.md at the
  repo root plus one per module that has rules. Lifts kind:rule findings
  only; observations stay in assessment.md. Verifies length budgets, rule
  duplication, and code-style leaks before writing. If AGENTS.md exists at
  the repo root, derive into AGENTS.md instead and write a thin CLAUDE.md
  that imports it.
disable-model-invocation: true
argument-hint: "(no arguments)"
model: opus
allowed-tools: Read, Write, Glob, Grep, Edit, Bash(git rev-parse:*), Bash(wc:*), Bash(ls:*)
---

# Codebase Derive Instructions

You read a completed codebase survey and produce `CLAUDE.md` at the repo root
plus one `<module>/CLAUDE.md` per module **that has module-specific rules or
local commands**. The derived files are lean and contain only instructions
Claude Code actually needs at conversation start — not a recap of the survey.

## What CLAUDE.md is for (and what it isn't)

`CODEBASE.md` is the source-of-truth survey: module map, dependencies, API
surface, tests, ops, observations, full assessment. It is **on-demand**
reading — Claude opens it when relevant.

`CLAUDE.md` is the **instruction sheet** loaded into every session. It must
answer "how do I work in this repo?" — operational commands, hard rules,
gotchas — without re-stating the survey. A reader of CLAUDE.md should never
think "this is just a wrapper around CODEBASE.md."

Concretely:

- **Do not `@import` `CODEBASE.md`, `docs/codebase/*.md`, or `README.md`
  into the derived files.** `@<path>` in CLAUDE.md eagerly inlines that
  file's full contents into every session — exactly the bloat we are trying
  to avoid. Use plain markdown references (e.g., `` see `CODEBASE.md` ``)
  so Claude reads them only when it needs to.
- **Lift only what Claude must follow**, not what it can discover. Build
  commands, hard rules, and non-default workflows belong in CLAUDE.md.
  Tech-stack rationale, module internals, and observations do not.
- If a module's only "content" would be a pointer to its `CODEBASE.md`,
  **do not write a CLAUDE.md for that module**. An empty wrapper is
  strictly worse than no file.

The skill is a consumer of survey output, not a producer of new findings.
If something looks wrong in the survey, surface it and stop — go fix the
survey upstream rather than papering over it here.

## Prerequisites

1. Top-level `CODEBASE.md` exists.
2. Per-module `<path>/CODEBASE.md` files exist (or the project is a confirmed
   single-module repo).
3. `docs/codebase/assessment.md` exists with findings tagged `kind: rule` or
   `kind: observation`. If absent, ask the user whether to proceed without
   assessment-driven boundaries (the resulting CLAUDE.md will be thinner but
   still useful) or run `/codebase-architecture-assessment` first.

## Phase Workflow

### Step 1: Select the root-file target

This step **selects a target — it does not finish the workflow.** Steps 2–8
run in full regardless of which root file is chosen, and per-module
`<module>/CLAUDE.md` derivation (Steps 4 & 7) is unaffected by the choice.
Do not stop after this step.

Check whether `AGENTS.md` exists at the repo root and set the root-file
target accordingly:

- **AGENTS.md absent** (default): root file is `CLAUDE.md` at the repo root.
- **AGENTS.md present**: root file is `AGENTS.md`. The skill (over)writes
  it with derived content (same way it would write `CLAUDE.md`). A thin
  pointer `CLAUDE.md` is also written so Claude Code defers to AGENTS.md
  — that file's template lives in Step 7.

  Hand-authored guard: if the existing `AGENTS.md` has **no**
  `derived_from_survey_sha` in its front-matter, treat it as wholly
  hand-authored. Halt and ask the user how to proceed (typically: rename
  the existing file out of the way, or accept overwrite) before continuing.
  Files that already carry the derive front-matter — even if originally
  seeded from hand-authored content — may be (re)written.

The rest of this document refers to "the root file" — substitute `AGENTS.md`
when in the interop case.

### Step 2: Read the survey

Load:

- Top-level `CODEBASE.md`.
- Every `<module>/CODEBASE.md` referenced in the module map.
- `docs/codebase/assessment.md` (this is where rules live — it's the
  primary input for everything that ends up in the derived files).
- `docs/codebase/architecture.md`, `docs/codebase/tech-stack.md`,
  `docs/codebase/operations.md` — read to confirm a rule's context, never
  to harvest content for the derived files.
- The README at the repo root, only to compose the one-line project-identity
  sentence.

Capture each source's `surveyed_sha` from its front-matter — you'll record
the latest one as `derived_from_survey_sha` so future updates can detect
drift.

### Step 3: Plan the root file

The root file is loaded into every Claude Code session. Budget: ≤ 150 lines
in the file body (excluding front-matter and trailing newline). Because
nothing is `@import`ed except the AGENTS.md interop case, the file body
*is* the launch context — keep it tight.

Use this fixed section order. **Omit a section entirely if it has no content
— do not write empty headers, and do not invent material to fill them.** A
short CLAUDE.md is a feature, not a defect.

1. **Project identity** — One inline sentence. No imports. The sentence
   names the kind of thing, the primary language/runtime, and the primary
   value, drawn from the README and the top-level `CODEBASE.md`.

   ```markdown
   # <Project Name>

   <One-line: kind of thing it is, primary language, primary value.>
   ```

2. **Build & test commands** — Verbatim, only the commands a contributor
   actually runs. Each line ends with an HTML comment pointing to its
   source. Pull from manifest scripts (`package.json scripts`,
   `Cargo.toml [aliases]`, `Makefile` targets,
   `pyproject.toml [tool.poetry.scripts]`). Skip duplicates and
   never-invoked aliases.

   ```markdown
   ## Build & Test

   - `pnpm install` — install dependencies <!-- from: package.json, surveyed_sha=abc123 -->
   - `pnpm build` — full build <!-- from: package.json scripts.build, surveyed_sha=abc123 -->
   - `pnpm test` — run all tests <!-- from: package.json scripts.test, surveyed_sha=abc123 -->
   - `pnpm lint` — lint <!-- from: package.json scripts.lint, surveyed_sha=abc123 -->
   ```

3. **Where things live** — Optional, and only when modules are not
   self-evident from the directory layout. One line per module, max one
   phrase. End with a plain reference to `CODEBASE.md`. Skip the entire
   section in single-module repos or when names like `frontend/` and
   `backend/` already say enough.

   ```markdown
   ## Where Things Live

   - `packages/api` — HTTP gateway (Express, port 8080)
   - `packages/core` — domain logic (pure TS)
   - `packages/db` — persistence (Prisma + Postgres)

   Full module map: `CODEBASE.md`.
   ```

4. **Boundaries** — Three subsections from `kind: rule` findings only.
   Skip findings tagged `kind: observation` — they stay in assessment.md.
   Phrase each rule as imperative. If a subsection has no rules, omit it
   (and omit the whole section if all three are empty).

   ```markdown
   ## Boundaries

   ### Always
   - <imperative rule> <!-- from: docs/codebase/assessment.md F-003, surveyed_sha=abc123 -->

   ### Ask first
   - <rule that gates an action on user confirmation> <!-- from: ... -->

   ### Never
   - <prohibitive rule> <!-- from: ... -->
   ```

5. **Git workflow** — Only if non-default. If the project uses standard
   PR-based workflow, omit this section. Include only when the assessment
   surfaced a workflow rule (e.g., "all commits go through `/commit`",
   "merges to main require `make verify`").

6. **See also** — Optional. A short bulleted list of *plain* file
   references (no `@`) for files Claude can open on demand. Include only
   when a path is non-obvious; skip the section otherwise.

   ```markdown
   ## See Also

   - `CODEBASE.md` — module map and per-module surveys
   - `docs/codebase/architecture.md` — system design
   - `docs/codebase/operations.md` — CI/CD, deploys, observability
   - `docs/codebase/assessment.md` — full assessment (incl. observations)
   ```

   The leading `` ` ``-quoted paths are intentional — they make it obvious
   these are files to open, not content to inline.

### Step 4: Plan per-module files

Per-module derivation runs in every invocation — it is independent of the
root-file target selected in Step 1. Visit every module listed in the
top-level `CODEBASE.md` module map and decide for each whether it qualifies.

A module only gets a `<module>/CLAUDE.md` when it has **module-specific
instructions** that aren't already captured at the root. "Module exists"
is not a reason to write a file. Skip a module entirely when:

- It has no Architectural Deviations in its `<module>/CODEBASE.md`.
- It has no module-only commands (per-module test runner, generator,
  etc.) beyond the root command set.
- The only thing you would write is a pointer to `<module>/CODEBASE.md`.

When a module *does* qualify, write a `<module>/CLAUDE.md` with budget
≤ 60 lines. Section order:

1. **Local commands** — only if the module has commands beyond the root set
   (e.g., a per-module test command, a generator). Skip otherwise.
2. **Boundaries** — pulled verbatim from this module's `Architectural
   Deviations` section in `<module>/CODEBASE.md`. Add the source-anchor
   comment. Skip the section if there are none.

No `@import`. No "see also" pointer to `<module>/CODEBASE.md` — Claude Code
already knows to look there when working in the subtree.

Example:

```markdown
---
derived_from_survey_sha: <SHA>
derived_at: <YYYY-MM-DD>
derive_schema: 1
---

# packages/api — Local Notes

## Boundaries
- Never call `core/internal/*` directly from a route handler — always go
  through the public `core` API. <!-- from: packages/api/CODEBASE.md#architectural-deviations, surveyed_sha=abc123 -->
```

If you find yourself writing a file with only a header and no rules or
commands, stop and skip the module instead. An empty wrapper is strictly
worse than no file: it costs lines in every session that touches the
subtree, and it reads like a stub waiting to be filled.

### Step 5: Apply content discipline

Use this table when deciding what to derive. When in doubt, leave it out —
the survey is the source of truth, not the derived file.

| Survey input | Derived? | Notes |
|---|---|---|
| Build/test commands (from manifests, CI) | Yes, verbatim | The single highest-signal section |
| Project map / module boundaries | At most a 1-phrase-per-module section, optional | Skip when names are self-evident; never duplicate `CODEBASE.md` |
| Tech-stack rationale | No | Lives in `docs/codebase/tech-stack.md`; reference by path if Claude must know it exists |
| Architectural Deviations (per-module) | Yes, as module Boundaries | Exactly the gotchas CLAUDE.md exists for |
| Assessment findings | Only `kind: rule` | `kind: observation` stays in assessment.md |
| Open Questions | No | Not yet decided → not a rule |
| Code style | No | Linter's job; reference the linter config instead |
| API surface | No | Discoverable on demand |
| Operations / secrets | Only the "always do X before commit" subset | Rest stays in `docs/codebase/operations.md` |
| `CODEBASE.md` body (any of it) | No | Never `@import`, never paraphrase; mention by path when Claude needs to know it exists |

### Step 6: Verify before writing

Run these checks. Surface failures to the user; do not auto-fix silently.

1. **No stray `@imports`.** Scan every planned file for lines beginning
   with `@`. The only sanctioned occurrence is `@AGENTS.md` in the thin
   root-level CLAUDE.md of the AGENTS.md interop case (Step 1). Anywhere
   else — `@CODEBASE.md`, `@README.md`, `@docs/...`, `@<module>/CODEBASE.md`
   — is a halt: rewrite that section as plain text or drop it. If a path
   reference is genuinely useful, write it as `` `path/to/file.md` `` in
   prose, not as an import.

2. **File-reference paths resolve.** For each backtick-quoted token that
   looks like a file path (contains `/` or ends with a known extension like
   `.md`, `.toml`, `.yaml`, `.json`), confirm the path exists relative to
   the repo root. This catches the See Also section and inline pointers
   like `` `CODEBASE.md` ``, but skips command tokens like `` `pnpm test` ``.
   Halt on broken references — fix the path, don't write a dangling
   pointer.

3. **Length budgets.**
   - Root file: count body lines (excluding YAML front-matter). If > 150,
     report and ask the user how to shed material before writing.
   - Per-module file: > 60 lines → same response.

4. **Rule duplication.** For each derived rule, similarity-check against
   the corresponding `CODEBASE.md` body. A near-verbatim copy of survey
   prose is a smell — either the rule is mis-phrased (reformulate as an
   imperative) or the survey itself is doing rule-work it shouldn't.
   Surface as a warning so the user can decide.

5. **Code-style heuristic scan.** Search the planned content for indicators
   that suggest a code-style rule snuck in: substrings like `tabs`, `spaces`,
   `indent`, `camelCase`, `snake_case`, `naming convention`, `PascalCase`,
   `2-space`, `4-space`. Flag every hit for human review — these usually
   shouldn't be in CLAUDE.md (the linter handles them).

6. **Rule count ceiling.** Total derived rules across root + all module
   files. If > 100, warn that adherence drops past frontier-model
   thresholds. > 150 is a hard halt — ask the user to triage before writing.

7. **Source-anchor coverage.** Every derived rule must carry a block-level
   HTML comment naming its source and `surveyed_sha`. Halt on any rule
   without one.

8. **Empty-file guard.** No file in the write set may consist solely of
   front-matter and a header (no rules, no commands). If one would, drop
   it from the write set instead.

### Step 7: Write the files

Pass verification → write. Failures from Step 6 → halt and explain. Never
write a partial set on verification failure: either all planned files write,
or none.

Front-matter on every file written:

```markdown
---
derived_from_survey_sha: <git SHA at derivation>
derived_at: <YYYY-MM-DD>
derive_schema: 1
---
```

If a target file already exists with the same body modulo `derived_at`, do
**not** rewrite it — re-running on unchanged sources is a no-op. Bump
`derived_at` only if any other content changed.

**AGENTS.md interop case** — when AGENTS.md is the root-file target, write
the derived content to `AGENTS.md` and *additionally* write a thin pointer
`CLAUDE.md` at the repo root with this exact shape:

```markdown
---
derived_from_survey_sha: <SHA>
derived_at: <YYYY-MM-DD>
derive_schema: 1
---

@AGENTS.md

## Claude Code

<Claude-specific addenda only — e.g., references to specific skills like
/commit or /implementation-cycle. Omit the section entirely if no
Claude-specifics apply.>
```

This is the **only** sanctioned `@import` the skill produces. Do not place
derived content (build commands, boundaries, etc.) inside this thin
`CLAUDE.md` — that content goes into `AGENTS.md`.

Per-module `<module>/CLAUDE.md` files (from Step 4) are written in this
case too, exactly as they would be without AGENTS.md.

### Step 8: Hand off

Report:

- Files written (path + line count) — both root and per-module.
- Files left unchanged (same body modulo `derived_at`).
- **Every module from the top-level module map**, classified as either
  *written* or *deliberately skipped* (no rules, no local commands).
  Listing every module explicitly proves the per-module pass actually
  ran and lets the user spot anything the skill missed.
- Any verification warnings (length, duplication, code-style hits, rule
  count) that the user opted to accept.
- Confirmation that re-running `/codebase-survey-update` is the right next
  step when sources move.

Do **not** commit.

## Operating Modes

- **First derivation**: no prior `CLAUDE.md` (or AGENTS.md). Write everything
  from scratch.
- **Re-derivation after `/codebase-survey-update`**: existing files are
  rewritten in place. The `git diff` shows what changed; review happens
  there, not in this skill.
- **Drift detection**: if any per-module `<module>/CLAUDE.md` references a
  `derived_from_survey_sha` that doesn't match the corresponding
  `<module>/CODEBASE.md`'s `surveyed_sha`, surface it before rewriting — the
  user may want to know which modules drifted and why.

## Important Principles

- **CLAUDE.md is instructions, not a manifest.** The survey (`CODEBASE.md`,
  `docs/codebase/*.md`) describes the codebase. CLAUDE.md tells Claude how
  to act in it. If a line could have come from a project guidebook, it
  belongs in the survey, not here.
- **No `@imports` of survey content.** Don't `@CODEBASE.md`,
  `@<module>/CODEBASE.md`, `@docs/codebase/*.md`, or `@README.md`. Those
  files are read on demand. The only sanctioned `@import` is `@AGENTS.md`
  in the thin root CLAUDE.md of the AGENTS.md interop case.
- **Lift, don't author.** Every line in the derived files traces back to a
  specific `CODEBASE.md` or assessment finding via the source-anchor
  comment. If you cannot anchor it, do not write it.
- **Rules ≠ observations.** Only `kind: rule` lifts. The cost of a noisy
  CLAUDE.md is paid on every conversation; the cost of a too-thin CLAUDE.md
  is one occasional question.
- **Skip beats stub.** When a section, module, or even a whole CLAUDE.md
  would have nothing real to say, omit it. Empty headers and pointer-only
  files are pure overhead.
- **Verify before write.** A stray `@import`, a length blow-out, or a
  code-style rule slipping through is much harder to clean up after the
  fact than to catch at the gate.
- **Idempotent.** Re-running on unchanged sources is a no-op modulo
  `derived_at`. The user can always run this after a survey update without
  worrying about churn.
- **No commit.** The user reviews via `git diff` and runs `/commit`.
