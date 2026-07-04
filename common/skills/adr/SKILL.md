---
name: adr
description: >-
  Manually record one or more Architecture Decision Records from the current
  conversation. The human's override for when they see a decision worth
  preserving that no skill recorded on its own — invoked explicitly, it captures
  the decision(s) just made (or discussed) in this session as full ADRs under
  docs/decisions/ using the shared NNNN-title.md + INDEX.md convention.
argument-hint: "[which decision(s) to record — blank to infer from the conversation]"
disable-model-invocation: true
---

# ADR — record a decision from this conversation

The user has decided that something discussed or settled in this session
deserves a durable Architecture Decision Record. The automated skills record
ADRs only when *they* judge a decision architecture-splitting; this skill is
the human override for everything they miss. **The user's invocation is the
worth-recording call — do not second-guess it.** The usual "what not to
record" bar is waived: if they asked for an ADR, they get one.

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
mechanics exactly: find the next number under `docs/decisions/` (create the
directory and seed `INDEX.md` if absent), write
`docs/decisions/NNNN-kebab-title.md` from the template, append the one-sentence
`INDEX.md` line. (Its "What not to record" section does not apply here — see
above.) When recording several decisions, number and write them sequentially in
one pass.

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
- **Deciders** — the user, plus this session (name the skill or workflow that
  was running when the decision was made, if any).
- **Affected documents** — if the decision is already encoded in project docs
  (spec, README, ROADMAP, code), add an `- **Affected documents:**` line to the
  record's header list naming them; the ADR records the *reasoning*, the docs
  remain the source of truth for the *content*.

If the conversation doesn't actually contain enough substance to fill a
section, ask the user the one missing question instead of inventing content.

## Step 3 — Report

Tell the user what was written, one line per record:
`NNNN — <title> → docs/decisions/NNNN-kebab-title.md`. Do not paste the
records back into the conversation.

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
