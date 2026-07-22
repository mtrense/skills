# Standard Component Catalog

The reference catalog `/design-components` starts from — trimmed and extended per project during the dialog, never shipped wholesale without asking. Grouped in suggested kitchen-sink order. Each entry: what it is, typical variants, and the states/a11y notes that must not be forgotten.

## Actions

- `button` — the workhorse. Variants: primary, secondary, ghost/tertiary, destructive; sizes sm/md/lg; with leading/trailing icon. States: hover, focus-visible, disabled, loading (static spinner sample).
- `icon-button` — icon-only action; requires `aria-label`; tooltip pairing optional.
- `button-group` — segmented set of related actions; `role="group"` with a label.
- `link` — inline and standalone; visited/hover/focus styles; external-link affordance.

## Forms

- `input` — text input with label, help text, error message wiring (`aria-describedby`, `aria-invalid`); states: default, focus, disabled, invalid; with prefix/suffix affix sample.
- `textarea` — multi-line; resize behavior specified.
- `select` — native `<select>` styled; labeled, disabled, invalid states.
- `checkbox` — single + group; indeterminate shown statically; label click-target.
- `radio` — group with `fieldset`/`legend`; disabled option sample.
- `switch` — on/off toggle (`role="switch"`, `aria-checked`); both states as parallel samples.
- `slider` — native `<input type="range">` styled; value label.
- `field` — the composed form row: label + control + help + error, the layout contract all form controls share.
- `search` — input specialization with icon, clear affordance, `role="search"` landmark.

## Display

- `card` — surface container: media/header/body/footer slots; interactive (whole-card link) and static variants.
- `badge` — small status label; status-role color variants; never color-only (icon or text pairs it).
- `tag` — dismissible chip; with remove affordance (labeled).
- `avatar` — image, initials fallback, sizes; grouped/stacked sample.
- `table` — data table: `<caption>`, `<th scope>`, alignment rules (numeric end-aligned), row hover, dense + comfortable density samples; locale-formatted number/date columns.
- `list` — styled item list; the classic theme-variance showcase (one-per-row vs two-column grid across themes).
- `stat` — key figure + label + delta; locale-formatted number slot.
- `accordion` — expand/collapse sections via `<details>`/`<summary>`; open + closed samples.
- `tooltip` — static positioning sample; note that real behavior is the consumer's (never the only way to reach content).

## Navigation

- `navbar` — top app bar: brand, nav links, actions; `<nav>` with label; current page marked `aria-current="page"`.
- `sidebar` — vertical navigation with sections and active state.
- `tabs` — tablist pattern (`role="tablist"/"tab"/"tabpanel"`); active + inactive; overflow behavior specified.
- `breadcrumbs` — `<nav aria-label="Breadcrumb">` + ordered list; separator is decorative (`aria-hidden`).
- `pagination` — page list + prev/next; current marked `aria-current`; disabled edges.
- `menu` — dropdown panel shown statically open; grouped items, destructive item, keyboard hints optional.

## Feedback

- `alert` — inline callout: info/success/warning/danger; `role="alert"` only for the assertive variants; icon + text pairing.
- `toast` — transient notification, statically placed; `role="status"`; with action sample.
- `modal` — `<dialog>`-based; header/body/footer, labeled, close affordance; shown statically open.
- `progress` — determinate bar (`<progress>` or `role="progressbar"` with value attrs) + label.
- `spinner` — indeterminate loading; `role="status"` with visually-hidden text.
- `skeleton` — loading placeholders for text/media/card; `aria-hidden` (a live region elsewhere announces loading).
- `empty-state` — icon/illustration + headline + explanation + primary action.
