---
name: adr
description: >-
  Record one or more Architecture Decision Records from the current
  conversation. Trigger whenever the user wants to capture, record, log, or
  write down a decision, an architectural choice, or "the call we just made" —
  e.g. "record this decision", "let's ADR this", "capture this as an ADR",
  "write an ADR for…", "log this architectural decision", or /adr. Also the
  human override for when a decision worth preserving was settled in-session but
  no build skill recorded it on its own. Writes each as a full ADR under the
  architecture home (./architecture/decisions/ by default, overridable via an
  architecture-path: line in CLAUDE.md) using the shared NNNN-title.md +
  decisions.md convention, then refreshes the derived per-topic summaries.
  Grounds every section in what was actually discussed and confirms the list
  before writing; treats the invocation itself as the worth-recording call, so
  do NOT trigger for read-only questions about existing decisions ("what did we
  decide about…", "show me the ADRs") — those are lookups, not new records.
argument-hint: "[which decision(s) to record — blank to infer from the conversation]"
---

# ADR — record a decision from this conversation

## Git identity of the current user

Captured stdout of a shell command run *before* this skill loaded — use it verbatim
as the human decider in the **Deciders** field (Step 2), so the record names who
made the call rather than the anonymous "the user":

```
!`name=$(git config user.name 2>/dev/null); email=$(git config user.email 2>/dev/null); if [ -n "$name" ] && [ -n "$email" ]; then printf '%s <%s>\n' "$name" "$email"; elif [ -n "$name" ]; then printf '%s\n' "$name"; elif [ -n "$email" ]; then printf '%s\n' "$email"; else printf '(git identity not configured — use "the user")\n'; fi`
```

The user has decided that something discussed or settled in this session
deserves a durable Architecture Decision Record. The automated skills record
ADRs only when *they* judge a decision architecture-splitting; this skill is
the human override for everything they miss. **The user's invocation is the
worth-recording call — do not second-guess it.** The usual "what not to
record" bar is waived: if they asked for an ADR, they get one.

## Step 0 — Resolve the architecture home

The architecture home is `./architecture/` by default. If the project's
`CLAUDE.md` (root, or the nearest one governing the working directory) contains a
line of the form `architecture-path: <directory>`, use that directory instead —
resolved relative to the project root. Everywhere below and in
`references/decision-record.md`, `<architecture-home>` means this resolved
directory (`architecture/` unless overridden); records live in
`<architecture-home>/decisions/`, the index in `<architecture-home>/decisions.md`,
and the derived topic summaries in `<architecture-home>/<topic>.md`.

## Step 1 — Identify the decision(s)

Look at `$ARGUMENTS` first: if the user named the decision(s), that's the list.

If blank, scan the current conversation for the decision(s) they most plausibly
mean — typically the one(s) just settled: a choice made between alternatives, a
constraint accepted, a direction committed to. Recent and concrete beats old
and vague.

Then **confirm before writing**:

- If exactly one candidate stands out, state it in one sentence ("Recording:
  *<decision>* — right?") and proceed only on confirmation, unless the user's
  invocation already named it unambiguously — then just proceed.
- If several candidates qualify, list them one line each and ask which to
  record (possibly all). Use `AskUserQuestion` with `multiSelect` when the
  candidates are a clean closed set.

## Step 2 — Write each record

Read `references/decision-record.md` (in this skill directory) and follow its
mechanics exactly: find the next number under `<architecture-home>/decisions/`
(create the directory and seed `<architecture-home>/decisions.md` if absent),
write `<architecture-home>/decisions/NNNN-kebab-title.md` from the template,
append the one-sentence `decisions.md` line. (Its "What not to record" section
does not apply here — see above.) When recording several decisions, number and
write them sequentially in one pass.

Ground every section in what actually happened in this conversation:

- **Context** — the problem or tension as it actually arose here, not a
  reconstructed idealization.
- **Decision** — what was settled, stated as the new source of truth, concrete
  and testable.
- **Rationale** — the reasoning actually given in the conversation.
- **Alternatives considered** — only alternatives that were *genuinely* raised,
  weighed, or rejected in this session (or that the user explicitly asks to
  include). If none were, write "None seriously considered — <one line on why
  the choice was direct>" rather than fabricating a comparison. A padded
  alternatives section is worse than a short honest one.
- **Deciders** — the human decider from the "Git identity of the current user"
  block above (the `Name <email>` string; fall back to "the user" only if it
  reported no identity), plus this session (name the skill or workflow that was
  running when the decision was made, if any).
- **Affected documents** — if the decision is already encoded in project docs
  (spec, README, ROADMAP, code), add an `- **Affected documents:**` line to the
  record's header list naming them; the ADR records the *reasoning*, the docs
  remain the source of truth for the *content*.
- **Scope** — if the decision is bound to a specific artifact (frontend / backend
  / mobile / CLI / service), environment (production / testing / dev), or bounded
  context, name that binding in the `Scope:` field. This is what lets the derived
  topic summary file the guideline under the right heading instead of presenting a
  scoped rule as project-wide.

If the conversation doesn't actually contain enough substance to fill a
section, ask the user the one missing question instead of inventing content.

## Step 2b — Refresh the derived summaries

Once every record and its index line are written, bring the derived per-topic
summaries back in sync. Spawn the **architecture-summarizer** subagent
(`subagent_type: architecture-summarizer`) with the architecture home
(`<architecture-home>`) and the ADR number(s) you just recorded. It maps each ADR
to its topic(s) and rewrites the affected `<architecture-home>/<topic>.md`
guideline files — you do not edit the summaries yourself. Capture its report of
which summary files it touched for Step 3.

## Step 3 — Report

Tell the user what was written, one line per record:
`NNNN — <title> → <architecture-home>/decisions/NNNN-kebab-title.md`, then one
line listing the `<architecture-home>/<topic>.md` summaries the summarizer
refreshed. Do not paste the records back into the conversation.

Do **not** commit — the user invokes `/commit` when ready.

## What not to do

- **Don't refuse or debate whether the decision "deserves" an ADR.** That call
  was made by invoking this skill.
- **Don't fabricate context, rationale, or alternatives** the conversation
  doesn't support — short and honest beats complete and invented.
- **Don't edit the project docs.** This skill only writes the record and its
  index line; if the docs also need updating, say so and let the user drive it.
- **Don't batch silently.** When inferring multiple decisions, confirm the list
  before writing anything.
