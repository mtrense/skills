# Finding Taxonomy

The checklist the sweep runs against. Work top-to-bottom; the categories are
roughly ordered from "blocks a build" to "polishes the prose." For each item,
the question to ask yourself is: *could two competent engineers read this and
build materially different things — or be unable to build at all?*

Prioritize findings in this order when deciding what to surface first:
1. **Blockers** — an engineer literally cannot proceed (missing core behavior,
   undefined central concept, an outright contradiction).
2. **Fork risks** — the spec admits two reasonable but incompatible readings.
3. **Clarity / quality** — understandable but vague, under-specified, or fragile.
4. **Wording / style** — correct and clear but imprecise, inconsistent, or messy.

---

## 1. Ambiguities
- Vague qualifiers with no measurable definition: "fast", "secure", "scalable",
  "user-friendly", "real-time", "soon", "large".
- Unquantified quantities: "many", "some", "a few", "frequently".
- Pronouns or references with an unclear antecedent ("it", "this", "the service").
- Sentences that parse two ways. Read each requirement adversarially.

## 2. Contradictions
- The same value stated differently in two places (limits, timeouts, names,
  versions, port numbers, field names).
- Requirements that can't both hold (e.g. "fully offline" + "syncs live").
- Doc vs. doc, section vs. section, and prose vs. diagram/table/example mismatches.

## 3. Gaps & omissions
- Error/failure behavior unspecified (what happens when X fails, times out, is
  absent, is malformed?).
- No authn/authz model where the system clearly needs one.
- No data model, or entities mentioned but never defined.
- Missing acceptance criteria / definition of done for features.
- Edge cases and boundaries left open (empty, max, concurrent, duplicate, retry).
- Lifecycle gaps: creation is described but not update/delete/expiry/migration.

## 4. Undefined or inconsistent terminology
- Domain terms used but never defined — does the project need a glossary?
- The same concept under different names ("account" vs "user" vs "member"), or
  one name for two different concepts.
- Acronyms expanded nowhere.

## 5. Unstated assumptions
- Implied platform, runtime, deployment target, or scale never written down.
- Assumed user knowledge, locale, language, timezone, or device.
- Assumed external state ("the data will already be there").

## 6. Scope boundaries
- Is a mentioned feature *in* the system being specified, or not? Flag the
  ambiguity of whether something belongs — not when it should be built.
- Features mentioned in passing whose in-scope status is genuinely unclear.
- Open-ended "etc." / "and more" that hides undefined scope.
- **Out of bounds for this sweep:** sequencing, milestone ordering, MVP-vs-later
  prioritization, phasing, or "what's a reasonable first increment." That is
  *planning*, done later by `/strategic-planning` and `/milestone-breakdown` —
  never propose it here. A scope finding is only valid if it's about *whether* a
  thing is part of the spec, never about *what order* to build the parts in.

## 7. Interfaces & contracts
- API endpoints/messages without defined inputs, outputs, status/error codes.
- Data formats, encodings, units (ms vs s, bytes vs KB), and timezones unstated.
- Pagination, sorting, filtering, rate limits, idempotency on endpoints that need
  them.
- Versioning and backward-compatibility expectations.

## 8. Data model
- Entities, fields, types, required vs. optional, defaults.
- Identity and uniqueness (what is the key?), relationships and cardinality.
- Validation rules and invariants. Allowed value ranges / enums.
- Persistence, retention, and deletion semantics.

## 9. State & behavior
- State machines: what are the states and which transitions are legal?
- Concurrency, ordering, race conditions, idempotency, exactly/at-least-once.
- Time-dependent behavior, scheduling, retries, backoff.

## 10. Non-functional requirements
- Performance targets (throughput, latency) with actual numbers.
- Security & privacy: data sensitivity, encryption, secrets, PII handling.
- Compliance/regulatory constraints if relevant.
- Availability/reliability targets, observability (logging, metrics, tracing).
- Limits and quotas.

## 11. Dependencies & integrations
- External services/APIs: which, what version, what auth, what failure mode.
- Third-party libraries implied but unpinned.
- What happens when a dependency is down or changes.

## 12. Constraints & invariants
- Business rules stated implicitly that should be explicit.
- Hard limits (max file size, max users, budget caps).
- Things that must always or never be true.

## 13. Testability / acceptance
- For each requirement: how would you *prove* it's met?
- Vague success criteria that can't be turned into a test.

## 14. Boilerplate ↔ spec consistency
- Does the scaffolded code/config contradict the docs (different name, framework,
  language, structure than the spec describes)?
- Does the boilerplate reveal an assumption the spec never states?
- Treat the spec as the artifact to fix, but flag the mismatch so the user
  decides which one is right.

## 15. Exemplars (concrete sample artifacts)

Applies when the project keeps an `exemplars/` directory (sample configs,
datasets, payloads, transcripts — each with a `NOTES.md` carrying
`status: illustrative | normative`). Exemplars are spec stated in bytes, which
makes them the sharpest contradiction detectors in the corpus:

- **Placeholder rot** — `TODO`, `<your-value-here>`, `changeme`, suspiciously
  generic values in a field the exemplar exists to pin: the value was never
  actually decided.
- A field, key, or value **no spec claim, ADR, or ubiquitous-language term
  sanctions** — either the exemplar is wrong or the spec has a silent gap.
- A **`normative` exemplar contradicting** prose spec or an `Accepted` ADR —
  tasks bind to normative exemplars, so this is blocker-grade; route it, never
  encode over it.
- **Exemplar vs. exemplar disagreement** — two samples encoding incompatible
  answers to the same question (same field, different type/name/unit).
- Field names using a term **differently than the owning bounded context's
  ubiquitous language** defines it.
- A **spec claim with no exemplar** where one is clearly warranted (a config
  format described only in prose, a wire contract with no sample payload) —
  flag the gap; creating the exemplar belongs to `/exemplar`, not the encoder.
- An exemplar's `NOTES.md` **"Deliberately left open" list drifting** — a value
  listed as non-binding that prose elsewhere treats as a commitment, or vice
  versa.

## 16. Wording & style
- Inconsistent heading levels, structure, or document organization.
- RFC-2119 keyword discipline: are MUST / SHOULD / MAY used deliberately, or are
  requirements buried in soft prose ("we'd like to maybe")?
- Imprecise phrasing that's clear enough but could be tightened.
- Duplicated content that will drift out of sync.
