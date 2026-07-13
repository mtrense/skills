---
name: author-ingest
description: Ingest repo-local source material into un-id'd reference/ files plus grounding metadata, without touching the web. Handles both the `research` kind (a citable KB shaped as markdown + references.yaml + CONFIDENCE markers, e.g. from the deep-research workflow) and the `document` kind (any plain repo file — md/html/txt/yaml/csv/json). Distils the material's *facts and insights* (never its structure or verbatim prose) into reference/, tagging each with a resolvable grounding ref. Trigger when the user says "ingest", "bring in this source/material/corpus", "turn these docs into reference material", or "/author-ingest". Spawns material-extractor.
---

# author-ingest — source material → reference/ + grounding

You turn repo-local source material into the **author-only `reference/` layer** the drafting
skills draw on, and record where each fact came from as a **grounding ref**. This is the base
layer of the research→bulk pipeline (AUTHORING_SKILLS.md §5.A).

## Keep your own context lean — you never read the source yourself
The source corpus is read **once**, inside `material-extractor`, and stays in *its* context. It
returns both the units manifest **and** the write-ready `reference/` file bodies. You write those
bodies verbatim; you do **not** open the source files in your own context to "check" or "enrich"
them — that re-read is exactly what makes this skill blow past its token budget. If a returned body
looks wrong, send the extractor back with a correction, don't pull the source in yourself. Your
context holds only the manifest, the file bodies as you write them, and the ingest-state manifest.

## Scope — read repo-local material, never the web
`author-ingest` **reads files already in the repo and never fetches from the web.** Any web work
happened upstream, when the material was produced (e.g. by the `deep-research` skill). If the user
wants a *fresh* online article folded in, that is the **graft** on-ramp (`author-graft`), not this.

## Two kinds, one path — detect the metadata
1. **Spawn `material-extractor`** on the source root (**pass the track goal** if you have one — it
   lets the extractor scope the ingest). It reads the KB's `INDEX.md` first to triage against the
   goal and reads full chapter bodies **only for the chapters in scope** — it never slurps the whole
   tree. It classifies the corpus and returns, per file, the **write-ready `reference/` body** plus a
   lightweight units index (candidate prerequisites, why-it-matters hooks, source line refs,
   `grounding_ref` + `confidence` per unit) and a `provenance` block for the ingest-state manifest.
   - **Small / goal-scoped corpus** — one `material-extractor` call. Its cross-file dedup and
     `candidate_prerequisites` linking are strongest when it sees everything in scope at once.
   - **Large corpus (many in-scope chapters / subtrees)** — **fan out in parallel**: split the
     in-scope tree (use the index to pick natural boundaries) into per-file or per-directory batches
     and issue one `Agent` call per batch **in a single message**.
     Each returns its own bodies + units index; **write each batch's `reference_files` as they come
     back** (don't hold them all), then **merge only the lightweight units index in this session** —
     concatenate the unit lists, dedup units that restate the same claim, and reconcile
     `candidate_prerequisites` across batches (a prereq named in one batch may be defined in
     another). Only the compact index is merged here, never the full bodies, so the merge stays
     cheap. Prefer directory-aligned batches so a batch's `candidate_prerequisites` mostly resolve
     within it.
   If the extractor reports chapters it **skipped as out-of-goal-scope** (in its `notes`), surface
   that list to the user before writing — a one-line "ingested X chapters, skipped these N as
   out-of-scope: …" — so they can pull any back in. Don't silently drop KB regions.
2. Set `grounding.source` from what it found (whether one call or a merged fan-out):
   - **research kind** — the material carries `references.yaml` + `<!-- CONFIDENCE: … -->` markers
     and heading anchors. Lift citations and confidence forward verbatim; refs are
     `research:<path>#<heading-anchor>`. This is the honest, high-credibility base layer.
   - **document kind** — plain files with no citation metadata. Refs are
     `doc:<path>@sha256:<hex>`; assert an honest `confidence` (`medium`/`low` is legitimate — not
     every internal fact has a citable source, and the contract records *that* rather than faking one).

## What to write
- **Write each `reference_files` body the extractor returned, verbatim**, to its `path` (author-only
  — **no `id`**, so the CLI excludes it from the snapshot). The distillation, register change, and
  heading structure are already done inside the extractor; your job is to land them, not redo them.
  Do not re-open the source to "improve" a body — see the lean-context rule above.
- Heading structure in those bodies already matches the anchors, so `research:<path>#<anchor>` refs
  resolve — the CLI existence-checks the anchor against a real heading (TRACK_STRUCTURE.md §5.6). For
  a `verbatim_keep` entry (a `document`-kind file kept for `doc:@sha256` refs), leave the original
  file byte-for-byte (the hash must match) — write nothing.
- Do **not** draft learner-facing nodes here, do **not** build the DAG, do **not** mint ids. Output
  is reference material + a manifest of units and their grounding refs for `author-structure`.
- Record an **ingest-state manifest** at `reference/.ingest-state.yaml` so the delta-aware
  `author-ingest-update` can later tell what changed: `source_root` (where the ingested source
  lives), `grounding_kind`, `ingested_through` (`git rev-parse HEAD` — the source commit this ingest
  reflects, or `(no git)`), `ingested_at`, and a `provenance` list mapping each upstream source file
  → its distilled `reference/` file → the grounding refs it produced. **Assemble `provenance` from
  the `provenance` blocks the extractor returned** (concatenated across batches), not by re-reading
  source. Skip only if the repo has no git.

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
