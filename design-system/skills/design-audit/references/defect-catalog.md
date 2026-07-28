# Visual Defect Catalog

The named defect classes the `visual-critic` checks per story, in addition to its page-level rubric. This is a **living document**: every time a defect ships that the audit missed, append its class here — the audit gets monotonically sharper from real failures, and a checklist entry is cheaper than a prompt rewrite.

Each class states what it looks like in a screenshot, the usual root cause, and the default severity. A small defect that repeats across components or themes is **systemic** and rates `major` regardless of its size on screen.

## stretched-sample

**Looks like:** a control (button, badge, chip) filling the story row or the whole viewport width when its spec doesn't call for full-bleed.
**Root cause:** the story wrapper is block-level and the sample carries no `w-fit`/inline-flex constraint — CSS default stretch, not a design decision.
**Severity:** major — it also invalidates every other judgment about that sample (proportion, padding, color mass).

## off-mode-accent

**Looks like:** an accent fill (primary button, selected band) that reads pasted-in against the mode's background — typically a light-mode pastel reused verbatim on a dark warm/cool background. Contrast passes; harmony doesn't.
**Root cause:** the dark mode reuses the light mode's accent hex instead of re-tuning lightness/saturation per the conventions' per-mode accent rule.
**Severity:** major when it affects a large fill; minor for small accents. Route to `/design-revise <theme>` (token change), not to the component.

## group-proximity-inversion

**Looks like:** spacing that contradicts grouping — items within one set spaced further apart than the set is from its heading/label, or from unrelated neighbors. The eye reads the wrong things as belonging together.
**Root cause:** gap classes chosen per element instead of per relationship; no proximity check in the layout.
**Severity:** major when it breaks a label-group relationship; minor for mild unevenness.

## doubled-focus-ring

**Looks like:** two concentric focus rings on one control — typically a composite (affixed input, input-with-button) where both the group wrapper and the inner element carry focus styling.
**Root cause:** the one-indicator-per-interactive-unit rule (conventions, a11y contract) not applied; focus styling duplicated instead of owned by the group container via focus-within.
**Severity:** major — it's visible on every keyboard interaction.

## radius-content-conflict

**Looks like:** a fully-rounded shape (pill, badge) whose content wrapped to multiple lines, producing bloated capsule corners; or truncation/wrap behavior that contradicts the component's spec.
**Root cause:** no `**Overflow**` decision in the COMPONENTS.md section, so the smith improvised wrap where the spec should have said truncate or disallow.
**Severity:** major. If the spec genuinely lacks the Overflow line, route to `/design-components` revision, not the component build.

## cramped-padding

**Looks like:** control padding or stack gaps visibly below the foundation's density direction — a "spacious" system rendering buttons whose focus ring hugs the text, list rows with no air.
**Root cause:** the FOUNDATION.md `## Dials` floors (min control padding, min stack gap) missing or ignored by the build.
**Severity:** major when systemic across a component's stories; minor for a single sample. Judge against the dials' concrete floors, not taste.
