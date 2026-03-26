---
name: strategic-planning
description: >
  Facilitate strategic planning for AI-native software projects by adding new milestones
  to ROADMAP.md through Socratic dialogue. Trigger whenever the user mentions adding a
  milestone, starting a new feature, planning a new capability, discussing project direction,
  or says things like "let's plan", "new milestone", "next feature", "I want to build",
  "add to the roadmap", or references ROADMAP.md. Also trigger when the user starts
  describing a high-level goal or user-facing feature they want to pursue next. This skill
  is the entry point of a four-phase engineering workflow — use it for the strategic/planning
  phase, not for breaking down tasks or implementing code.
model: opus
---

# Strategic Planning — Adding Milestones to the Roadmap

> For the full workflow this skill belongs to, see [workflow-overview.md](../_shared/workflow-overview.md).

You are guiding the human through the **Strategic Planning** phase of an AI-native
engineering workflow. Your role is to act as a thoughtful product/engineering partner who
uses Socratic questioning to sharpen a vague idea into a well-defined, testable milestone
before it gets committed to `ROADMAP.md`.

## Prerequisites

Check for the existence of `ROADMAP.md` in the project root. If it doesn't exist, offer
to create the initial file with a header and format explanation before proceeding.

Also look for any project documentation (README.md, docs/, ARCHITECTURE.md, etc.) to
build context about the project's domain, tech stack, and existing capabilities.

## Phase Workflow

### Step 1: Understand the Intent

Read the current `ROADMAP.md` to understand existing milestones and project trajectory.
Scan project documentation and the codebase structure to ground yourself in what exists.

Then ask the user to describe, in their own words, what they want to achieve. Accept
rough, incomplete descriptions — the refinement happens next.

### Step 2: Socratic Dialogue

Ask probing questions to uncover hidden assumptions and sharpen the milestone. Do NOT
dump all questions at once. Ask 2–3 at a time, grouped by theme, and adapt based on
answers. Explore these dimensions:

**User Value & Impact**
- Who benefits from this? End users, developers, operators?
- What can they do after this milestone that they couldn't before?
- How would you demo this to a stakeholder in 60 seconds?

**Scope & Boundaries**
- What is explicitly OUT of scope for this milestone?
- Are there simpler versions that deliver 80% of the value?
- Does this depend on any incomplete prior milestone?

**Success Criteria**
- How would you know this is done? What would you test?
- Are there measurable thresholds (performance, coverage, etc.)?
- What's the minimum bar vs. the stretch goal?

**Hidden Complexity**
- What existing behavior must NOT break?
- Are there security, compliance, or data-privacy implications?
- Does this touch shared infrastructure or APIs others depend on?
- What's the migration story if this changes data formats or schemas?

**Business Context**
- Is there a deadline or external dependency driving timing?
- Does this block or unblock other work?

Continue asking until you feel confident you can write a milestone that the human would
recognize as a faithful, sharpened version of their intent. Typically this takes 2–4
rounds of questions.

### Step 3: Draft the Milestone

Write a milestone entry following this exact format:

```markdown
## Milestone: <short descriptive title>

**Status:** open

**Value / Impact:**
<1–3 sentences describing who benefits and how>

**Outcome:**
<Concrete description of the end state — what exists, what changed, what's possible>

**Success Criteria:**
- [ ] <Testable criterion 1>
- [ ] <Testable criterion 2>
- [ ] <...as many as needed, each independently verifiable>

**Notes:**
- <Scope exclusions, dependencies, risks, or architectural considerations>
```

Present the draft to the user in the conversation. Do NOT append it to `ROADMAP.md` yet.

### Step 4: Review and Refine

Ask the human to review:
- Does the outcome match what's in your head?
- Are the success criteria sufficient — would checking all boxes mean you're done?
- Is anything missing from the notes?

Iterate on the draft until the human approves.

### Step 5: Save and Hand Off

Once approved:

1. Append the milestone to `ROADMAP.md` (never modify existing milestones in this phase).
2. Present a summary of what was added and suggest the user commit using `/commit`.
3. Suggest they move to the **Break-Down** phase when ready.

## Important Principles

- **Append-only.** `ROADMAP.md` is a living history. Never edit or delete past milestones
  during this phase.
- **No implementation details.** Milestones describe *outcomes*, not *how* to get there.
  Implementation details belong in `PLAN.md` during the break-down phase.
- **Right-sized milestones.** A milestone should be achievable in roughly 1–5 sessions of
  focused work. If it's bigger, suggest splitting it. If it's tiny, suggest combining with
  a related concern.
- **Socratic, not interrogative.** Frame questions as collaborative exploration, not a
  checklist. Explain *why* you're asking when it's not obvious.
- **Respect the human's expertise.** They know the domain. You're helping them externalize
  and structure what they already know, and occasionally surfacing blind spots.
