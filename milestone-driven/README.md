# Milestone-Driven Workflow

A phased cycle for building software, from idea through implementation to closeout.

| Phase | Command | What it does | Produces |
|-------|---------|-------------|----------|
| 0 | `/project-inception` | Socratic dialogue to discover project vision and goals | `README.md` |
| 1 | `/strategic-planning` | Sharpen ideas into well-defined, testable milestones | `roadmap/NNNN-slug.md` + `ROADMAP.md` index entry |
| 2 | `/milestone-breakdown` | Decompose a milestone into ordered, independently testable tasks | `PLAN.md` |
| 3 | `/task-implementation` | Implement one task using strict TDD (tests first, then code) | Passing code + tests |
| 3 | `/implementation-cycle` | Run task-implementation + commit in fresh subagents per task, then sync docs/examples to each commit | Passing code + commits + doc commits |
| 4 | `/milestone-closing` | Verify success criteria, document results, reset for next cycle | Updated `roadmap/NNNN-slug.md` + `ROADMAP.md` index |
| - | `/commit` | Craft a conventional commit from staged/unstaged changes | Git commit |

**Typical flow:** `inception` (once) → `planning` → `breakdown` → `implementation` (repeat per task) → `closing` → back to `planning`.

## Roadmap file layout

`ROADMAP.md` is a lightweight **index** — one line per milestone — kept lean so it stays
cheap to load:

```
NNNN-slug.md — [status] one-line summary of what the milestone achieves
```

The full content of each milestone (value/impact, outcome, success criteria, notes, and
closing notes) lives in its own file under `roadmap/NNNN-slug.md`. Later phases scan the
index to find the next open milestone and open only the specific file they need, so a
growing roadmap no longer bloats the working context.

## Migrating an existing project

Projects created before the index split keep all milestone content inline in a monolithic
`ROADMAP.md`. To migrate to the new index + `roadmap/` layout, paste this prompt into a
Claude Code session opened in the target project:

```
Migrate this project's ROADMAP.md from the old monolithic format to the new index + per-file format.

Old: ROADMAP.md contains full milestone blocks (## Milestone: … with Status, Value/Impact, Outcome, Success Criteria, Notes, and any Closing Notes).

New:
- Create a roadmap/ directory.
- For each milestone, in order, create roadmap/NNNN-slug.md (zero-padded 4-digit sequential number starting at 0001; short kebab-case slug from the title). Move the milestone's entire block into it verbatim, changing the heading from "## Milestone: <title>" to "# Milestone: <title>". Preserve Status, all checkbox states, and any closing notes exactly.
- Replace ROADMAP.md with an index: keep the top header/comment explaining the format, then one line per milestone:
      NNNN-slug.md — [status] <one-line summary>
  Status matches the file's **Status:** field; summary is a condensed Value/Impact.
- Preserve original ordering. Don't drop, reword, or renumber any milestone content beyond the heading level and the moves above.

After writing, show me a diff summary and the new ROADMAP.md so I can review before committing.
```

If `PLAN.md` currently points at an in-progress milestone, update its `> Milestone:` line
to name the new `roadmap/NNNN-slug.md` file after migrating.
