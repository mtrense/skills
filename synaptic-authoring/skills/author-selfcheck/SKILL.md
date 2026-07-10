---
name: author-selfcheck
description: The mandatory hand-off gate for Synaptic content. Runs `synaptic validate --json` over the track directory, summarizes the findings, and blocks hand-off on any integrity violation. Trigger before proposing any content diff to a human, after any author-* drafting/structuring/changelog skill lands files, or when the user says "check", "validate", "self-check", "is this valid", "ready to push", or "/author-selfcheck". Reports which pieces fail and why, in the CLI's own terms, and refuses to present an integrity-breaking snapshot.
---

# author-selfcheck — the standing integrity gate

You verify that a working tree of proposed content is snapshot-valid **before** any human sees a
diff. You defer every integrity judgment to the deterministic CLI — you never adjudicate validity
yourself, never mint ids, never hash, never assign editions (AUTHORING_SKILLS.md §4, guardrail #1).

## Procedure

1. **Locate the track.** Find the directory containing `track.toml` (ask if ambiguous).
2. **Run the gate:**
   ```bash
   synaptic validate <track-dir> --json
   ```
   The output is a stable `{ "ok": bool, "findings": [ {kind, file, id, slug, cycle, message} ] }`
   shape. Parse it — do not eyeball the human report for pass/fail.
3. **Report.**
   - If `ok: true` — state it plainly: "Validation passed — N nodes / M questions, no violations."
     Then hand off (the human commits + pushes; you never push or commit on your own authority).
   - If `ok: false` — **block hand-off.** List each finding grouped by `kind`, name the offending
     `file`/`id`/`slug`, and give a one-line fix per finding. Do not describe the tree as ready.
4. **Route fixes.** Map common findings to the skill that fixes them, but do not silently fix
   structural/pedagogical issues yourself:
   - `invalid-grounding-ref` / missing grounding → the node still has a scaffold `TODO:` ref or a
     stale path; route to `author-snippet` / `author-ingest` to supply a resolvable ref.
   - unresolved `glossary#`/`cheatsheet#` slug or dangling `assets:` path → `author-adjacent` /
     `author-visual` (or fix the reference).
   - cycle in prerequisites → `author-structure` (the DAG must stay acyclic).
   - active reference to a retired id → `author-restructure`.
   - changelog-vs-hash (bytes changed with no new changelog entry) → `author-changelog`.

## What this gate does NOT cover yet

`synaptic diff`/`visualize` are **not implemented** in the current binary — so this skill cannot
yet show "which editions advance / whose `significant_edition` moves / who goes stale." That
staleness-impact summary is deferred until `diff` ships; for now report *validity* only and say so.
Do not invent a diff by hand.

## Hard rules
- Never present or approve an integrity-breaking snapshot.
- Never `push` or `git commit` — hand a clean, validated tree to the human and stop.
- Report the CLI's findings faithfully; if validation fails, say so with the messages.
