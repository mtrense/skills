# Synaptic Authoring Workflow

Skills and subagents for authoring content for **Synaptic**, an interactive online learning
platform. A Synaptic *track* is a git directory of content files that the deterministic
`synaptic` CLI validates and snapshots. This workflow drafts that content against the CLI's
file contract — it never adjudicates validity, mints ids, or hashes anything itself; every
integrity judgment is deferred to `synaptic validate`.

## The contract these skills serve

Synaptic recognises five content kinds authored as files in a track directory:

- **Knowledge snippet** / **Exercise** — DAG nodes with a lifecycle and a `significance`-carrying changelog.
- **Question** — multiple-choice assessment referencing a tight list of nodes it tests; assessment is *feedback, never a gate*.
- **Glossary term** / **Cheatsheet element** — slug-addressed, reference-driven (never text-matched), disclosed-then-persistent.

Two invariants run through every skill:

- **The prerequisite DAG** (acyclic, AND-semantics, single-track) is the product's core differentiator. Ids are minted only by `synaptic scaffold`; skills propose structure and the human approves before scaffolding.
- **Grounding** — every node carries a `grounding` block recording where its substance came from (`research` / `document` / `expert`), with resolvable refs the CLI checks. Credibility is a property of every node, independent of source kind.

## Skills

| Command | What it does | Spawns |
|---------|-------------|--------|
| `/author-ingest` | Distil repo-local source material (research KB or plain docs — never the web) into un-`id`'d `reference/` files tagged with grounding refs; record `reference/.ingest-state.yaml` (source root, watermark SHA, provenance) for later updates | `material-extractor` |
| `/author-ingest-update` | Delta-aware re-ingest from a git commit range: re-extract only changed source, reconcile against `reference/` by grounding ref, and report which track nodes went STALE/BROKEN so they can be re-drafted | `material-extractor`, `grounding-tracer` |
| `/author-structure` | Propose the track DAG (nodes, prerequisite edges, priority) from `reference/` + a track goal, then mint node ids via `synaptic scaffold` | `concept-mapper` |
| `/author-snippet` | Draft the learner-facing body of a scaffolded node from `reference/` — playful low-stakes voice, always *why it matters* / *what it unlocks*, each claim grounded | — |
| `/author-questions` | Draft multiple-choice questions with tight reference lists honoring "assessment is feedback, never a gate", then mint question ids and write files | `question-smith` |
| `/author-gap-scan` | Audit an existing or proposed DAG for foundational gaps — concepts referenced but never taught, orphan roots, prerequisite leaps, redundant nodes | `concept-mapper`, `coverage-auditor` |
| `/author-selfcheck` | The standing hand-off gate: run `synaptic validate --json`, summarise findings, and refuse to present an integrity-breaking snapshot | — |

**Typical flow:** `ingest` → `structure` → `snippet` (per node) → `questions` (per node) → `gap-scan` → `selfcheck` before hand-off.

**Update loop:** when the ingested source moves on, `ingest-update <range>` refreshes `reference/` and hands you a worklist of STALE/BROKEN nodes → re-run `snippet`/`questions` on those → `selfcheck`.

## Subagents

All read-only proposal workers (`tools: Read, Glob, Grep`); they return structured reports and
write no files — the orchestrating skill does the scaffolding and writing.

- `material-extractor` — pulls atomic knowledge units from `reference/` files, tags each with candidate prerequisites, a "why it matters" hook, and a source line, and reports which grounding kind applies (research vs document). For `/author-ingest` and `/author-ingest-update` (which runs it over only the source files a commit range changed).
- `concept-mapper` — turns knowledge units into a proposed prerequisite DAG with a one-line rationale per edge and an explicit acyclicity self-check. For `/author-structure` and `/author-gap-scan`.
- `question-smith` — drafts multiple-choice questions with per-distractor rationale and flags any question whose reference list is too broad. For `/author-questions`.
- `coverage-auditor` — audits a DAG for foundational gaps keyed to node ids. For `/author-gap-scan`.
- `grounding-tracer` — downstream-impact scout: given the grounding refs a source update changed (tagged changed / anchor-moved / removed) and the track root, scans the id'd node files and returns a STALE/BROKEN re-draft worklist plus each affected node's dependents. Keeps the track-wide grep sweep out of the orchestrator. For `/author-ingest-update`.

See the design proposal `AUTHORING_SKILLS.md` in the Synaptic project for the full contract
these skills target (`grounding` grammar, changelog rules, the research→bulk pipeline).
