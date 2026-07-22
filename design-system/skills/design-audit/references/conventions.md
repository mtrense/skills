# Design-System Conventions

The canonical contract every design-system skill and subagent targets. The deterministic half is enforced by `design-check.sh` (same directory); the rest is enforced by the orchestrating skills and the `component-smith` worker.

## Target layout (in the consuming project)

```
design-system/
  FOUNDATION.md                # design brief — the Socratic dialog's result (/design-foundation)
  THEMES.md                    # one section per theme: intent, personality, key token rationale (/design-themes)
  COMPONENTS.md                # structural spec + machine-readable ## Catalog (/design-components)
  references.md                # persisted digest of the analyzed references (/design-foundation, appended later)
  index.html                   # root browser linking every theme dir (assemble.sh index)
  <theme>-<light|dark>/        # one directory per theme × mode — mode is baked into the directory, never a runtime toggle
    index.html                 # kitchen-sink of every component, marker-delimited (assemble.sh assemble)
    index.css                  # :root { --ds-* } tokens + minimal global CSS
    tokens.md                  # human/agent-readable token documentation
  .fragments/<slug>/<theme-dir>.html   # build intermediates — workers write, assemble.sh consumes, deleted after assembly
```

## Catalog grammar (COMPONENTS.md)

`COMPONENTS.md` opens with a `## Catalog` section listing every component as `- \`slug\` — one-liner`, in kitchen-sink order. That line grammar (`^- \`[a-z0-9-]+\``) is machine-read by `assemble.sh` and `design-check.sh` — never reformat it. Each component then gets its own `## <Name>` section: anatomy (the shared DOM sketch), variants, states, accessibility contract, i18n slots, and theme-variance notes.

Two lines inside a component section are machine-read too. The `- **Slug**: \`<slug>\`` line binds the section to its catalog slug, and the `- **Variants**:` entry is a nested list `` - `variant-slug` — when-to-use one-liner `` (two-space indent, same backtick grammar as the catalog) — `design-check.sh` parses both to verify every spec'd variant ships its story sample (see Stories below) in every theme. Never fold the variant list back into prose.

## Markers and fragments

Every component in a kitchen-sink is delimited exactly once:

```html
<!-- component: button -->
<section id="component-button" aria-labelledby="component-button-h">
  <h2 id="component-button-h" class="text-lg font-semibold">Button</h2>
  …
</section>
<!-- /component: button -->
```

The marker pair + `id="component-<slug>"` anchor is the resumability and audit contract: `assemble.sh missing` derives the build worklist from it, and revisions replace exactly one block. Fragments are the same block written to `.fragments/<slug>/<theme-dir>.html` by `component-smith`; only `assemble.sh` writes an `index.html`.

## Tokens

Tokens are CSS custom properties on `:root` in each theme dir's `index.css`, prefix `--ds-`. Because mode lives in the directory, a dark mode is simply a different `index.css` — no `dark:` variants, no media queries, no class toggles in the markup.

**Required color roles** (checked): `--ds-color-bg`, `--ds-color-on-bg`, `--ds-color-surface`, `--ds-color-on-surface`, `--ds-color-primary`, `--ds-color-on-primary`, `--ds-color-border`. Recommended additions: `muted`/`on-muted`, and the status roles `success`/`warning`/`danger`/`info`, each with its `on-*` partner.

**The contrast contract:** every `--ds-color-on-<x>` is the foreground used on `--ds-color-<x>`, and each pair must meet WCAG AA (≥ 4.5:1). `design-check.sh` computes this from hex values — keep color tokens in 6-digit hex so the gate can do the math.

**Typography:** `--ds-font-sans` (required) and optionally `--ds-font-mono` / `--ds-font-display`. Every stack ends in a generic family, and `tokens.md` records the intended script coverage (Latin, Cyrillic, CJK, Arabic, …) and the fallback rationale.

**Scales:** `--ds-radius-sm|md|lg`, `--ds-shadow-sm|md|lg` as the theme needs them. Spacing normally rides on Tailwind's own scale; themes vary density through the classes they choose, not through spacing tokens.

`index.css` also carries the base styles so pages render without utility soup on `<body>`:

```css
body { background: var(--ds-color-bg); color: var(--ds-color-on-bg); font-family: var(--ds-font-sans); }
```

plus any genuinely global CSS the theme needs (focus ring defaults, scrollbar styling). Keep it minimal — components style themselves.

## Markup rules

- **Shared DOM across themes.** A component's element structure, ordering, ARIA wiring, and sample content are byte-identical in every theme dir. Themes differ only in the `class` attributes (and their token values) — a list may be one-per-row in one theme and two-column in another, but through classes, never through different elements.
- **Tokens via Tailwind v4 var shorthand:** `bg-(--ds-color-surface)`, `text-(--ds-color-on-surface)`, `border-(--ds-color-border)`, `rounded-(--ds-radius-md)`, `shadow-(--ds-shadow-sm)`. Literal Tailwind colors (`bg-blue-500`) are forbidden in components — every color goes through a token so re-theming never touches markup structure.
- **Logical direction only:** `ms-*`/`me-*`/`ps-*`/`pe-*`, `text-start`/`text-end`, `rounded-s-*`/`rounded-e-*`, `border-s`/`border-e`, `start-*`/`end-*`. Physical classes (`ml-*`, `text-left`, `rounded-l-*`, …) fail the gate; the rare legitimately-physical line (e.g. a media control) carries `data-ds-physical` as an explicit opt-out.
- **No JavaScript.** State that needs interactivity is shown as parallel static samples (open + closed accordion, checked + unchecked switch) — the consuming project adds behavior.
- Pages load Tailwind via the browser CDN (`<script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>`) and `<link rel="stylesheet" href="index.css">`, so everything opens from disk with no build step; a consuming project lifts the markup plus the token vars into its own Tailwind build.

## Stories — the machine-readable sample split

Every discrete sample inside a component block is wrapped in exactly one element carrying `data-ds-story="<story-slug>"` (kebab-case, unique within the block). The story marker is what lets a downstream consumer — the gate, a revision pass, a storybook-style viewer — address one sample without parsing prose headings. Reserved slugs:

- `variant-<variant-slug>` — one per variant the COMPONENTS.md spec lists (same slug as the spec's variant list).
- `state-<state>` — one per statically-showable state sample (`state-disabled`, `state-focus-visible`, `state-invalid`, …).
- `rtl` — the RTL sample; `long-string` — the long-string sample.
- Additional samples take free-form slugs (`sizes`, `with-icon`, …).

Because the DOM is shared, a component's story set is identical in every theme dir — `design-check.sh` fails a cross-theme mismatch, fails duplicate slugs within a block, and warns when a spec'd variant has no `variant-<slug>` story.

## Samples every component block must ship

1. **Variants** — every variant the COMPONENTS.md spec lists, labeled, each wrapped `data-ds-story="variant-<variant-slug>"`.
2. **States** — default, hover/active where showable statically, `focus-visible` styling, disabled, error/invalid where applicable — each wrapped `data-ds-story="state-<state>"`.
3. **RTL sample** — at least one rendering wrapped in `dir="rtl"` with RTL-script sample text (e.g. Arabic); story slug `rtl`.
4. **Long-string sample** — one rendering with German/Finnish-length labels, the stressed element marked `data-ds-sample="long"`, demonstrating the specified wrap/truncate behavior; story slug `long-string`.
5. **Locale slots** — any date, number, or currency shown is sample content, marked `data-ds-locale="date|number|currency"`; COMPONENTS.md documents the slot as locale-formatted, never a committed format.

## Accessibility contract

- WCAG 2.2 AA is the floor unless FOUNDATION.md sets a higher bar.
- Semantic elements first (`<button>`, `<nav>`, `<table>`, `<dialog>`); ARIA roles/attributes exactly where the pattern requires them (per the APG), not decoratively.
- Keyboard reachability is visible: every interactive sample has `focus-visible` styling driven by tokens.
- `<html>` carries `lang` and `dir`; icons are inline SVG with `aria-hidden="true"` plus a text label (or `aria-label` where text is absent).
- Color is never the only signal — status components pair color with an icon or text.
