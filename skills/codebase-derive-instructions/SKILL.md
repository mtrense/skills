---
name: codebase-derive-instructions
description: >
  Read the assembled codebase survey (CODEBASE.md files, docs/codebase/*.md,
  assessment findings) and produce a lean, source-anchored CLAUDE.md at the
  repo root plus one per module. Lifts kind:rule findings only; observations
  stay in assessment.md. Verifies length budgets, import resolution, and rule
  duplication before writing. If AGENTS.md exists at the repo root, derive
  into AGENTS.md instead and write a thin CLAUDE.md that imports it.
disable-model-invocation: true
argument-hint: "(no arguments)"
model: opus
allowed-tools: Read, Write, Glob, Grep, Edit, Bash(git rev-parse:*), Bash(wc:*), Bash(ls:*)
---

# Codebase Derive Instructions

You read a completed codebase survey and produce `CLAUDE.md` at the repo root
plus one `<module>/CLAUDE.md` per module. Both are lean, source-anchored, and
structured so a frontier model loads them at conversation start without
exhausting its instruction budget.

The skill is consumer of survey output, not a producer of new findings. If
something looks wrong in the survey, surface it and stop — go fix the survey
upstream rather than papering over it here.

## Prerequisites

1. Top-level `CODEBASE.md` exists.
2. Per-module `<path>/CODEBASE.md` files exist (or the project is a confirmed
   single-module repo).
3. `docs/codebase/assessment.md` exists with findings tagged `kind: rule` or
   `kind: observation`. If absent, ask the user whether to proceed without
   assessment-driven boundaries (the resulting CLAUDE.md will be thinner but
   still useful) or run `/codebase-architecture-assessment` first.

## Phase Workflow

### Step 1: Detect the AGENTS.md interop case

Check whether `AGENTS.md` exists at the repo root. There are two cases:

- **AGENTS.md absent** (default): derive into `CLAUDE.md` at repo root.
- **AGENTS.md present**: derive into `AGENTS.md` instead. Write a thin
  `CLAUDE.md` at the repo root containing only:

  ```markdown
  ---
  derived_from_survey_sha: <SHA>
  derived_at: <YYYY-MM-DD>
  derive_schema: 1
  ---

  @AGENTS.md

  ## Claude Code

  <Claude-specific addenda only — e.g., references to specific skills like
  /commit or /implementation-cycle. Empty if no Claude-specifics apply.>
  ```

  Per-module derivation still goes into `<module>/CLAUDE.md`.

The rest of this document refers to "the root file" — substitute `AGENTS.md`
when in the interop case.

### Step 2: Read the survey

Load:

- Top-level `CODEBASE.md`.
- Every `<module>/CODEBASE.md` referenced in the module map.
- `docs/codebase/assessment.md`.
- `docs/codebase/architecture.md`, `docs/codebase/tech-stack.md`,
  `docs/codebase/operations.md` (mostly for `@imports`, not for content
  duplication).
- The README at the repo root (used only for project-identity import).

Capture each source's `surveyed_sha` from its front-matter — you'll record
the latest one as `derived_from_survey_sha` so future updates can detect
drift.

### Step 3: Plan the root file

The root file is loaded into every Claude Code session. Budget: ≤ 200 lines
in the file body (excluding front-matter and trailing newline), keeping the
total expanded launch context (root file + everything its `@imports` pull
in) comfortably under ~10 KB.

Use this fixed section order. Omit a section entirely if it has no content —
do not write empty headers.

1. **Project identity** — 1–2 lines plus `@README.md` and `@CODEBASE.md`.
   Single sentence saying what this is. Example:

   ```markdown
   # <Project Name>

   <One-line: kind of thing it is, primary language, primary value.>

   @README.md
   @CODEBASE.md
   ```

2. **Build & test commands** — Verbatim. Each line ends with an HTML comment
   pointing to its source. Pull from manifest scripts (`package.json scripts`,
   `Cargo.toml [aliases]`, `Makefile` targets, `pyproject.toml [tool.poetry.scripts]`).

   ```markdown
   ## Build & Test

   - `pnpm install` — install dependencies <!-- from: package.json, surveyed_sha=abc123 -->
   - `pnpm build` — full build <!-- from: package.json scripts.build, surveyed_sha=abc123 -->
   - `pnpm test` — run all tests <!-- from: package.json scripts.test, surveyed_sha=abc123 -->
   - `pnpm lint` — lint <!-- from: package.json scripts.lint, surveyed_sha=abc123 -->
   ```

3. **Where things live** — One line per module, plus a pointer to
   `@CODEBASE.md` for detail. Do **not** duplicate the module map — name
   each module in one phrase.

   ```markdown
   ## Where Things Live

   - `packages/api` — HTTP gateway (Express, port 8080)
   - `packages/core` — domain logic (pure TS)
   - `packages/db` — persistence (Prisma + Postgres)

   See `@CODEBASE.md` for the full module map.
   ```

4. **Boundaries** — Three subsections from `kind: rule` findings only.
   Skip findings tagged `kind: observation` — they stay in assessment.md.
   Phrase each rule as imperative.

   ```markdown
   ## Boundaries

   ### Always
   - <imperative rule> <!-- from: docs/codebase/assessment.md F-003, surveyed_sha=abc123 -->
   - ...

   ### Ask first
   - <rule that gates an action on user confirmation> <!-- from: ... -->

   ### Never
   - <prohibitive rule> <!-- from: ... -->
   ```

5. **Git workflow** — Only if non-default. If the project uses standard
   PR-based workflow, omit this section. Include only when the assessment
   surfaced a workflow rule (e.g., "all commits go through `/commit`",
   "merges to main require `make verify`").

6. **Pointers** — On-demand reads.

   ```markdown
   ## See Also

   - `@docs/codebase/architecture.md` — system design
   - `@docs/codebase/tech-stack.md` — stack rationale
   - `@docs/codebase/operations.md` — CI/CD, deploys, observability
   - `@docs/codebase/assessment.md` — full assessment (incl. observations)
   ```

### Step 4: Plan per-module files

Each module gets `<module>/CLAUDE.md`, loaded lazily by Claude Code when it
reads files in that subtree. Budget: ≤ 80 lines.

Section order:

1. **Local commands** — only if the module has commands beyond the root set
   (e.g., a per-module test command, a generator). Skip otherwise.
2. **Boundaries** — pulled verbatim from this module's `Architectural
   Deviations` section in `<module>/CODEBASE.md`. Add the source-anchor
   comment.
3. **Pointer to `@<module>/CODEBASE.md`**.

Example (a thin module CLAUDE.md is good):

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

@packages/api/CODEBASE.md
```

If a module has no findings beyond what the root file already covers, write
a minimal stub:

```markdown
---
derived_from_survey_sha: <SHA>
derived_at: <YYYY-MM-DD>
derive_schema: 1
---

# packages/<name>

@packages/<name>/CODEBASE.md
```

A near-empty module CLAUDE.md is fine — it still gets the `@import` of the
module survey when the user works in that subtree.

### Step 5: Apply content discipline

Use this table when deciding what to derive. When in doubt, leave it out —
the survey is the source of truth, not the derived file.

| Survey input | Derived? | Notes |
|---|---|---|
| Build/test commands (from manifests, CI) | Yes, verbatim | Highest signal |
| Project map / module boundaries | Pointer only | Don't duplicate `CODEBASE.md` |
| Tech-stack rationale | No | Lives in `docs/codebase/tech-stack.md` |
| Architectural Deviations (per-module) | Yes, as module Boundaries | Exactly the gotchas CLAUDE.md exists for |
| Assessment findings | Only `kind: rule` | `kind: observation` stays in assessment.md |
| Open Questions | No | Not yet decided → not a rule |
| Code style | No | Linter's job; reference the linter config instead |
| API surface | No | Discoverable on demand |
| Operations / secrets | Only the "always do X before commit" subset | Rest stays in `docs/codebase/operations.md` |

### Step 6: Verify before writing

Run these checks. Surface failures to the user; do not auto-fix silently.

1. **All `@imports` resolve.** For every `@<path>` in the planned root file
   and module files, confirm `<path>` exists. Fail loudly on broken imports.

2. **Length budgets.**
   - Root file: count body lines (excluding YAML front-matter). If > 200,
     report and ask the user how to shed material before writing.
   - Per-module file: > 80 lines → same response.
   - Total launch context: estimate by reading the root file and following
     `@imports` one level deep, summing bytes. If > ~10 KB, warn.

3. **Rule duplication.** For each derived rule, similarity-check against
   the corresponding `CODEBASE.md` body. If a derived rule is a near-verbatim
   copy of body content already in `CODEBASE.md`, that's redundant — the
   `@CODEBASE.md` import already pulls it in. Surface as a warning so the
   user can decide whether to keep it for emphasis or drop it.

4. **Code-style heuristic scan.** Search the planned content for indicators
   that suggest a code-style rule snuck in: substrings like `tabs`, `spaces`,
   `indent`, `camelCase`, `snake_case`, `naming convention`, `PascalCase`,
   `2-space`, `4-space`. Flag every hit for human review — these usually
   shouldn't be in CLAUDE.md (the linter handles them).

5. **Rule count ceiling.** Total derived rules across root + all module
   files. If > 100, warn that adherence drops past frontier-model
   thresholds. > 150 is a hard halt — ask the user to triage before writing.

6. **Source-anchor coverage.** Every derived rule must carry a block-level
   HTML comment naming its source and `surveyed_sha`. Halt on any rule
   without one.

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

In the AGENTS.md interop case, write `AGENTS.md` and a thin `CLAUDE.md` per
Step 1.

### Step 8: Hand off

Report:

- Files written (path + line count).
- Files left unchanged (same body modulo `derived_at`).
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

- **Lift, don't author.** Every line in the derived files traces back to a
  specific `CODEBASE.md` or assessment finding via the source-anchor comment.
  If you cannot anchor it, do not write it.
- **Rules ≠ observations.** Only `kind: rule` lifts. The cost of a noisy
  CLAUDE.md is paid on every conversation; the cost of a too-thin CLAUDE.md
  is one occasional question.
- **Pointer over duplication.** When `CODEBASE.md` has it, link via `@import`
  rather than copy. The rendered context is the same; the diff cost when the
  source changes is much lower.
- **Verify before write.** A length blow-out, a broken `@import`, or a
  code-style rule slipping through is much harder to clean up after the
  fact than to catch at the gate.
- **Idempotent.** Re-running on unchanged sources is a no-op modulo
  `derived_at`. The user can always run this after a survey update without
  worrying about churn.
- **No commit.** The user reviews via `git diff` and runs `/commit`.
