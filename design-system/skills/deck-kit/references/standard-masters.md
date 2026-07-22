# Standard Master Catalog

The reference set `/deck-kit` starts from — trimmed and extended per project during the dialog, never shipped wholesale without asking. In suggested sample-deck order. Each entry: what it is, its content slots, the content budget that must not be forgotten, and theme-variance notes.

- `title` — the opening slide. Slots: deck title, subtitle/speaker, date (`data-ds-locale="date"`), optional brand mark. Budget: title ≤ 8 words. Variance: the theme's one moment of maximal personality — background treatment, display type.
- `agenda` — where we're going. Slots: 3–6 labeled items, optional numbers. Budget: ≤ 6 items × ≤ 6 words. Variance: list vs grid layout.
- `section-divider` — act break. Slots: section number, section title, optional one-line teaser. Budget: title ≤ 6 words. Variance: like `title` but quieter; must be instantly distinguishable from a content slide.
- `content` — the workhorse: headline + bullets or short prose. Slots: headline, ≤ 5 bullets (≤ 12 words each) OR ≤ 8 lines of prose, never both. The classic overflow offender — busting the budget splits the slide, never shrinks the type. Variance: density, bullet markers, alignment.
- `two-column` — comparison or text-beside-visual. Slots: headline, two labeled columns (text, image, or list each). Budget: ≤ 5 short lines per column. Variance: column ratio, divider treatment, stacking rhythm.
- `image-full` — one visual carries the slide. Slots: full-bleed or framed image (`<img>` with real `alt`), one-line caption, optional attribution. Budget: caption ≤ 15 words. Variance: bleed vs framed, caption placement (logical classes).
- `quote` — one voice, verbatim. Slots: `<blockquote>` ≤ 30 words, attribution with name/role in `<cite>`. Variance: quote-mark treatment, scale, alignment.
- `code` — a code moment. Slots: headline, one `<pre><code>` block ≤ 12 lines × ≤ 60 columns, optional one-line takeaway. `--r-code-font`; no syntax-highlight JS — static `<span>` coloring through tokens if highlighting matters. Variance: frame/chrome around the block.
- `data` — one number or one chart. Slots: either a big stat (value marked `data-ds-locale="number|currency"`, label, delta) or one image/inline-SVG chart with caption; a slide makes one point, so one stat group or one chart. Variance: stat scale, accent usage.
- `closing` — the ask and the exit. Slots: closing statement or CTA, contact/link line, optional brand mark. Budget: statement ≤ 10 words. Variance: mirrors `title`'s treatment.
