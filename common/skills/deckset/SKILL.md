---
name: deckset
description: >
  Create Deckset (macOS) presentations from existing markdown content, research, or knowledge bases.
argument-hint: "<topic/goals> [source: <path to content>] [audience: <who>] [duration: <minutes>]"
---

# Deckset — Build Presentations from Source Material

Create polished Deckset-format markdown presentations by distilling existing content (research docs, knowledge bases, notes, or any markdown) into focused, well-structured slide decks.

Deckset is a macOS app that renders `.md` files as slide decks. All formatting is plain Markdown with Deckset-specific conventions described below.

## Workflow

### Step 1: Understand the Request

Parse `$ARGUMENTS` for:
- **Topic / goals** — what the presentation should convey
- **Source material** — path to markdown files, a research directory, or a knowledge base
- **Audience** — who will watch this (developers, executives, students, conference attendees...)
- **Duration** — target length in minutes (affects slide count; ~1-2 minutes per slide is typical)
- **Tone** — technical depth, formality, storytelling vs. informational

If any of these are missing and can't be inferred, ask the user before proceeding. Source material is the most critical — you need something to distill.

### Step 2: Read the Source Material

Read the source content thoroughly. If it's a directory, start with any index or overview file, then read the most relevant documents. Build a mental model of:
- The key ideas and their relationships
- What's most important vs. supporting detail
- Natural narrative arcs or logical progressions
- Memorable examples, quotes, or data points worth highlighting

Don't try to cover everything. A good presentation is selective — it picks the ideas that matter most for this audience and these goals, and leaves the rest out.

### Step 3: Plan the Presentation Structure

Before writing slides, outline the structure. Present it to the user as a numbered list:

```
1. Title slide — [title], [subtitle if any]
2. Opening hook — [what grabs attention]
3. Context / Problem — [why this matters]
4-8. Core content slides — [key points, one per slide]
9. Key takeaway / Call to action
10. Closing / Q&A
```

Adapt this shape to the content. Not every talk needs a "problem" slide. Some are walkthroughs, some are reports, some are pitches. Match the structure to the goal.

Tell the user the planned slide count and estimated duration. Ask: "Does this structure work, or would you like to adjust the focus?"

### Step 4: Write the Presentation

Generate the full Deckset markdown file. Follow these principles:

**Structure:**
- Start with global config (theme, autoscale, build-lists, footer, slidenumbers — no blank lines between them)
- Separate slides with `---` (blank line above and below)
- Use `# [fit]` for title slides and key messages
- Use `##` for section titles, `###` for supporting points

**Content discipline:**
- One idea per slide. If you have 5 bullet points, ask whether they should be 2-3 slides
- Short text. Sentence fragments, keywords, short phrases. Long paragraphs look bad on slides
- Max 3-5 bullet points per slide. If you need more, split the slide
- Keep code blocks to 5-15 lines. Use `[.code-highlight:]` to focus attention

**Visual variety — mix these slide types:**
- `# [fit]` heading-only slides for impact statements
- Block quotes (`>`) for memorable takeaways (quote-only slides get special large formatting)
- `[.column]` layouts for comparisons, before/after, pros/cons
- Code blocks with progressive highlighting for technical content
- Clean bullet lists for sequential points

**Presenter notes:**
- Add `^` notes on content-heavy slides with the full explanation, context, or talking points
- The slide is the visual anchor; the notes are the script
- Notes are especially valuable for data slides, code walkthroughs, and nuanced points

**What to avoid:**
- Walls of text — if it reads like a document, it's not a presentation
- Orphan slides with a single bullet point (combine with adjacent slides)
- Overusing `[fit]` — it's for emphasis, not every heading
- Missing slide separators (every `---` needs blank lines above and below)

### Step 5: Save and Present

Save the `.md` file. Suggest a filename based on the topic (e.g., `api-design-patterns.md`).

Tell the user:
- The file path
- Total slide count
- Estimated duration at ~1.5 min/slide
- How to open it: "Open this file in Deckset to preview. You may want to adjust the theme — I used `[theme name]` but Deckset has many options."

Ask if they'd like to adjust any slides, change the depth on a topic, or add/remove sections.

## Theme Selection

Pick a theme that fits the tone. Some good defaults:
- **Fira** — clean, modern, good for technical talks
- **Next** — minimal, professional
- **Libre** — classic, readable
- **Merriweather** — warm, editorial feel
- **Ostrich** — bold, high-contrast

If the user hasn't specified, default to `Fira` for technical content or `Next` for general presentations.

## Handling Different Source Types

**Research directory** (with INDEX.md, content/ subdirectory): Read INDEX.md first to understand the topic landscape, then read the most relevant content files based on the presentation goals. The research structure gives you a natural outline to work from.

**Single long document**: Identify the key sections and extract the most presentation-worthy points. Don't try to present every section — pick what matters for the audience.

**Multiple loose files**: Scan all of them, identify common themes, and synthesize. The presentation should feel unified, not like a file-by-file walkthrough.

**Minimal notes or bullet points**: The user is giving you the skeleton — flesh it out with clear slide content while staying true to their intent. Ask clarifying questions if the notes are ambiguous.

---

## Deckset Formatting Reference

### File Structure

Global configuration commands go at the very top with **no blank lines between them**. Slides are separated by `---` (three dashes on their own line, blank line above and below).

```markdown
theme: Fira, 5
autoscale: true
build-lists: true
slidenumbers: true
footer: © Acme Corp 2026

# First Slide Title

Content here

---

# Second Slide Title

More content
```

### Global Configuration Commands

Place at the **top of the file** with no blank lines between them.

| Command | Values | Purpose |
|---------|--------|---------|
| `theme:` | `Fira`, `Next`, `Libre`, `Merriweather`, etc. | Set presentation theme |
| `autoscale:` | `true` | Auto-shrink body text to fit slide |
| `build-lists:` | `true` | Animate list items one-by-one |
| `footer:` | Text string | Footer on every slide |
| `slidenumbers:` | `true` | Show slide numbers |
| `slidecount:` | `true` | Show total slide count alongside number |
| `slide-transition:` | `true`, `fade(0.3)`, `push(horizontal)`, etc. | Transition between slides |
| `background-image:` | `image.jpg` | Default background for all slides |
| `fit-header:` | `#`, `##` | Auto-fit specified heading levels |

### Per-Slide Configuration

Override global settings on individual slides using bracket notation at the top of the slide:

```markdown
[.autoscale: true]
[.build-lists: false]
[.footer: Custom footer]
[.hide-footer]
[.slidenumbers: false]
[.background-color: #1a1a2e]
[.slide-transition: fade(0.5)]
```

### Headings

Four levels available. Use `[fit]` to auto-scale a heading to fill the slide width.

```markdown
# [fit] This Heading Fills the Slide
```

Use `<br>` for line breaks within headings.

### Block Quotes

Slides containing **only** a quote get special large-format styling.

```markdown
> The best way to predict the future is to invent it.
-- Alan Kay
```

Use `--` (two dashes) before the author name.

### Code Blocks

Fenced code blocks with language for syntax highlighting. Deckset auto-scales code to fit.

Highlight specific lines using `[.code-highlight:]`:

```markdown
[.code-highlight: 2]
[.code-highlight: 2, 6-8]
[.code-highlight: all]
```

For progressive highlighting (build steps), stack multiple highlights:

```markdown
[.code-highlight: none]
[.code-highlight: 2]
[.code-highlight: 6-8]
[.code-highlight: all]
```

### Images

```markdown
![](image.jpg)              # fill entire slide
![fit](image.jpg)           # fit within slide, maintaining aspect
![left](image.jpg)          # fill left half (content goes right)
![right](image.jpg)         # fill right half (content goes left)
![inline](image.jpg)        # placed within content flow
![inline 50%](image.jpg)    # inline at 50% size
```

Multiple background images create a grid. Multiple inline images side by side:

```markdown
![inline fill](a.jpg)![inline fill](b.jpg)
```

### Columns

Use `[.column]` to split slide content into columns:

```markdown
[.column]

### Left Column
Content for left side

[.column]

### Right Column
Content for right side
```

### Tables

Standard Markdown table syntax with alignment support:

```markdown
| Left | Center | Right |
|------|:------:|------:|
| A    | B      | C     |
```

### Presenter Notes

A line containing only `^` starts presenter notes for that slide. Everything after it is visible only in Presenter mode.

```markdown
# Slide Title

Visible content here.

^
- This is a presenter note
- Use regular markdown after the opening caret
```

Only one `^` is needed per slide — do not prefix every notes line with `^`.

### Footnotes

```markdown
This claim needs a citation[^1].

[^1]: Source: Author, "Title", Year.
```

### Formulas (LaTeX)

Display: `$$ E = mc^2 $$` on its own line. Inline: `$$a = 2$$` within text.

### Slide Transitions

Per-slide: `[.slide-transition: push(horizontal, 0.3)]` or `[.slide-transition: false]`

Types: `fade(duration)`, `push(horizontal|vertical)`, `move(direction)`, `reveal(direction)`

### Text Styling

```markdown
[.text: #000000, alignment(left), line-height(10), text-scale(2.0), Font Name]
[.header: #FF0000, alignment(center), text-scale(3.0), Font Name]
[.list: bullet-character(→), bullet-color(#ffcc00)]
```

### Videos

```markdown
![](video.mov)                          # background video
![autoplay loop mute](video.mov)        # auto-playing background
![](https://youtube.com/watch?v=ID)     # YouTube embed
```
