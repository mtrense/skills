---
name: author-ingest
description: Ingest repo-local source material into un-id'd reference/ files plus grounding metadata, without touching the web. Handles both the `research` kind (a citable KB shaped as markdown + references.yaml + CONFIDENCE markers, e.g. from the deep-research workflow) and the `document` kind (any plain repo file — md/html/txt/yaml/csv/json). Distils the material's *facts and insights* (never its structure or verbatim prose) into reference/, tagging each with a resolvable grounding ref. Trigger when the user says "ingest", "bring in this source/material/corpus", "turn these docs into reference material", or "/author-ingest". Spawns material-extractor.
---

# author-ingest — source material → reference/ + grounding

You turn repo-local source material into the **author-only `reference/` layer** the drafting
skills draw on, and record where each fact came from as a **grounding ref**. This is the base
layer of the research→bulk pipeline (AUTHORING_SKILLS.md §5.A).

## Scope — read repo-local material, never the web
`author-ingest` **reads files already in the repo and never fetches from the web.** Any web work
happened upstream, when the material was produced (e.g. by the `deep-research` skill). If the user
wants a *fresh* online article folded in, that is the **graft** on-ramp (`author-graft`), not this.

## Two kinds, one path — detect the metadata
1. **Spawn `material-extractor`** on the input files. It classifies the corpus and returns atomic
   knowledge units with candidate prerequisites, why-it-matters hooks, source line refs, and a
   proposed `grounding_ref` + `confidence` per unit.
2. Set `grounding.source` from what it found:
   - **research kind** — the material carries `references.yaml` + `<!-- CONFIDENCE: … -->` markers
     and heading anchors. Lift citations and confidence forward verbatim; refs are
     `research:<path>#<heading-anchor>`. This is the honest, high-credibility base layer.
   - **document kind** — plain files with no citation metadata. Refs are
     `doc:<path>@sha256:<hex>`; assert an honest `confidence` (`medium`/`low` is legitimate — not
     every internal fact has a citable source, and the contract records *that* rather than faking one).

## What to write
- Land distilled **facts and insights** as markdown under `reference/` (author-only — **no `id`**,
  so the CLI excludes it from the snapshot). Change register from source prose to DAG-ready,
  chunked, note-form material. **Never copy source prose verbatim.**
- Preserve heading structure so `research:<path>#<anchor>` refs resolve — the CLI existence-checks
  the anchor against a real heading (TRACK_STRUCTURE.md §5.6). For `document`-kind files kept for
  `doc:@sha256` refs, leave the original file byte-for-byte (the hash must match).
- Do **not** draft learner-facing nodes here, do **not** build the DAG, do **not** mint ids. Output
  is reference material + a manifest of units and their grounding refs for `author-structure`.
- Record an **ingest-state manifest** at `reference/.ingest-state.yaml` so the delta-aware
  `author-ingest-update` can later tell what changed: `source_root` (where the ingested source
  lives), `grounding_kind`, `ingested_through` (`git rev-parse HEAD` — the source commit this ingest
  reflects, or `(no git)`), `ingested_at`, and a `provenance` list mapping each upstream source file
  → its distilled `reference/` file → the grounding refs it produced. Skip only if the repo has no
  git.

## Grounding refs you emit (must later validate — §5.6)
| kind | grammar | CLI check downstream |
|---|---|---|
| research | `research:<path>#<heading-anchor>` | file + heading exist |
| document | `doc:<path>@sha256:<hex>` | file exists **and** bytes hash to `<hex>` (CLI computes hash — you leave a placeholder) |

You do **not** compute hashes. Emit `doc:<path>@sha256:<PLACEHOLDER>`; the node's real hash is
filled when the referenced file is stable, and `author-selfcheck` catches any mismatch.

## Hand-off
Produce: (1) `reference/` files, (2) a units manifest `{claim, why_it_matters, candidate_prereqs,
grounding_ref, confidence}`, (3) `reference/.ingest-state.yaml` (above). Point the user at
`author-structure` next. When the source material later changes, `/author-ingest-update` refreshes
`reference/` incrementally from a commit range rather than re-running this from scratch. Do not
commit or push.
