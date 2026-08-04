---
name: kickoff
description: >
  Start a trajectory project (or revise its vision): a Socratic interview about users and
  their needs, what success looks like, hard constraints/invariants, and the domain
  vocabulary, wrapped up as VISION.md with an explicit ## Vocabulary section. Trigger on
  "/kickoff", "start a new project", "let's define the vision", "kick this project off", or
  when the user wants to revise an existing VISION.md ("the vision changed", "update the
  vision"). Do NOT trigger for milestone planning (/aim), task capture (/enrich,
  /supplement), or read-only questions about the existing vision.
argument-hint: <optional project idea, or what changed for a revision>
model: opus
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Skill, AskUserQuestion
---

# Kickoff — Vision and Vocabulary

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

The user's argument, if any: `$ARGUMENTS` — the project idea (first run) or what changed (revision). Check whether `VISION.md` exists at the project root: present → **revision mode**, absent → **first run**.

Your job is a shared understanding of why this project exists, captured tight enough that every later skill can check itself against it. The interview is Socratic — but never verbatim topic-quizzing. The topics below are what you must *understand* by the end; reach them through the user's own framing, follow the thread their answers open, and probe where an answer is vague or contradicts an earlier one. One question (or one tight cluster) per turn.

## What you must understand

- **Users and needs** — who are the potential users, what are their needs, and how does the project solve them? Push past roles to situations: when does this person reach for the tool, and what happens if it doesn't exist?
- **Success** — how does success look? Concrete, observable outcomes; if the user offers a metric, ask what change in the world it stands for.
- **Invariants** — hard constraints that must never fail. Distinguish true invariants ("data never leaves the device") from preferences ("should be fast").
- **Vocabulary** — the domain language: the nouns and verbs the user naturally uses, terms they correct you on, distinctions they insist on. Collect these as you go; every correction is a vocabulary entry.

Stop interviewing when new questions stop changing the picture — typically 5–10 exchanges, not an exhaustive questionnaire.

**How to ask** (see [Asking the user](../_shared/workflow-overview.md#asking-the-user)): users-and-needs, success, and why an invariant is absolute are **open discovery** — prose, always. Use `AskUserQuestion` for the closed turns inside the interview: which of the candidate user groups is *primary*, whether a stated constraint is a true invariant or a preference, and — at wrap-up — which foundational decisions to work now (see below). Once the picture is formed, offering 2–4 concrete readings of it as options is often a faster route to a correction than an open prompt.

## Writing VISION.md

Wrap the understanding up as `VISION.md` at the project root:

- Purpose and users (the needs, in the user's framing)
- What success looks like
- **Invariants** — one per line, absolute statements
- `## Vocabulary` — **one line per term**: `- **Term** — definition`. This section is load-bearing: `/enrich` checks every task's names, terms, and acceptance criteria against it, and a prose-only vision is too thin to serve as that referent. Be generous — a term that seems obvious today is a synonym-drift bug next month.

Keep the whole file to roughly a page. Show the draft, incorporate corrections, write it.

## Foundational decisions (first run only)

Foundational decisions — tech stack, persistence, testing approach, everything that predates any milestone — are **not smuggled into the vision**. Close a first run by listing the foundational decisions the conversation surfaced or implied (each as a one-line candidate), and offer to work through them as a first `/decide` batch, so they land in the decision log with the same rigor as every later decision. Pose that offer with `AskUserQuestion` using `multiSelect` — one option per candidate decision — so the user picks which to settle now and which to defer in a single turn. If the user accepts, invoke `Skill(decide)` per item (or point them at `/decide`); if they defer, leave the list in the chat — do not park it in VISION.md.

## Revision mode

With `VISION.md` present, run diff-oriented: read the current file, ask what changed (or start from `$ARGUMENTS`), and interview only around the delta — new user group, shifted success shape, a new or retired invariant, vocabulary drift. Update only the affected sections; never re-interview settled ground from scratch. If a vocabulary term changes meaning, note that `/enrich`-shaped tasks using the old sense may need review, and say which board query finds them (`backlog.sh by-status task todo`).

## Wrap-up

Leave `VISION.md` uncommitted — this skill runs in the foreground, so the user reviews the change and commits it themselves (`/commit`). Close by naming the file written and pointing at the next move: `/aim` for the first milestone (or `/decide` if a foundational batch is pending).
