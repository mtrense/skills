---
last_audit:
  consistency: 2026-05-01
  coverage: 2026-05-01
  quality: null
  coherence: null
  ambiguity: null
---

# Glossary

Project-wide terms of art. Each `### <slug>` heading is addressable as `G:#<slug>`. Definitions are deliberately short; deeper treatment belongs in the spec element that owns the concept.

### idempotency

A property of an operation such that performing it once and performing it more than once produce the same observable state. In this spec, every write endpoint accepts a client-supplied `Idempotency-Key` header and is required to honor it for ≥24 hours.

### session

The authenticated relationship between a `customer` and the system, materialized as a `DM:session` row and a signed cookie. Created by `auth/login`; terminated by `auth/logout` or by expiry.

### reservation

A soft hold placed on `DM:inventory` when a customer enters checkout. Distinct from a committed inventory decrement, which only happens once `INV:checkout-atomicity` resolves successfully. Reservations expire after 15 minutes.

### evidence

In a behavior specification, the externally observable signal that distinguishes "behavior happened" from "behavior didn't happen". See `README.md` §"What Evidence contains" for the full definition; this entry exists so prose can link to it as `G:#evidence`.

### saga

A long-running sequence of local transactions across multiple aggregates, with compensating actions for each step, used in place of a distributed transaction. The checkout flow is implemented as a saga (see `INV:checkout-atomicity`).

<!-- AUDIT: coverage — "actor" is used pervasively but has no glossary entry; either add one or accept that it is defined structurally by `actors/`. severity: low -->
