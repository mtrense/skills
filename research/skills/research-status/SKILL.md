---
name: research-status
description: "Report the derived status of every chapter in a research project — computed live from frontmatter and the RESEARCH/CONFIDENCE/AUDIT directives on disk, not from a stored enum. Use when the user asks for research status/progress, what's left, or which chapters are stub/inquiry/draft/audited/done. Arguments: optional path or status filter."
model: sonnet
allowed-tools: Read, Bash(bash */skills/research-status/research-status.sh *)
argument-hint: "[path-prefix] [--status stub|inquiry|draft|audited|done]"
---

# Research Status

Report the true, derived status of each chapter in a research project. Status is
**not** stored anywhere — it is computed on the fly from the signals that live on
disk (frontmatter `audit:` field, and the `<!-- RESEARCH: -->`, `<!-- CONFIDENCE: -->`,
`<!-- AUDIT: -->` directives, plus `references.yaml` verification flags). This skill
is the human-facing front end to the shared `research-status.sh` helper that every
other research skill also consults instead of reading a status enum from `INDEX.md`.

## How it works

The helper lives next to this skill at `<skills-root>/research-status/research-status.sh`,
where `<skills-root>` is the `.claude/skills/` directory this skill is installed in
(`~/.claude/skills` for a global install, `<project>/.claude/skills` for a project
install). Run it against the project's `research/` directory.

Parse `$ARGUMENTS`:
- A bare token that looks like a path (contains `/` or ends in `.md`, or names a
  top-level topic) → pass as `--path <token>` to scope to one chapter or subtree.
- `--status <s>` → pass through to filter to one derived status.
- Nothing → report the whole project.

Run the helper (adjust `<skills-root>` to the real install path):

```
bash <skills-root>/research-status/research-status.sh research [--path P] [--status S]
```

If the project's research directory is not the default `research`, pass its path as
the first positional argument instead.

## Output

Present the helper's output verbatim in a fenced block, then add a one-paragraph
reading of it: how many chapters sit at each status and what the nearest actionable
work is (e.g. "3 chapters are `inquiry` — run `/research-investigation` or
`/research-investigation-cycle` next; 1 `audited` chapter has an open major AUDIT —
`/research-refine` it").

Each chapter line reads:

```
<status>  <rel_path>  research=N conf=lo/me audit=mi/ma lenses=D/4 gfx=y|n refs=V/T [warn=...]
```

- **research** — open RESEARCH directives (inquiry work still pending).
- **conf** — open CONFIDENCE markers, `low`/`medium` (verification pending in audit).
- **audit** — open AUDIT directives, `minor`/`major` (refine work pending).
- **lenses** — core audit lenses recorded (of consistency, coverage, quality,
  coherence); all four are required to reach `audited`. `gfx` flags the supplementary
  graphics lens.
- **refs** — verified / total references; a chapter cannot reach `done` while any
  reference is unverified.
- **warn** — appears only when signals contradict (e.g. an audit lens was recorded
  while RESEARCH directives are still open); surface these to the user as anomalies.

The status map: `stub` (no outline yet) → `inquiry` (outline placed, not investigated)
→ `draft` (investigated, not fully audited) → `audited` (all four lenses run, open
findings remain) → `done` (nothing open). `missing` means a chapter is listed in
`INDEX.md` but absent on disk; the footer also lists `untracked` chapters (on disk,
absent from `INDEX.md`).

## Rules

- Read-only. This skill never edits any file, and never writes a status anywhere —
  status is always derived, never stored.
- Do not commit.
