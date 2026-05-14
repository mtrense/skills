# Skill Family: Spec-Native

A family of skills for producing and maintaining living specifications with Claude Code, designed for projects operating at **spec-anchored (Tier 2)** or **spec-as-source (Tier 3)** maturity:

- **Tier 1 — Spec-First**: spec is written first, then discarded after code generation. Appropriate for one-off generation; the cost is paid during maintenance, when the discarded spec can no longer anchor agent context.
- **Tier 2 — Spec-Anchored**: spec is a living, version-controlled artifact. Agents use it as a permanent anchor for all future refactoring.
- **Tier 3 — Spec-as-Source**: humans never edit code. The specification is the literal source code; the LLM acts as the compiler.

The three tiers are not a strict maturity ladder where higher is always better — the right tier depends on team size, change velocity, regulatory needs, and the half-life of the code being produced. But realizing the full productivity gain from coding with AI requires fluency in **all three**: knowing when a throwaway script earns Tier 1's speed, when a long-lived system needs Tier 2's anchor, and when a tightly-scoped domain rewards Tier 3's compile-from-spec discipline. This skill family targets Tier 2 and Tier 3 because that is where tooling support is most load-bearing; Tier 1 needs no skills at all.

The Tier 1/2/3 framing is original to this workflow. Adjacent ideas — "spec-driven development," Kiro's spec-then-implement loop, GitHub Spec Kit, Anthropic's writing on agent context engineering — informed it but do not use the same three-rung division.

The workflow operates entirely on markdown files with structured frontmatter and an inline marker grammar. Structure is deliberately machine-friendly so deterministic scripts can build dependency graphs, coverage matrices, certainty reports, and topological orderings on top of the spec without an LLM in the loop.

---

> **Status: Design draft.** This document captures structural decisions (file zoo, ID scheme, marker grammar, frontmatter shapes). The skill list is sketched but not specified — Socratic question banks, audit failure-mode boundaries, lifecycle/deprecation, and Tier 3 compile/trace skills are explicitly open.
>
> **Out of scope for v1: brownfield onboarding.** The first version assumes a greenfield project — `/spec-inception` is the entry point. Reverse-engineering a spec from an existing codebase (extracting behaviors from tests, route handlers, controllers; proposing capability boundaries from module structure; back-filling `// SPEC:` annotations) is a substantial design effort on its own and is deferred. Projects that already have code can hand-author or use `/spec-add-*` skills incrementally; a dedicated `/spec-extract` (or extract → review → annotate phase) will be designed once the greenfield workflow is proven.

---

## Specification Structure

The spec is organized along **two axes**:

**Behavioral hierarchy** (a tree):

```
capability  →  scenario  →  behavior
   (dir)        (file)      (heading)
```

- **Capability** — one coherent outcome the system delivers. The boundary rule is *outcome cohesion*: a capability is the smallest grouping of scenarios where removing any one weakens the rest. A single primary actor is the common case (and the cheapest smell test for bloat), but genuinely collaborative flows may list secondary actors explicitly. A structural lint (size budget + cohesion check) backs the rule when authorial judgment drifts: warn at **>8 scenarios per capability** (advisory only — no hard ceiling, since some capabilities legitimately span more), and flag any scenario reachable only by an actor outside the capability's `actor` / `secondary_actors` list as a cohesion smell.
- **Scenario** — a specific situation, flow, or case within a capability.
- **Behavior** — the atomic unit of specification: `trigger + system response + observable evidence` (externally-detectable signals that distinguish success from failure; see *Scenario file* for shape).

**Parallel layers** (not in the tree, referenced by it):

- **Actors** — the catalog of actor types the system serves, one file per actor under `actors/`. Each file describes who the actor is, what they want, and what authority they hold. Capability and scenario `actor` / `secondary_actors` frontmatter values resolve against this catalog; a deterministic lint flags unknown values. The single-primary-actor expectation under *Specification Structure* points here for its enum.
- **Journeys** — ordered compositions of scenarios across capabilities (e.g. "user signs up and immediately makes a purchase"). Necessary because real user journeys are not orthogonal to capabilities.
- **Domain model** — entities, state machines, and invariants. DDD-aligned: only **aggregates** and named domain services get referenceable IDs; **value objects** are described inline within their owning aggregate.
- **NFRs** — measurable cross-cutting properties (latency, error rate, throughput, availability, accessibility level, extensibility surface, error-recovery time, operability/MTTR, observability coverage, security posture). **Prohibitions phrased as measurable absence** belong here (e.g. "passwords never appear in logs" — measurable by log scan; threshold: zero occurrences).
- **Constraints** — non-measurable external requirements (regulatory, contractual, compatibility). **Prohibitions sourced from an external authority** belong here (e.g. "must not store EU PII outside the EU" — sourced from GDPR, verification is procedural rather than metric-based).
- **Invariants** (cross-aggregate, optional) — invariants spanning multiple aggregates that don't belong to any single one. Single-aggregate invariants live inside the domain model file.

## ID Scheme

Every ID has the same shape: **`[PREFIX:][<path>][#<anchor>]`**, where at least one of `<path>` and `<anchor>` is present. The path is the file path under the prefix's container directory (without `.md`); the anchor, when present, is a heading slug inside that file. `#` always means *anchor within the file* — nothing else. The prefix determines the container; for singleton-file layers the path is omitted and the anchor-only form is used.

**Behavioral hierarchy** is unprefixed (it's the default kind):

```
auth                            ← capability      (capabilities/auth.md)
auth/login                      ← scenario        (capabilities/auth/login.md)
auth/login#invalid-password     ← behavior        (### invalid-password heading)
```

**Cross-cutting layers** carry a prefix:

```
DM:order                        ← domain model entity
DM:order#amount-positive        ← invariant on entity
NFR:api                         ← NFR group
NFR:api#p95-latency             ← single NFR within the group
CON:gdpr#data-deletion
INV:checkout-atomicity          ← cross-aggregate invariant (used only when needed)
JRN:first-purchase              ← journey
A:customer                      ← actor type            (actors/customer.md)
G:#idempotency                  ← glossary term         (heading in glossary.md)
```

### Per-prefix resolution

Each prefix has a fixed container and a fixed form (path-based for directories, anchor-only for singleton files). Deterministic tooling consults this table:

| Prefix   | Container        | Form           | Example                       |
|----------|------------------|----------------|-------------------------------|
| (none)   | `capabilities/`  | `path[#anchor]`| `auth/login#invalid-password` |
| `A:`     | `actors/`        | `path`         | `A:customer`                  |
| `DM:`    | `models/`        | `path[#anchor]`| `DM:order#amount-positive`    |
| `NFR:`   | `nfr/`           | `path[#anchor]`| `NFR:api#p95-latency`         |
| `CON:`   | `constraints/`   | `path[#anchor]`| `CON:gdpr#data-deletion`      |
| `INV:`   | `invariants/`    | `path`         | `INV:checkout-atomicity`      |
| `JRN:`   | `journeys/`      | `path`         | `JRN:first-purchase`          |
| `G:`     | `glossary.md`    | `#anchor`      | `G:#idempotency`              |

The path form is "literal path under the container directory"; the anchor-only form is "heading inside the singleton file." A prefix supports one or the other, not both — picking a form per prefix is a deliberate one-time decision, not a per-ID choice.

### Strict tree, deeper paths if needed

Sub-scenarios — if ever needed — go in **deeper directories**, not nested headings: `capabilities/auth/login/with-2fa.md` yields the scenario ID `auth/login/with-2fa` and behaviors `auth/login/with-2fa#invalid-password`. The rule "one file = one scenario, leaf heading = behavior" stays intact; ID grammar does not have to encode hierarchy depth.

### File path provides parent ID

The full ID of any element is reconstructed by tooling as `<path>` (file-level) or `<path>#<heading-slug>` (heading-level). Headings carry only the **local name**, never the parent path. This means restructuring a file does not require sweep-rewriting headings inside it.

```markdown
# capabilities/auth/login.md
### invalid-password            ← full ID: auth/login#invalid-password
```

```markdown
# models/order.md
### amount-positive             ← full ID: DM:order#amount-positive
```

### Naming discipline

Enforced by deterministic scripts where possible:

- lowercase kebab-case, no special characters
- descriptive (`wrong-password`, not `case-2`)
- non-redundant with parent (`fails`, not `login-fails`)
- max segment length (~30 chars) for readability

### Restructuring cost is accepted

Path-derived IDs are not truly stable. When a capability is split, merged, promoted, or demoted, every reference (in other spec files, in code annotations, in tests) must be sweep-rewritten. The dedicated `/spec-restructure` skill is responsible for this; git provides the audit trail. This is a deliberate trade for human-readable IDs over opaque ones.

## Project Layout

Everything lives under a `spec/` directory so it can coexist with other workflows:

```
/
├── CLAUDE.md
├── spec/
│   ├── SPEC.md                              ← top-level index (auto-generatable)
│   ├── glossary.md
│   ├── DECISIONS.md
│   ├── actors/                              ← actor type catalog, one file per actor
│   │   ├── customer.md
│   │   └── admin.md
│   ├── capabilities/
│   │   ├── auth.md                          ← capability index
│   │   ├── auth/                            ← scenarios under it
│   │   │   ├── login.md
│   │   │   ├── logout.md
│   │   │   └── password-reset.md
│   │   └── checkout.md
│   ├── journeys/
│   │   └── first-purchase.md
│   ├── models/
│   │   ├── order.md
│   │   └── user.md
│   ├── nfr/
│   │   └── api.md
│   ├── constraints/
│   │   └── gdpr.md
│   └── invariants/                          ← cross-aggregate only; rare
│       └── checkout-atomicity.md
├── src/
└── ...
```

A capability starts as a single `capabilities/<name>.md` index file. Once it gains scenarios, scenarios go in a sibling `capabilities/<name>/` directory. The index file remains as the capability's overview.

## File Formats

### Frontmatter conventions

Every spec file carries frontmatter with:

- `id` — the element's stable ID (path-derived, but explicit so tooling doesn't have to reverse-engineer paths).
- `references` — list of cross-cutting IDs this element depends on (NFRs, constraints, model entities). Optional free-form comment per entry: `- DM:user (must be active)`.
- `last_audit` — per-axis timestamps for the audit axes that apply to this file type, so audit skills can target stale areas first. `null` means never audited. The full axis set is `consistency`, `coverage`, `quality`, `coherence`, `ambiguity`, `testability`, `traceability`; each file type declares which subset it carries (e.g. journey files omit `traceability`; pure-prose files omit `testability`). The applicable subset per file type is fixed by the schema and enforced by a deterministic lint — files don't carry axes that will never be populated. Trade-off: this keeps frontmatter lean and signals "N/A vs. never audited" structurally, but the schema must be updated (and files migrated) when an axis is added, removed, or reassigned to a different file type. The alternative considered — a project-level `spec/.audit-state.yaml` sidecar — was rejected because per-file git-traceability of audit state is more valuable than the YAML savings.

Capability and scenario files add two behavioral fields:

- `actor` — the primary actor type the element serves, as a bare slug (`customer`) resolved by tooling against the actor catalog (`A:<slug>`). Required at capability level; inherited by scenarios unless overridden. Capabilities with genuinely collaborative flows may add `secondary_actors` (list), resolved the same way; their presence is descriptive metadata, not a boundary violation. A deterministic lint flags any value that doesn't match a catalog entry. Actor is no longer the boundary rule itself — see *outcome cohesion* under Specification Structure — but the single-actor case remains the expected default and a useful bloat smell test.
- `preconditions` — list of state requirements (typically references to domain model entities with a state qualifier). Distinct from `references`: `preconditions` implies "this state must hold before the element applies"; `references` implies "this element is defined in terms of that one". The same target can appear in both.

Other file types add their own fields (see the per-type sections below).

### Capability index (ex. `capabilities/auth.md`)

Full example: [`_examples/capability-auth.md`](_examples/capability-auth.md) (the `_examples/` directory is part of *this* skill family's documentation, sibling to this README — it is not part of the spec project layout produced for users). The capability frontmatter carries `value` (one-line statement of what the capability delivers), `actor`, `scenarios` (ordered list of scenario IDs), `preconditions`, and `references`, in addition to the universal fields. The body has an `Out of scope` section and an ordered prose listing of scenarios.

Two non-obvious choices:

- **Frontmatter is authoritative; prose listings are a deterministic render of it.** The `scenarios` list in frontmatter is the single source of truth — its order is the order shown to humans. The prose `## Scenarios` section is generated (or regenerated) from frontmatter by a deterministic script; humans edit frontmatter to reorder or regroup, never the prose list directly. Free-form prose *between* generated blocks (framing paragraphs, group headings) is human-authored and preserved across regeneration via stable comment fences (`<!-- scenarios:begin -->` / `<!-- scenarios:end -->`). The same rule applies to `references` (frontmatter list authoritative; inline citations are links into spec elements, not a parallel list). This eliminates the "two sources of truth" failure mode by construction — drift is mechanically impossible, not audited after the fact. `/spec-inception` and every `/spec-add-*` skill must produce files that conform.
- **"Out of scope" is a first-class required section.** Specs lie about coverage when scope is implicit; forcing this section catches the "we didn't think about X" failure mode at audit time.

### Scenario file (ex. `capabilities/auth/login.md`)

Full example: [`_examples/scenario-login.md`](_examples/scenario-login.md). It demonstrates frontmatter (id, capability, actor, preconditions, references, last_audit), two behaviors with the fixed shape, and inline AUDIT / CERTAINTY markers.

Behaviors have a **fixed shape**: `Trigger` / `System response` / `Evidence` / `References`. Missing parts are filled with `<!-- POSTPONED: ... -->` so the structure remains parseable. There is no behavior-level frontmatter — too noisy.

**What `Evidence` contains.** Evidence describes *signals falsifiable from outside the unit-under-test* — i.e. detectable without reaching into the unit's internals — that distinguish "behavior happened correctly" from "behavior didn't happen". Concretely: HTTP status + response shape, emitted events/log lines with key fields, state transitions visible via the public API, persisted state queryable by other components (e.g. a row in a shared table, the modeled state of a `DM:` aggregate), user-visible UI changes, or measurable outcomes (counter incremented, mail sent). The "outside" boundary is the unit being specified — for a scenario at capability scope, the database is fair game; for a behavior scoped to a single function, it usually isn't. Evidence is **prose, not a test reference** — tests verify evidence; they are not it. The link between behavior and verifying test is carried by `// SPEC:` annotations on tests (see *Code-side annotations*), not by embedding test IDs in the spec.

Good evidence is *concrete and falsifiable*: "returns 401 with `error.code = invalid_credentials`; no `Set-Cookie` header; `auth.login.failed` event emitted with `reason: invalid_password`". Vague evidence ("user sees an error") is a `/spec-audit-testability` finding.

When evidence cannot yet be specified — e.g. the response shape isn't designed — use `<!-- POSTPONED: response shape pending API design -->` so the slot stays parseable.

### Domain model entity (`models/order.md`)

Full example: [`_examples/model-order.md`](_examples/model-order.md). It demonstrates the aggregate frontmatter (`state_machine`, `invariants`), an attributes table, a nested-list state machine, three invariants with `Statement` / `Rationale` / `Enforced at`, and two examples (generic + edge case).

Every file under `models/` is a DDD aggregate. Value objects are described inline within their owning aggregate (no own file, no own ID). Named domain services, if needed, also live under `models/` and receive `DM:` IDs — their shape will be pinned once a real one shows up.

Notes on the format:

- **State machines are nested lists**, not ASCII art or mermaid. A 5-line regex parses them into a graph structure.
- **Invariant headings carry only the local name** (`amount-positive`); full ID is `DM:order#amount-positive`.
- **Examples belong with the model**, not in test fixtures, when they are *generic and demonstrate invariants*. Test fixtures with specific user data sit at the implementation border and live elsewhere.

### Journey, NFR, constraint, cross-aggregate invariant — sketch

The remaining four file types are simpler:

- **`actors/<slug>.md`** — one file per actor type, each carrying a one-paragraph description (who they are, what they want, what authority they hold). IDs are `A:<slug>`.
- **`journeys/first-purchase.md`** — frontmatter lists ordered scenario IDs; body explains why this composition matters; no new behaviors, just composition + intent.
- **`nfr/api.md`** — grouped measurable properties, each as a heading: `### p95-latency` (full ID `NFR:api#p95-latency`). Each has Statement / Measurement / Threshold / Rationale. Prohibitions whose absence is measurable live here — e.g. `### no-password-in-logs` with Measurement "grep of structured log stream over rolling 7 days" and Threshold "zero matches".
- **`constraints/gdpr.md`** — same shape as NFR but for non-measurable external constraints. Each has Statement / Source / Verification. Prohibitions whose justification is external authority live here — e.g. `### no-pii-export` with Source "GDPR Art. 44" and Verification "data-flow review at PR time".
- **`invariants/<name>.md`** — used only for invariants that span multiple aggregates. Single-aggregate invariants stay in the domain model file.
- **`SPEC.md`** at root — like research's `INDEX.md`: structural overview of the project. Auto-generatable from frontmatter; humans edit only the framing prose.
- **`glossary.md`** — flat file, one `### <slug>` heading per term, each carrying a short definition. IDs are `G:#<slug>` (anchor-only form; the glossary is a singleton file). Spec prose references terms inline as `G:#<slug>` — the same ID grammar used for every other cross-cutting reference, so frontmatter `references`, the reverse-trace tool, and `/spec-restructure` treat glossary entries uniformly with NFRs, constraints, and DM entities. Authoring discipline: italicize a term-of-art on first use per file and tag it with its `G:#<slug>` reference; subsequent mentions in the same file are bare. `/spec-glossary-sync` enforces three things: (a) every italicized first-use resolves to a `G:` entry (or proposes adding one), (b) every `G:` entry is referenced from ≥1 spec file (orphans flagged), (c) terms used heavily without italic-tag on first use get an AUDIT under `ambiguity`.

Full shapes will be added once skills are designed.

### DECISIONS.md

Chronological, append-mostly log of decisions that shape the spec but are not visible from the spec text alone: scope choices (what's in/out, rejected scenarios), NFR/model trade-offs, restructure events (capability splits/merges/promotes/demotes recorded by `/spec-restructure`), contradiction resolutions (when two stakeholder inputs disagreed and one was adopted), and deprecations.

- **Scope: one global file by default.** `spec/DECISIONS.md` is the canonical log. Most decisions cross capabilities (an NFR trade-off affects multiple flows), and a single chronological log is easier to audit and search. Per-capability escalation (`spec/capabilities/<name>/DECISIONS.md`) is allowed when a capability accumulates >~20 entries scoped exclusively to it; `/spec-restructure` is the natural place to detect and perform the split. The global file then keeps cross-capability decisions only. Finer granularity (per-NFR, per-model) is not allowed — it fragments the log past usefulness.
- **Lifecycle.** Created by `/spec-inception`. Appended-to by `/spec-restructure`, `/spec-refine`, the `/spec-add-*` family (when a non-obvious trade-off is decided during authoring), and `/spec-deprecate`. Never rewritten — superseded entries get a follow-up entry referencing the old one via `supersedes:`. Read by every `/spec-audit-*` skill so already-deliberated trade-offs aren't re-flagged. Read by `/spec-derive-instructions` only for `kind: rule` entries — those get lifted into `CLAUDE.md` the same way `kind: rule` findings do from the codebase-survey assessment.
- **Entry schema.**
  ```yaml
  - id: dec-0042
    date: 2026-05-14
    kind: trade-off              # trade-off | scope | restructure | contradiction | deprecation | rule
    scope: capabilities/auth     # or "global"
    affects: [NFR:api#p95-latency, B:auth/login#valid-credentials]
    supersedes: dec-0017         # optional
    summary: "Accept 800ms p95 on login to avoid pre-warming infra."
    rationale: |
      ...
    source: "/spec-inquiry session 2026-05-14, stakeholder: payments-team"
  ```
- **Contradiction-handling policy** (mirrors the research workflow): when stakeholder inputs disagree, both positions are summarized in the relevant spec element, a DECISIONS entry (`kind: contradiction`) records which was adopted and why, and an `<!-- AUDIT: consistency ... -->` marker is inserted at the spec element so `/spec-audit-consistency` can verify the resolution still holds.

### Marker grammar

Three inline HTML-comment markers, parseable by deterministic tooling:

```
<!-- AUDIT:     <axis> — <finding>. severity: <low|medium|high> -->
<!-- CERTAINTY: <low|medium|high> — <reason> -->
<!-- POSTPONED: <what is missing and why> -->
```

- **AUDIT** — placed by audit skills, resolved by `/spec-refine`. `<axis>` is one of the seven: `consistency`, `coverage`, `quality`, `coherence`, `ambiguity`, `testability`, `traceability`. One axis per audit skill (see Skill Family).
- **CERTAINTY** — placed by authoring skills (or by hand) to flag the author's own confidence in a claim: a behavior, evidence statement, or NFR threshold the author committed to but isn't sure of. The `<reason>` should name *why* certainty is below `high` (e.g. "assumed from existing code", "needs product review", "regulation unread"). Audit skills prioritize CERTAINTY-marked content for verification. When external resolution is required (interviews, regulations, market data), hand off to the research workflow — its `CONFIDENCE` marker covers *source verifiability against the web*, which is a different epistemic axis.
- **POSTPONED** — placed when a fixed-structure field (e.g. behavior `Evidence`) cannot yet be filled. Distinct from AUDIT in that it's an author-acknowledged gap, not an audit finding.

POSTPONED and AUDIT both mark unfilled or unsatisfactory content, but differ operationally:

- **Origin.** POSTPONED is placed by an authoring skill (or hand-written) at the moment the gap is created, with the author's reason embedded. AUDIT is placed by an audit skill after the fact, against content the author considered complete.
- **Audit treatment.** Each audit skill ignores POSTPONED *within its own axis* — the gap is already acknowledged, so re-flagging is noise. POSTPONED does **not** exempt the field from other axes: a POSTPONED `Evidence` is silent to `coverage` but a `traceability` audit may still flag it if downstream code claims to implement the behavior. Coverage audits surface POSTPONED separately as a "known-gaps" tally rather than as findings, so the dashboard distinguishes *unknown unknowns* (AUDIT) from *known unknowns* (POSTPONED).
- **Lifecycle.** AUDIT is resolved by `/spec-refine`, which edits the surrounding content and removes the marker. POSTPONED is resolved by filling the field — typically via the same authoring skill that created it, or by a thin `/spec-resolve-postponed` pass — converting to a normal field with no audit footprint.
- **Certainty debt.** POSTPONED does **not** count toward certainty debt (it's structural, not epistemic). CERTAINTY markers do. AUDIT findings count weighted by severity.

### Code-side annotations

For Tier 2 (and the foundation for Tier 3), code references the spec via a single-line comment using the host language's native comment syntax:

```
// SPEC: <id>[, <id>...]   [-- <optional note>]
```

Examples in different languages:

```python
# SPEC: auth/login#invalid-password
def reject_login(user, attempt):
    ...
```

```typescript
// SPEC: auth/login#valid-credentials, NFR:api#p95-latency
function issueSession(user) { ... }
```

```rust
// SPEC: DM:order#amount-positive -- enforced on every line-item mutation
fn recalc_total(order: &mut Order) { ... }
```

#### Rules

- **Comment style follows the language.** `//`, `#`, `--`, `;`, `/* ... */` all valid; the `SPEC:` token is what tooling matches on, not the comment delimiter.
- **One annotation, one or more IDs.** Comma-separated. Use multiple IDs when a single code unit implements multiple behaviors or honors an NFR/constraint alongside a behavior. Prefer splitting code rather than annotating with more than ~3 IDs.
- **Stacked annotations are allowed.** Multiple consecutive `// SPEC:` lines directly above the same code unit are treated as a union — equivalent to a single comma-separated annotation. Use stacking when the IDs warrant per-line notes (`// SPEC: <id> -- <note>`) that would otherwise collide; use the comma-separated form when no per-ID notes are needed. Tooling parses both identically. The ~3-ID guideline applies to the combined set, not per line.
- **Placement: directly above the code unit that implements the element.** Functions, methods, classes, test cases, or — when finer granularity is needed — the specific branch (`if`, `match` arm, `catch`) that realizes the behavior. No blank line between annotation and code.
- **One element may have many annotations across the codebase**; one annotation refers to ≥1 spec element. The relation is many-to-many.
- **Tests count.** A test annotated `// SPEC: auth/login#invalid-password` is the canonical evidence that the behavior is verified; the traceability audit treats test annotations distinctly from production-code annotations. Evidence in the spec describes *what* is observable; a `SPEC:`-annotated test is *how* that evidence is checked.
- **Table-driven and property-based tests.** When one test function covers many distinct behaviors (table-driven cases in Go, parametrized tests in Python, property tests in Rust), annotate at the row/case level if each row maps to a distinct spec element; otherwise annotate the function with a comma-separated list of every ID it exercises. A property test that fuzzes a single invariant annotates the function with that one ID.
- **Free-form note after `--`** is preserved by tooling but not parsed structurally — useful for "partial implementation", "see also X", etc. The separator is the literal two-character `--`; em-dash (`—`) is not accepted, since most keyboards don't produce it and accepting both forms would force every tooling regex to handle the alternation.
- **Renames are mechanical.** `/spec-restructure` rewrites every `SPEC:` annotation in the codebase when an ID changes. The same regex that finds annotations for the reverse-trace tool drives the rewrite.

What annotations are *not*:

- Not a substitute for tests. They declare intent; tests verify it.
- Not nested or hierarchical. An annotation on a function does not implicitly cover its callees — each unit annotates its own coverage.

## Tooling Implications

Structured frontmatter + the marker grammar make the spec a graph database. Deterministic scripts (no LLM needed) can produce:

- **Dependency / topological order** across capabilities and domain entities.
- **Certainty-debt report** — every CERTAINTY marker, ranked by severity and age.
- **Coverage matrix** — which NFRs are referenced by ≥1 behavior; which DM entities are touched by ≥1 scenario; orphans flagged.
- **Staleness ranking** — each `last_audit.<axis>` timestamp, sorted oldest-first to feed audit skills.
- **Reverse trace** — for a given `// SPEC: auth/login#invalid-password` annotation in code, find the spec element and verify it still exists.
- **Restructure sweep** — when an ID is renamed, find every occurrence across spec, code, and tests.

For Tier 3, this graph is the substrate that makes "spec → code" feasible at all.

### Deterministic scripts vs. skills

The list above describes capabilities, not invocation surfaces. Several user-facing tools that *look* like skills are in fact pure scripts and should ship that way — invoked directly, by skills via `Bash`, by pre-commit hooks, or by CI:

- **`spec-validate`** — all syntactic lints in one entry point: ID prefix-table resolution, kebab-case naming, frontmatter required-key presence, `last_audit` axis-subset conformance per file type, marker grammar, glossary `G:#<slug>` anchor resolvability, actor catalog membership. No LLM judgment; a parser plus the prefix table is sufficient.
- **`spec-report`** (a.k.a. certainty-debt / audit-debt report) — walks `last_audit.*` and tallies/sorts `CERTAINTY`, `AUDIT`, and `POSTPONED` markers. Pure aggregation.
- **`spec-deprecate-check <id>`** — the safety half of the deprecation flow: verify no remaining references in spec or in code-side `// SPEC:` annotations, then emit a structured report. The judgment half (what supersedes the element, how to migrate live references) is an LLM skill that consumes this report.

These ship under `spec/scripts/` in the skill family and are surfaced as both standalone CLI commands and pre-commit/CI hooks. Skills must shell out to them rather than reimplement the parsing — keeping one parser canonical avoids drift between "what the lint says" and "what the audit skill assumes". A wrapping skill is added only when the user-facing surface needs Socratic refinement on top of the script's output (the deprecation flow above is the prototypical case).

## Skill Family (sketch — not yet specified)

The skills below are the intended phasing; their detailed designs are open.

**Bootstrap**
- `/spec-inception` — Socratic dialogue establishing scope, actors, top-level capabilities; produces directory structure, `SPEC.md`, `glossary.md`, `DECISIONS.md`, and stubs.

**Authoring** — Socratic challenge baked into entry. Each `add-*` skill asks targeted questions before writing.
- `/spec-add-capability`
- `/spec-add-scenario`
- `/spec-add-behavior`
- `/spec-add-journey`
- `/spec-add-model` (entity + state machine + invariants)
- `/spec-add-nfr`
- `/spec-add-constraint`
- `/spec-add-invariant` (cross-aggregate only)
- `/spec-elaborate <id>` — deepen an existing vague item with targeted questions.

**Audit** — narrow skills, one per failure mode, leaving inline AUDIT directives.
- `/spec-audit-consistency` — contradictions between elements.
- `/spec-audit-coverage` — gaps relative to declared scope and journey compositions.
- `/spec-audit-quality` — depth of behavior specifications, evidence concreteness, naming discipline.
- `/spec-audit-coherence` — narrative flow and abstraction-level consistency within a capability.
- `/spec-audit-ambiguity` — vague language ("appropriate", "fast"), undefined terms, missing quantifiers.
- `/spec-audit-testability` — every behavior independently verifiable with stated evidence.
- `/spec-audit-traceability` (Tier 2/3) — every element has ≥1 code/test back-reference; every code path is justified by some element.

**Refinement**
- `/spec-refine <id> <operation>` — resolve AUDIT findings (`correct`, `expand`, `condense`, `restructure`, `cross-reference`).
- `/spec-restructure <op> <path> [target]` — `split`, `merge`, `promote`, `demote`. Sweeps every reference in spec, code, and tests.
- `/spec-glossary-sync` — terminology alignment across the project.

**Tier 3 (deferred)**
- `/spec-compile` — generate code from spec.
- `/spec-diff-trace` — when code drifts from spec, decide whether spec or code is wrong.

**Bridges to execution workflows**
- `/spec-derive-milestone` — project one slice of the spec (a capability, journey, or NFR target) into a new `ROADMAP.md` entry for the milestone-driven workflow. See *Integration with other workflows*.

## Integration with other workflows

Spec-native is the **singular upstream** — the durable description of *what should be*. Execution-oriented workflows are **pull consumers**: each translates slices of the spec into its own native unit of work. Spec-native is expected to stay stable and unique; execution workflows are expected to be swapped or adapted per team.

### Milestone-driven

A dedicated bridge skill, `/spec-derive-milestone`, lives in `spec-native/` and projects one spec slice per invocation into a `ROADMAP.md` entry in the format `/milestone-breakdown` already consumes. Decisions:

- **Co-ownership of `ROADMAP.md`.** Manual entries via `/strategic-planning` remain valid; bridge-generated entries are an alternative input, not a replacement. Milestone-driven keeps working standalone for projects that don't adopt spec-native.
- **Provenance via `spec_ref`.** Bridge-generated entries carry an inline `spec_ref:` metadata field alongside the existing `status:` field, pointing at the source spec element (e.g. `spec_ref: auth/login`). Entries without `spec_ref` are valid — they're just untracked-from-spec.
- **One milestone per run**, symmetrical with `/strategic-planning`. The user picks the slice (or it's named as an argument); the skill runs a short Socratic refinement pulling in `CON:`, NFR references, and acceptance hints from the spec automatically.
- **Refuses on unresolved AUDIT.** If the spec slice being projected has any unresolved AUDIT directive within it, the bridge refuses — projecting from audited-incomplete content would propagate ambiguity into a milestone.
- **Traceability flows spec → roadmap, not the reverse.** Any future `/spec-audit-traceability` reports gaps on the spec side ("capability X has no realizing milestone"), so it doesn't choke on manual roadmap entries.

### Codebase-survey

Still open. `CODEBASE.md` documents *what is*; the spec documents *what should be*. Conflict-resolution rules (which wins when they disagree, whether `/codebase-architecture-assessment` consults the spec, whether `/spec-audit-traceability` consults `CODEBASE.md`) are deferred until both workflows have been used together on a real project.

### Research

Still open. The likely seam is glossary entries (`G:` in spec vs. `glossary.md` in research) and whether `CON:` constraints can cite research sources directly. Deferred.

## Open Questions

Tracked here so they can be resolved in subsequent design sessions:

1. **Behavior addressability** — does the ID space stop at behavior, or do sub-parts (`auth/login#invalid-password.evidence`) get IDs? Useful for fine-grained test failure attribution; risks encouraging behaviors that should split.
2. **Socratic question banks** — what specifically does each `add-*` skill ask before writing? Universal challenges per kind (e.g. behavior: "what's the trigger? what's the observable evidence? which actor?") plus per-kind specifics.
3. **Audit skill boundaries** — where exactly does each audit skill's responsibility start and end? E.g. "missing edge case" — coverage or quality? "Vague trigger" — ambiguity or testability?
4. **Lifecycle / deprecation** — Tier 2/3 specific. When a behavior no longer applies, code may still reference it. Need a "deprecated" status (still resolvable for trace, flagged for removal) and a removal workflow that verifies no remaining references first.
5. **Inception flow** — what `/spec-inception` asks, what defaults it offers, what minimum viable starting state looks like.
6. **Tier 3 compile/trace** — out of scope for the initial workflow; design once Tier 2 is proven.
