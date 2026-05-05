---
name: research-generate-graphics
description: "Generate graphics (SVG diagrams, charts, tables, schematics) from AUDIT comments with type: graphics. Creates assets in the topic's _assets folder. Arguments: optional topic path or specific file:line."
argument-hint: "[topic-path | file:line]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Write, Glob, Grep, Edit, Bash(grep *), Bash(bash */skills/research-refine/list-audits.sh *), Bash(mkdir *), Bash(ls *)
---

# Research Graphics

You are generating visual assets from `type: graphics` AUDIT comments in research content. Each AUDIT comment describes a graphic that would improve comprehension — you create it.

**Arguments**: `$ARGUMENTS`
- First argument (optional): topic file path relative to `research/content/`, or `file:line` pointing to a specific AUDIT comment. Omit to auto-discover the next graphics AUDIT.

## No-Argument Default

If `$ARGUMENTS` is empty, auto-discover the next graphics AUDIT:

1. Run `bash <skill-directory>/../research-refine/list-audits.sh research` to list all AUDIT comments.
2. Read each listed AUDIT comment and find the first with `type: graphics`.
3. If none found, tell the user "No graphics AUDIT comments found." and stop.
4. Proceed with that file and AUDIT comment.

## Prerequisites

1. Read `research/INDEX.md` to check the topic's status.
   - Topics with status `stub` or `inquiry` are skipped — abort if targeted.
   - Topics with status `draft`, `audited`, or `done` are eligible.
2. Read `research/CLAUDE.md` for project conventions, especially any graphical language or style guidance.
3. Read the target topic file and the surrounding context of the AUDIT comment.
4. Read `research/glossary.md` for correct terminology.

## Graphic Generation

### Read the AUDIT Comment

Extract the structured fields:
```html
<!-- AUDIT:
  type: graphics
  severity: minor | major
  detail: "description of what the graphic should convey"
  graphic-type: diagram | graph | table | schematic | screenshot
  ref: "optional cross-reference"
-->
```

The `detail` field is your primary brief. The `graphic-type` guides format choice.

### Choose the Output Format

Prefer formats in this order based on `graphic-type` and content:

1. **SVG** (preferred for diagrams, schematics, flowcharts, architecture diagrams, state machines, decision trees, sequence diagrams, network topologies, data format layouts, memory layouts)
   - Hand-written SVG markup — clean, semantic, and re-stylable
   - Use `currentColor` and CSS classes for colors so the graphic adapts to light/dark themes
   - Use readable font stacks: `font-family="system-ui, sans-serif"`
   - Keep viewBox tight to content; do not hardcode width/height on the root element
   - Group related elements with `<g>` and descriptive `id` attributes
   - Provide a `<title>` element for accessibility

2. **SVG** (also preferred for graphs, charts, trade-off curves, distributions)
   - Same SVG conventions as above
   - Include axis labels, legends, and data annotations directly in the SVG
   - Use `<text>` elements for labels — no embedded raster text

3. **Markdown table** (for comparisons, option matrices, property summaries)
   - Embed directly in the topic file — no separate asset file
   - Use standard GitHub-flavored markdown table syntax

4. **Screenshot** (`graphic-type: screenshot`)
   - You cannot take screenshots. Leave a TODO comment in the topic file:
     `<!-- TODO: screenshot needed — [detail from AUDIT] -->`
   - Remove the AUDIT comment and note the TODO in your summary.

### SVG Design Principles

- **Clarity over decoration**: every element must convey information. No ornamental gradients, shadows, or 3D effects.
- **Consistent spacing**: use a grid (e.g., 20px increments) for positioning. Align elements on the grid.
- **Readable text**: minimum 12px font size. Labels should be concise.
- **Arrows and connectors**: use `<marker>` definitions for arrowheads. Keep lines orthogonal or use clean curves — no arbitrary angles.
- **Color as secondary channel**: shape and position carry the primary meaning. Color reinforces but never serves as the sole differentiator. Use CSS classes (`.primary`, `.secondary`, `.accent`, `.muted`) rather than hardcoded hex values. Define a minimal `<style>` block with reasonable defaults.
- **Responsive**: no fixed width/height on root `<svg>`. Use `viewBox` for intrinsic sizing.
- **Self-contained**: no external dependencies (fonts, images, stylesheets).

### Asset Placement

For SVG and image assets:

1. Determine the asset directory: if the topic file is `topic-name.md`, the asset directory is `topic-name_assets/` in the same parent directory.
2. Create the directory if it doesn't exist: `mkdir -p <asset-dir>`.
3. Choose a descriptive filename: `<brief-slug>.svg` (e.g., `auth-flow.svg`, `performance-comparison.svg`).
4. Write the SVG file to `<asset-dir>/<filename>.svg`.
5. Insert a markdown image reference in the topic file immediately where the AUDIT comment was:
   ```markdown
   ![Brief description](topic-name_assets/filename.svg)
   ```

For markdown tables: embed directly in the topic file at the AUDIT comment location. No asset file needed.

## After Generation

1. **Remove the resolved AUDIT comment** from the topic file.
2. **Insert the graphic reference** (or inline table) at the AUDIT comment's former location.
3. **Update `updated` date** in the topic file's frontmatter.
4. **Check remaining graphics AUDIT comments** in the file:
   - If none remain, the graphics audit pass is complete for this file.
5. **Do NOT change topic status** in INDEX.md — graphics resolution does not affect the topic lifecycle.
6. **Present a summary**:
   - What graphic was created and where it was placed
   - Format chosen and why
   - Any TODOs left (e.g., screenshots that need manual capture)

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(graphics): <topic-name> <brief-description>`

## Rules

- Only process ONE AUDIT comment per invocation. If the user targets a file without specifying a line, pick the first `type: graphics` AUDIT in that file.
- Do NOT modify content beyond inserting the graphic reference and removing the AUDIT comment.
- Do NOT invent data. If the AUDIT comment describes quantitative relationships, derive values from the surrounding text. If the text is qualitative ("much faster"), use relative visual sizing rather than fabricated numbers.
- If `research/CLAUDE.md` specifies a graphical language, style guide, color palette, or diagramming convention, follow it. It overrides the defaults in this skill.
- Tables go inline. Everything else becomes an asset file.
- If the `ref` field in the AUDIT comment points to another topic, read that topic for context before generating the graphic.
