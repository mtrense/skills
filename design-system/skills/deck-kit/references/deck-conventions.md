# Deck Conventions

The canonical contract for the design-system's presentation layer. The deterministic half is enforced by `deck-check.sh` (in `skills/deck-build/`); the rest by the orchestrating skills and the `slide-smith` worker. These conventions extend, and never override, the component conventions in `skills/design-audit/references/conventions.md` — token discipline, logical direction classes, and semantic markup carry over verbatim.

## Two layers

**The deck kit** lives inside the design system and is regenerated when themes change. **Decks** are content, live outside `design-system/`, and reference the kit — they drift *with* the design system, never pin it.

```
design-system/
  deck-kit/
    DECKKIT.md                   # master spec + machine-readable ## Masters list (/deck-kit)
    <theme>-<light|dark>/
      deck.css                   # the bridge: imports the theme's index.css, maps --r-* onto --ds-*
    sample/
      <theme>-<light|dark>.html  # kitchen-sink sample deck: every master once, marker-delimited
    .fragments/<master>/<theme-dir>.html   # build intermediates — smiths write, deck-assemble.sh consumes

<anywhere>/presentations/<deck-slug>/     # location is the consuming project's choice
  OUTLINE.md                     # the deck spec: frontmatter + ## Slides list + per-slide content notes
  index.html                     # the assembled reveal deck (deck-assemble.sh assemble)
  assets/                        # images, data files referenced by slides
  .fragments/<slug>.html         # build intermediates
```

## The stack

Decks are [reveal.js](https://revealjs.com) pages loading everything from CDNs, so they open from disk like the kitchen-sinks. Head/foot order is fixed (written only by `deck-assemble.sh`):

1. `reveal.js@5/dist/reveal.css` — structural CSS
2. `reveal.js@5/dist/theme/white.css` — the neutral base theme whose rules consume the `--r-*` vars
3. `@tailwindcss/browser@4` — the same Tailwind CDN the kitchen-sinks use
4. the theme's `deck.css` — **last**, so its `--r-*` overrides win
5. body: `<div class="reveal"><div class="slides">…blocks…</div></div>`, then `reveal.js` + `Reveal.initialize({ hash: true })`

No other JavaScript — reveal's runtime is the single sanctioned exception to the system's no-JS rule, and slide markup itself never carries scripts. Reveal-native staging (`class="fragment"`) and speaker notes (`<aside class="notes">`, never rendered on the slide) are allowed.

## The bridge (`deck.css`)

One file per theme×mode directory, mirroring the design system's theme dirs. It **never states a color** — it imports the theme's tokens and maps reveal's vars onto them:

```css
@import url("../../<theme-dir>/index.css");

:root {
  --r-background-color: var(--ds-color-bg);
  --r-main-color: var(--ds-color-on-bg);
  --r-heading-color: var(--ds-color-on-bg);
  --r-main-font: var(--ds-font-sans);
  --r-heading-font: var(--ds-font-display, var(--ds-font-sans));
  --r-code-font: var(--ds-font-mono, monospace);
  --r-link-color: var(--ds-color-primary);
  --r-link-color-hover: var(--ds-color-primary);
  --r-selection-background-color: var(--ds-color-primary);
  --r-selection-color: var(--ds-color-on-primary);
  --r-main-font-size: 38px;   /* deck-only decision: the projection type ramp */
  --r-block-margin: 20px;
}
```

The import also puts every `--ds-*` token in scope, so slide markup uses the same `bg-(--ds-color-surface)` Tailwind var shorthand as components. Deck-only decisions (type ramp, block margin, print rules) live here; everything colorful routes through `--ds-*` so a `/design-revise` token change propagates into every deck with zero regeneration.

**Contrast:** the upstream `design-check.sh` already proves every `on-<x>`/`<x>` pair. The bridge must not launder that away — `--r-main-color` and `--r-heading-color` sit on `--r-background-color`, so map them to the `on-*` partner of whatever backs the background (normally `on-bg`/`bg`). `deck-check.sh` resolves the var chain to hex and re-verifies: main/link ≥ 4.5, headings ≥ 3.0 (large text).

## Grammars

**`DECKKIT.md`** opens with `## Masters` listing every master as `` - `slug` — one-liner ``, in sample-deck order — the same line grammar as the component catalog, machine-read by `deck-assemble.sh` and `deck-check.sh`. Each master then gets its own `## <Name>` section: anatomy (the one shared DOM), content slots (what a deck fills in), theme-variance notes, and a content budget (see below).

**`OUTLINE.md`** is the deck spec — markup never leads it. YAML frontmatter: `title`, `theme` (a theme-dir name, e.g. `aurora-dark` — a deck targets exactly ONE theme×mode; the sibling mode is a different build), `ds` (relative path from the deck dir to the design-system dir, default `../../design-system`), optional `lang`/`dir` (default `en`/`ltr` — an RTL deck sets `dir: rtl` and the logical classes do the rest). Then `## Slides`:

```markdown
## Slides
- `01-title` [title] — Opening: product name, speaker, date
- `02-agenda` [agenda] — The three acts
- `03-problem` [content] — Why current tooling fails
```

Grammar: `` - `NN-slug` [master] — one-liner ``, in presentation order — order in this list IS the slide order; reordering the list and re-assembling reorders the deck. Each slide then gets its own `## NN-slug` section holding the actual content: exact headline, body text/bullets, asset paths, data, and speaker notes. Slide content comes from here, never invented by the smith.

## Markers and blocks

Same contract as components, one pair per slide:

```html
<!-- master: quote -->
<section id="master-quote">…</section>
<!-- /master: quote -->        (sample decks)

<!-- slide: 03-problem -->
<section id="slide-03-problem">…</section>
<!-- /slide: 03-problem -->    (decks)
```

Each block is exactly one reveal `<section>` (nested vertical stacks are one block). The markers are the resumability and revision contract: worklists derive from them (`missing-masters` / `missing-slides`), and a revision replaces exactly one block. Fragments are the same block written by `slide-smith`; only `deck-assemble.sh` writes an assembled page. The `id` anchors make `#/master-quote`-style deep links work.

## Slide markup rules

- **One DOM per master, shared across themes** — the sample decks are the master's source of truth; a slide instantiates a master by taking its block's DOM for the deck's theme and replacing sample content with OUTLINE content, structure intact.
- **Tokens only, logical classes only** — exactly as in components: no literal Tailwind colors, no unmarked physical direction classes (`data-ds-physical` is the opt-out).
- **Headings ride the reveal ramp.** No `text-*` size classes on `h1`–`h3` — sizes come from the `--r-*` type ramp so the whole deck rescales from one place. Non-heading display text (a stat callout) may size via classes.
- **The content budget is binding.** Each master's spec states its budget (e.g. content: ≤ 5 bullets × ≤ 12 words, or ≤ 8 body lines). Overflow never shrinks type to fit — content that busts the budget goes back to OUTLINE.md as a split into two slides. `deck-critic` flags anything that renders outside the slide frame or reads as a wall.
- **Realistic content, never lorem** — sample decks show plausible content; real decks show OUTLINE content verbatim.
- **Speaker notes** carry the talk track; the slide carries the visual. When OUTLINE content is prose-heavy, the smith puts the argument in `<aside class="notes">` and distills the slide.

## What themes may vary

Exactly as for components: class attributes and token values only — layout density, alignment, decorative emphasis — never elements, ordering, or sample content. A master may be centered and airy in one theme, start-aligned and dense in another, through classes alone.
