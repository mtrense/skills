# Deckset Presentation Authoring Guide

Guidelines for generating valid Deckset (macOS) presentations in Markdown. Deckset renders `.md` files as slide decks — every formatting decision is made in plain text.

> **Sources**: [Deckset Markdown Documentation](https://docs.deckset.com/markdownDocumentation.html), [sjsyrek/deckset-tutorial](https://github.com/sjsyrek/deckset-tutorial), [rooreynolds/cheatsheet](https://github.com/rooreynolds/presentations/blob/master/cheatsheet/cheatsheet.md)

---

## 1. File Structure

A Deckset file is a single `.md` file. Global configuration commands go at the very top with **no blank lines between them**. Slides are separated by `---` (three dashes on their own line, blank line above and below).

```markdown
theme: Libre, 5
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

---

## 2. Global Configuration Commands

Place these at the **top of the file** with no blank lines between them. They affect all slides unless overridden per-slide.

| Command | Values | Purpose |
|---------|--------|---------|
| `theme:` | Theme name (e.g., `Fira`, `Next`, `Merriweather`) | Set presentation theme |
| `autoscale:` | `true` | Auto-shrink body text to fit slide |
| `build-lists:` | `true`, `all`, `notFirst` | Animate list items one-by-one |
| `footer:` | Text string | Footer on every slide |
| `slidenumbers:` | `true` | Show slide numbers |
| `slidecount:` | `true` | Show total slide count alongside number |
| `slide-transition:` | `true`, `fade(0.3)`, `push(horizontal)`, etc. | Transition between slides |
| `slide-dividers:` | `#`, `##`, `###`, `####` | Auto-split slides at headings (instead of `---`) |
| `background-image:` | `image.jpg` | Default background for all slides |
| `code-language:` | Language name (e.g., `Swift`) | Default language for code blocks |
| `fit-header:` | `#`, `##` | Auto-fit specified heading levels |
| `paragraphs-as-presenter-notes:` | `true` | Treat body text as presenter notes |
| `time-budget:` | Minutes (e.g., `20`) | Target presentation time |
| `image-corner-radius:` | Pixels (e.g., `12`) | Default corner radius for images |

---

## 3. Per-Slide Configuration Commands

Override global settings on individual slides using bracket notation. Place at the top of the slide content.

```markdown
---

[.autoscale: true]
[.build-lists: false]
[.footer: Custom footer for this slide]
[.hide-footer]
[.slidenumbers: false]
[.background-color: #1a1a2e]
[.slide-transition: fade(0.5)]

# Slide Content Here
```

---

## 4. Headings

Four levels available. Use `[fit]` to auto-scale a heading to fill the slide width.

```markdown
# Heading 1
## Heading 2
### Heading 3
#### Heading 4

# [fit] This Heading Fills the Slide
```

Use `<br>` for line breaks within headings.

---

## 5. Text Formatting

```markdown
*italic* or _italic_
**bold** or __bold__
***bold italic***
~~strikethrough~~
`inline code`
```

Superscript and subscript: `<sup>text</sup>`, `<sub>text</sub>`

Paragraphs are separated by blank lines. Use `<br>` for explicit line breaks within text.

---

## 6. Lists

```markdown
- Unordered item
- Another item
    - Nested (indent 4 spaces)

1. Ordered item
2. Another item
    1. Nested ordered
```

To preserve your exact numbering (e.g., for non-sequential lists):

```markdown
[.use-source-list-numbering]
1. First
3. Third
5. Fifth
```

---

## 7. Block Quotes

Slides containing only a quote get special large-format styling.

```markdown
> The best way to predict the future is to invent it.
-- Alan Kay
```

Use `--` (two dashes) before the author name.

---

## 8. Code Blocks

Fenced code blocks with language for syntax highlighting. Deckset auto-scales code to fit.

````markdown
```python
def greet(name):
    return f"Hello, {name}"
```
````

### Code Highlighting

Highlight specific lines using `[.code-highlight:]` before the code block:

```markdown
[.code-highlight: 2]
[.code-highlight: 2, 6-8]
[.code-highlight: all]
[.code-highlight: none]
```

For progressive highlighting (build steps), stack multiple highlights:

```markdown
[.code-highlight: none]
[.code-highlight: 2]
[.code-highlight: 6-8]
[.code-highlight: all]
```

Line numbers: `` ```python, [.line-numbers: true] ``

### Code Styling

```markdown
[.code: auto(42), Fira Code, line-height(4.2)]
[.code: #ffcc00, #1b1b1b, #ffffff]
```

---

## 9. Images

### Background Images (fill the slide)

```markdown
![](image.jpg)              # fill entire slide (default)
![fit](image.jpg)           # fit within slide, maintaining aspect
![original](image.jpg)      # no text-darkening filter
![original 250%](image.jpg) # zoomed
![left](image.jpg)          # fill left half (content goes right)
![right](image.jpg)         # fill right half (content goes left)
![left fit](image.jpg)      # fit in left half
![right filtered](image.jpg)# right half with dark overlay
![right alpha(0.6)](image.jpg) # right half, 60% opacity
```

Multiple background images create a grid:

```markdown
![](image1.jpg)
![](image2.jpg)
```

### Inline Images (placed within content flow)

```markdown
![inline](image.jpg)
![inline fill](image.jpg)
![inline 50%](image.jpg)
![inline corner-radius(16)](image.jpg)
```

Multiple inline images side by side:

```markdown
![inline fill](a.jpg)![inline fill](b.jpg)
```

---

## 10. Columns

Use `[.column]` to split slide content into columns. Widths are distributed evenly.

```markdown
[.column]

### Left Column

Content for left side

[.column]

### Right Column

Content for right side
```

You can have more than two columns. Combine with `[.autoscale: true]` for dense content.

---

## 11. Tables

Standard Markdown table syntax. Supports alignment.

```markdown
| Left | Center | Right |
|------|:------:|------:|
| A    | B      | C     |
| D    | E      | F     |
```

Style with:

```markdown
[.table-separator: #000000, stroke-width(10)]
[.table: margin(5)]
```

---

## 12. Presenter Notes

A line containing only `^` starts the presenter-notes block for that slide. Everything after it (until the next `---` slide break) is visible only in Presenter/Rehearsal mode.

```markdown
# Slide Title

Visible content here.

^
- This is a presenter note. It won't appear on the projected slide.
- Use regular markdown (bullets, paragraphs) after the opening caret.
```

Only one `^` is needed per slide — do **not** prefix every notes line with `^`.

---

## 13. Footnotes

```markdown
This claim needs a citation[^1].

[^1]: Source: Author, "Title", Year.
```

Named footnotes: `[^Wiles, 1995]` with matching `[^Wiles, 1995]: ...` definition.

---

## 14. Formulas (LaTeX)

Display formula (centered, own block):

```markdown
$$
E = mc^2
$$
```

Inline formula: `The slope $$a$$ of the line $$f(x) = 2x$$ is $$a = 2$$.`

---

## 15. Emojis

GitHub-style shortcodes: `:thumbsup:`, `:rocket:`, `:warning:`, etc. Or paste Unicode emoji directly.

---

## 16. Links

```markdown
[Link text](https://example.com)
```

Internal slide links:

```markdown
<a name="target"></a>
[Jump to section](#target)
```

Links are clickable in exported PDFs.

---

## 17. Slide Transitions

Global (top of file):

```markdown
slide-transition: fade(0.3)
```

Per-slide:

```markdown
[.slide-transition: push(horizontal, 0.3)]
[.slide-transition: false]
```

Available types:
- `fade(duration)`
- `fadeThroughColor(#000000)`
- `push(horizontal|vertical|top|right|bottom|left)`
- `move(horizontal|vertical|top|right|bottom|left)`
- `reveal(horizontal|vertical|top|right|bottom|left)`

---

## 18. Text Styling Commands

Fine-grained per-slide style control:

```markdown
[.text: #000000, alignment(left), line-height(10), text-scale(2.0), Font Name]
[.text-emphasis: #FF0000, Font Name]
[.text-strong: #0000FF, Font Name]
[.header: #FF0000, alignment(center), text-scale(3.0), Font Name]
[.header-emphasis: properties]
[.header-strong: properties]
[.footer-style: #2F2F2F, alignment(center), text-scale(1.5)]
[.slidenumber-style: #999999]
[.quote: alignment(left), text-scale(2.0)]
[.quote-author: #666666]
[.list: bullet-character(→), bullet-color(#ffcc00)]
```

---

## 19. Build Steps (Progressive Reveal)

- **Lists**: Use `build-lists: true` globally or `[.build-lists: true]` per-slide
- **Code**: Stack multiple `[.code-highlight:]` directives (each becomes a build step)
- **Images**: Not natively supported — use multiple slides instead

---

## 20. Videos and Audio

```markdown
![](video.mov)                          # background video
![inline](video.mov)                    # inline video
![autoplay loop mute](video.mov)        # auto-playing background
![](https://youtube.com/watch?v=ID)     # YouTube embed
![hide](audio.mp3)                      # background audio, no controls
```

---

## Authoring Principles for AI-Generated Decks

When generating Deckset presentations:

1. **One idea per slide.** Dense slides defeat the purpose. If you have 5 bullet points, consider whether they should be 2-3 slides instead.

2. **Use headings as the primary hierarchy.** `#` for title slides, `##` for section content, `###` and `####` for supporting points. Deckset themes style these distinctly.

3. **Prefer short text.** Deckset is designed for presentations, not documents. Use sentence fragments, keywords, and short phrases. Long paragraphs look bad and are hard to read.

4. **Leverage block quotes for key takeaways.** A slide with only a `>` quote gets special large-format treatment — use this for memorable statements.

5. **Use `[fit]` headings for impact.** `# [fit] Key Message` fills the slide and creates visual emphasis.

6. **Presenter notes for detail.** Put the full explanation in `^` notes. The slide itself should be the visual anchor, not the script.

7. **Keep code blocks short.** 5-15 lines max. Use `[.code-highlight:]` to draw attention to specific lines rather than showing everything at once.

8. **Use columns for comparisons.** Side-by-side `[.column]` layouts work well for before/after, pros/cons, or contrasting approaches.

9. **Separate slides with `---` explicitly.** Don't rely on `slide-dividers:` unless you have a specific reason — explicit separators are clearer and less error-prone.

10. **Global config first, always.** Start every file with theme, autoscale, footer, and slidenumbers. No blank lines between config commands.

11. **Image references assume local files.** Use relative paths (`images/diagram.png`) or placeholder comments (`<!-- TODO: add diagram -->`) when images aren't available yet.

12. **Test with `autoscale: true`.** This prevents text overflow, especially on content-heavy slides. Combine with columns for dense information.
