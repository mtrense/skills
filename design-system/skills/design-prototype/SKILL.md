---
name: design-prototype
description: >
  Render a quick, disposable design prototype to settle a visual question by eye: candidate color palettes, font pairings, spacing/radius/shadow directions, or whole token sets, shown side by side as swatches + type scale + a handful of sample components in light and dark. Trigger whenever a design decision stalls on words and looking would settle it — "prototype these two palettes", "show me how these fonts feel", "try warmer neutrals", "compare these token sets", or /design-prototype. Also invoked by /design-foundation and /design-themes mid-dialog. Writes ONE self-contained HTML file to a temp location (never under design-system/), opens it for the human, and reports the verdict back to the invoking session — the prototype itself is deliberately disposable; only the decision survives, recorded by the caller in FOUNDATION.md or the tokens. Do NOT trigger for building real components (/design-build) or anything meant to be kept.
argument-hint: "[the question + the candidate directions — e.g. 'warm vs cool neutrals with Inter/Fraunhofer pairing']"
model: sonnet
allowed-tools: Read, Write, Glob, Bash(mktemp *), Bash(open *), ToolSearch
---

# Design Prototype — Settle It by Eye

Design questions that stall in words resolve in seconds on screen. You render the candidates side by side in one throwaway page, put it in front of the human, and hand the verdict back. Nothing you produce is kept.

## Step 0 — Frame the question

From `$ARGUMENTS` (or the invoking session's context), establish: **what question** is being settled, and the **2–3 candidate directions** (a full candidate token set from `/design-themes`, or partial directions — two palettes, two font pairings). If only one candidate is given, invent a deliberate contrast for it — a single option gets a shrug, two get a preference. If candidates are partial, fill the rest with neutral defaults **identical across candidates** so only the question under test varies.

If `design-system/FOUNDATION.md` or `references.md` exist, skim them so the invented parts don't fight the established direction.

## Step 1 — Build the page

One self-contained HTML file in a temp dir (`mktemp -d`) — never under `design-system/`, never in the project tree. Inline everything: Tailwind browser CDN (`https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4`), candidates as scoped CSS-var blocks (`.candidate-a { --p-bg: …; }`), no external files.

Layout: one **column per candidate**, clearly labeled (A / B / C + a one-line description), each column showing the same content in the same order so the eye compares like with like:

1. **Swatch row** — the palette with each on/base pair rendered as text-on-fill, the computed contrast ratio printed in the corner of each swatch (compute it yourself; flag < 4.5 visibly).
2. **Type specimen** — the scale from display to caption in the candidate fonts, one realistic headline + paragraph, plus a line of tabular numerals.
3. **Sample components** — 3–5 inline: a button row (primary/secondary/ghost), an input with label + error, a card, an alert, a small nav strip. Approximate, static, honest — enough to feel the direction, not kitchen-sink quality.
4. **Dark block** — the same swatches + components on the candidate's dark values, immediately below the light ones.

### Give it room — the presentation contract

A cramped page loses the comparison it exists to make: everything crushed together reads as one texture and the human can't tell the candidates' spacing personality from the page's own. So:

- **Never compress to fit one screen.** Vertical scrolling is free and expected; shrinking type, swatches, or padding to avoid it is not. Nothing on this page is ever below its natural size.
- **Every moving part is its own separated band.** Swatch row, type specimen, each sample component, and the aggregated view are separate sections — each with a small uppercase caption label, generous padding (≈ `p-6`+), and a **visible horizontal rule** (or a distinct surface panel) between it and the next. Large gaps between bands (≈ `gap-12`), smaller gaps inside one (≈ `gap-4`).
- **A real gutter between candidate columns** — wide (≈ `gap-12`) and carrying a full-height vertical rule, so A never bleeds into B. Two candidates side by side; **three or more stack as full-width bands** instead of squeezing into narrow columns.
- **Swatches are big enough to judge** — at least ~7rem wide and ~4.5rem tall, gapped (not butted into a solid strip), with the label and its contrast ratio both legible at a glance.
- **Sample components get their real size** — laid out at a realistic content width, not shrunk into a thumbnail; one per row unless two genuinely sit side by side.
- **Light and dark are separated bands too**, each with its own mode caption and rule — not two adjacent boxes.

The page shell's own spacing is deliberately neutral (plain rules, plain captions) so it reads as scaffolding and the candidates' spacing is what stands out.

Keep it to one file, built in one Write. Resist polishing — this page has a life expectancy of minutes.

## Step 2 — Show it and collect the verdict

`open <file>` (macOS) to put it in the human's browser; if that's unavailable, load the Chrome tools via one ToolSearch call and open the `file://` URL in a new tab. Then ask the one question the page exists to answer — "A or B, and what would you steal from the loser?" — and iterate: a tweak request ("B but with A's neutrals") is a new column or an edited file, same loop, usually only a round or two.

## When you are done

Report the verdict as decisions, not vibes: which candidate won, the concrete values the human approved (hex, families, radius), and any cherry-picks across candidates. When invoked from `/design-foundation` or `/design-themes`, that report is the hand-back — the **caller** records it in FOUNDATION.md or the token set; you write nothing outside the temp dir and you leave the temp file where it is (the OS cleans it up).
