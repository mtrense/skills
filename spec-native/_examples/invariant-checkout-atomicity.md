---
id: INV:checkout-atomicity
references:
  - DM:order
  - DM:inventory
  - DM:payment
last_audit:
  consistency: 2026-05-01
  coverage: 2026-05-01
  quality: null
  ambiguity: null
  testability: null
  traceability: null
---

# Cross-aggregate invariant: Checkout atomicity

**Statement**: for any successful checkout, exactly three state changes occur together or none do — `DM:order` transitions `pending → paid`, `DM:inventory` decrements the reserved quantity to a committed quantity, and `DM:payment` captures funds. No durable intermediate state in which only one or two of these have happened is reachable.

**Rationale**: each of the three aggregates owns its own consistency boundary; without this cross-aggregate guarantee, partial failures produce phantom orders (paid but unfulfillable) or phantom inventory holds (deducted but never paid). This is the canonical reason an invariant cannot live inside any single `DM:` file — it spans three of them.

**Enforced at**: the checkout orchestrator. Implementation is via a saga with compensating actions, not a distributed transaction — see `dec-0058` in `DECISIONS.md`.

**Observable failure modes**:
- `DM:order` in `paid` with `DM:payment` in `failed` (compensation did not run).
- `DM:inventory` decremented with no matching `DM:order` row in `paid` (orphan reservation past the reservation TTL).

**Audit hooks**: a nightly job reconciles the three aggregates and emits one alert per inconsistent triple. Sustained inconsistency is a `severity: high` operational finding.

<!-- CERTAINTY: medium — saga design committed; reconciliation job is specified but not yet implemented -->
