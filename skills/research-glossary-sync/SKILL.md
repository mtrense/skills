---
name: research-glossary-sync
description: "Reconcile glossary.md against current topic content — add new terms, update changed definitions, remove unused terms. Run after any content-changing phase."
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Edit, Write
---

# Research Glossary Sync

You are synchronizing `research/glossary.md` with the current state of all topic content.

**No arguments required** — this skill scans all topic files.

## Process

### Step 1: Read Everything

1. Read `research/glossary.md`.
2. Read `research/CLAUDE.md` for conventions.
3. Read ALL topic files in `research/content/` (use Glob to find them, then read each).
4. Read `research/INDEX.md` to understand the topic structure.

### Step 2: Extract Terms

Scan all topic content for:
- **Explicitly defined terms**: terms that are introduced with a definition or explanation in the content.
- **Domain-specific jargon**: technical terms, acronyms, or specialized vocabulary that a reader might need defined.
- **Key concepts**: central ideas that are discussed across multiple topics.

Do NOT include:
- Common English words or widely-known programming terms (e.g., "variable", "function", "server").
- Terms only mentioned in passing without significance.

### Step 3: Compare with Existing Glossary

For each term found in content:
- **New term**: not in glossary — add it.
- **Changed definition**: term exists but content uses it differently or more precisely — update the definition.
- **Existing and accurate**: no change needed.

For each term in the glossary:
- **Still used**: keep it.
- **No longer used in any topic**: remove it.

### Step 4: Update Glossary

The glossary is organized by domain area using headings:

```markdown
---
title: "Glossary"
created: <original-date>
updated: <today>
---

# Glossary

## <Domain Area 1>

**term-a**: Definition of term A.

**term-b**: Definition of term B. See [relevant topic](content-path.md#section).

## <Domain Area 2>

**term-c**: Definition of term C.
```

Rules:
- Group terms under domain-area headings (e.g., "## Authentication", "## Data Pipelines").
- Within each group, sort terms alphabetically.
- Definitions should be concise (1-2 sentences).
- Include a reference link if the definition comes from or is best explained in a specific topic section.
- Use `**term**:` format (bold term, colon, space, definition).
- If a term spans multiple domains, place it in the most primary one and cross-reference.

### Step 5: Summary

Present to the user:
- Terms added (with their definitions)
- Terms updated (with old vs. new)
- Terms removed (with reason)
- Any terms where the definition was ambiguous and a judgment call was made

## Git

Do NOT commit. The user will review and use `/commit` when ready.
The expected commit message format: `research(glossary): sync after <phase/topic>`

## Rules

- Do NOT modify any topic files — only `research/glossary.md`.
- Do NOT invent definitions — derive them from how terms are used in the content.
- Update the `updated` date in glossary frontmatter.
- If the glossary file doesn't exist yet, create it with proper frontmatter.
