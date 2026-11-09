# Deferred-question marker

The one format `spec-sharpener` uses to note a question that is real but **deliberately not answered yet**. Shared by the `spec-surveyor` (which finds markers and skips or reopens them) and the `decision-encoder` (which writes and removes them). The marker lives **inline in the spec, right at the spot it is about**, so whoever implements that section trips over it exactly when the answer becomes necessary.

## When a finding is deferrable

A finding is **deferrable** when *all* of these hold:

- **No fan-out** — no other finding or spec section depends on the answer.
- **Local** — confined to one component; not the data model, a contract/interface between parts, persistence shape, or anything cross-cutting.
- **Cheap to revise** — answering it at implementation time costs little rework.
- **Better answered later** — a prototype, real data, or hands-on feel will likely produce a better answer than speculation now.

Otherwise it is **load-bearing**: its answer can divert the direction of the build, so it is settled now.

The test is *"does the answer steer anything else?"* — never *"will this be built later?"*. Deferral is about when an answer is **needed**, not about build order; sequencing stays out of bounds for this skill.

## Two flavours of deferral

- **Open** — the question is noted and left; nothing else is decided.
- **Isolated** — a decision *is* made now: the fork goes behind a proper seam (interface, strategy, config switch, adapter) so it can be tested, switched, or decided later without rework. The seam itself becomes normal spec text (it is a commitment — callers depend on it); only the choice *behind* it stays open. Isolating can turn a load-bearing fork into a deferrable one.

## Format

A blockquote placed directly after the passage it concerns:

```markdown
> **Deferred `retry-backoff`:** Should failed uploads back off linearly or exponentially?
> - Decide when: implementing the upload retry loop
> - Options: linear — simplest · exponential with jitter — kinder to a struggling server
> - Seam: `RetryPolicy` (see "Upload pipeline") — implementations are swappable; tests target the interface
```

- **Slug** (in backticks after `Deferred`) — kebab-case, unique across the corpus. It is the handle for reopening (`--reopen=retry-backoff`). Grep `**Deferred \`` to list every marker.
- **Question** — one sentence, answerable.
- **Decide when** — the concrete moment the answer becomes necessary (a component, a flow, a piece of evidence) — never a milestone or a date.
- **Options** — the candidates known today with a short trade-off each, so the later decider doesn't start from zero. Omit if genuinely none.
- **Seam** — present only for *isolated* deferrals: names the seam and where the spec defines it.

## Lifecycle

- **Written** by the `decision-encoder` when the user defers a finding (singly or in the deferral triage batch). For an isolated deferral, the encoder also writes the seam into the spec text proper.
- **Respected** by the `spec-surveyor` on later runs: a marked question is settled-for-now and is not re-raised — unless an edit since has made it load-bearing (the answer now steers something else), in which case it is re-raised with that reason.
- **Reopened** on demand via `/spec-sharpener --reopen[=<slug>,…]`: the surveyor turns the named (or all) markers back into findings.
- **Removed** by the `decision-encoder` when a reopened question is answered: the marker is replaced by spec text stating the answer (an isolated deferral's seam stays unless the user drops it). Deferring a reopened question again just updates the marker in place.
