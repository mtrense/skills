---
name: author-snippet
description: Draft the learner-facing body of a scaffolded knowledge node (or exercise) from reference/ material — playful low-stakes voice, always stating *why it matters* and *what it unlocks*, with each claim grounded in a resolvable grounding ref. Fills the scaffold's TODO title/grounding/body, and proposes the glossary/cheatsheet slug links the prose needs. Trigger after author-structure has scaffolded nodes, or when the user says "draft this node/snippet", "write the body", "flesh out <node>", or "/author-snippet". Scaffolds glossary/cheatsheet slugs as needed; never mints node ids or edits the changelog rules.
---

# author-snippet — draft a node body

You write the **learner-facing prose** for a single scaffolded node, replacing its `TODO`
placeholders (title, grounding ref, body) with real, grounded, motivating content. The node's
`id` already exists (minted by `author-structure` via `cli scaffold`) — you never touch it.

## The voice and the credo (README.md, AUTHORING_SKILLS.md §3)
- **Playful, low-stakes tone** ("Challenge me!") — but *only* in learner-facing body prose, never
  in frontmatter or comments.
- **Every node states *why it matters* and *what it unlocks*.** This is mandatory, not optional
  garnish — motivation comes from seeing the point.
- **Active application beats passive reading.** Prefer "here's how you'd use it" framing; if the
  node is `kind: exercise`, write a task that applies the idea (never one that gates or ranks).
- **Ground every substantive claim.** Each claim should trace to the `reference/` material the
  node was seeded from.

## Filling the frontmatter
- `title` — replace the `TODO:` with a real learner-facing title.
- `grounding` — replace the scaffold's placeholder `TODO: research:...` ref (which **fails
  validation on purpose**) with the real resolvable ref(s) from the units manifest:
  - `research:<path>#<heading-anchor>` (file + heading must exist under `reference/`),
  - `doc:<path>@sha256:<hex>` (leave `<hex>` for the CLI/human to fill from the stable file; do
    **not** hash yourself),
  - set `source` to the primary kind and an honest `confidence` (low/medium is legitimate).
  `refs` must be non-empty or validation fails. A node may layer several refs.
- Leave `changelog` as the scaffold's initial `major` entry for a brand-new node; subsequent
  edits go through `author-changelog`, not here.

## Supplementary references (glossary / cheatsheet)
When the prose needs a defined term or a quick-reference element:
- Reference it **explicitly by slug**, never by text-matching: add the slug to the node's
  `glossary:`/`cheatsheet:` frontmatter list **and** write the inline link
  `[surface phrasing](glossary#slug)` / `[…](cheatsheet#slug)`. Different phrasings are just
  different link texts pointing at the same slug — no alias list needed.
- If the slug doesn't exist yet, scaffold it (then its body is a separate drafting job — this is
  the `author-adjacent` job; for now scaffold and leave a `TODO` body, or hand off):
  ```bash
  synaptic scaffold glossary  <track-dir> <slug>
  synaptic scaffold cheatsheet <track-dir> <slug>
  ```
- Every referenced slug must resolve or `synaptic validate` fails (both directions checked).

## Assets
For a diagram, prefer a **mermaid** block inline (per house style). A binary asset is
reference-driven: drop the file on disk and reference it via `assets:` frontmatter or an inline
`![alt](path)` — its bytes fold into the node's hash; binaries carry no id/sidecar. (Rich visual
work is the `author-visual` job — hand off if it's more than a simple diagram.)

## Close the loop
After drafting, run `author-selfcheck` (or `synaptic validate --json`) on the track to confirm the
node now passes — grounding ref resolves, slugs resolve, no `TODO` left. Fix and re-check until
clean. Hand a validated tree to the human; never push or commit.
