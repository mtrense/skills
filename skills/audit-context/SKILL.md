---
name: audit-context
description: "Audit the current session context (or a specified set of files) for three classes of context-degrading defect: contradictions, ambiguities, and irrelevance. Produces a structured, line-cited report ranked by severity. Diagnostic only — does not propose fixes. Arguments: optional list of file paths to audit instead of the live session."
argument-hint: "[file-path ...]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Glob, Grep
---

# Audit Context

You are auditing context for defects that degrade Claude's performance. The user runs this skill when they suspect their session context, project instructions, or memory have accumulated friction — and they want a quick diagnostic before deciding what to clean up.

You diagnose. You do not fix. The user (or a future companion skill) decides what to do with your findings.

**Arguments**: `$ARGUMENTS`
- If empty: audit the **current session context** — everything visible to you in this conversation right now (system prompt, CLAUDE.md files, MEMORY.md and any loaded memory files, prior user/assistant turns, tool results still in context).
- If one or more file paths: audit those files instead of the live session. Read each one with the Read tool. Treat the union of their contents as the context-under-audit.

## The three defect classes

### Contradiction (CON)
Two statements in the context that cannot both be true, or two instructions that cannot both be followed. The model has to silently pick one — and may pick the wrong one, or oscillate.

Examples:
- A CLAUDE.md says "always use tabs" while a memory file says "this project uses 2-space indentation."
- The system prompt says "be terse" while a hook reminder says "always end with a detailed summary."
- A spec file says component X is deprecated; a separate doc says X is the recommended approach.

Contradiction is the most damaging defect — flag aggressively even when the conflict is partial.

### Ambiguity (AMB)
A statement that admits multiple plausible readings, where the reading actually matters for behavior. Vagueness that doesn't change what the model would do is not ambiguity — don't flag it.

Examples:
- "Keep responses short" without saying short relative to what (one line? one paragraph?).
- "Use the new API" when more than one API in the codebase could be called "new".
- A rule that triggers "when appropriate" without saying what makes a case appropriate.

Distinguish ambiguity from generality. "Write good code" is general but not ambiguous in a way that drives different behaviors — skip it. "Use the standard format" *is* ambiguous if multiple formats are in use.

### Irrelevance (IRR)
Content that is in the context but provides no signal for the kinds of tasks the user is actually doing in this session. Irrelevance bloats the context window, dilutes attention, and crowds out the parts that matter.

Judging irrelevance requires inferring the session's purpose. Use the user's recent turns and the active working directory as evidence. If a memory file describes a project the user hasn't touched in months and isn't touching now, that's irrelevant *here*. Stale references to systems no longer in use are irrelevant. A 200-line doc on PDF generation loaded into a session about database migrations is irrelevant.

Be conservative. Don't flag general project conventions as irrelevant just because the immediate task doesn't touch them — they're load-bearing across many tasks. Flag content that is dead weight specifically.

## Severity scale

- **C (critical)** — Will almost certainly cause wrong behavior on the next task. A direct contradiction in active instructions; an ambiguity in a rule the model is about to apply.
- **H (high)** — Likely to cause friction or incorrect behavior on common tasks in this session.
- **M (medium)** — Could cause issues on some tasks; worth cleaning up but not urgent.
- **L (low)** — Minor; flag for completeness but the user may reasonably ignore.

When in doubt between two levels, pick the lower one. The user is triaging — over-flagging is more annoying than under-flagging.

## How to do the audit

1. **Determine scope.**
   - No arguments: enumerate what's in your context. Mentally list: the system prompt sections, CLAUDE.md files, MEMORY.md and any expanded memory files, files you've Read in this session, tool results still visible, and the user's prior turns. You don't need to dump this list — just be deliberate about what you're scanning.
   - With arguments: Read each path. If a path doesn't exist or isn't readable, note it in the report under a `READ_ERRORS` section but continue auditing the rest.

2. **Infer session intent** (only when auditing the live session). One short sentence — what is the user doing here? This grounds your irrelevance judgments. Skip when auditing a static file list, since there is no session.

3. **Scan for each defect class.** Make one pass per class, not one pass total — different defects need different attention modes. Contradictions need cross-referencing across sources. Ambiguities are local. Irrelevance needs the inferred intent.

4. **Cite precisely.** Every finding must point to where it lives. For files, use `path:line` or `path:line-line`. For session-only content (system prompt, conversation turns), use a stable label like `system-prompt:<section-name>` or `conversation:<turn-N>:<short-quote>`. The user needs to be able to find what you're talking about.

5. **One finding per line.** Don't merge two findings into one line even if they're related — the user wants to triage them independently.

## Output format

Print exactly this structure. No preamble, no closing remarks beyond what's specified.

```
# Context Audit

Scope: <"current session" or "N file(s)">
Intent: <one sentence; omit this line if auditing a static file list>

## Findings

<file:line> [<file:line> ...] [<CODE>/<SEV>] <one-line description>
<file:line> [<file:line> ...] [<CODE>/<SEV>] <one-line description>
...

## Summary

CON: <count by severity, e.g. "1C 2H 0M 1L">
AMB: <count by severity>
IRR: <count by severity>
```

Where:
- `<CODE>` is `CON`, `AMB`, or `IRR`.
- `<SEV>` is `C`, `H`, `M`, or `L`.
- For contradictions, list **both** locations (or all locations involved) before the bracket.
- For ambiguities and irrelevance, usually one location suffices — but list multiple if the same defect spans them.

Sort findings by severity (C → L), then by code (CON → AMB → IRR), then by file path.

If a defect class has zero findings, still include its summary line with all zeros.

## Examples

```
CLAUDE.md:42 memory/style.md:7 [CON/C] indentation rule disagrees: tabs vs 2-space
README.md:88 [AMB/H] "the standard format" — three formats are documented; unclear which applies
memory/old-project.md:1-120 [IRR/M] notes on a project not referenced in this session
conversation:turn-3:"use the new API" [AMB/M] two APIs labeled "new" in the codebase
```

## What not to do

- Do not edit any files. This skill is read-only.
- Do not propose fixes, rewrites, or recommendations. The output is a diagnosis. A future skill will handle remediation.
- Do not flag stylistic preferences or matters of taste. Flag defects that affect what the model will *do*.
- Do not pad the report. If there are no findings, say so cleanly and exit. A short clean report is a feature.
- Do not speculate about defects you can't cite. If you can't point to it, you don't have a finding.
