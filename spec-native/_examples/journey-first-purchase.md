---
id: JRN:first-purchase
actor: customer
scenarios:
  - auth/register
  - catalog/browse
  - checkout/place-order
  - checkout/pay
  - fulfillment/track
references:
  - NFR:api#p95-latency
  - CON:gdpr#consent-on-signup
last_audit:
  consistency: 2026-05-01
  coverage: 2026-05-01
  coherence: null
  ambiguity: null
---

# Journey: First purchase

A new customer arrives, creates an account, finds a product, completes a purchase, and tracks the shipment to their door — all in a single session.

## Why this composition matters

The individual scenarios are owned by separate capabilities (`auth`, `catalog`, `checkout`, `fulfillment`), but the first-purchase flow is the dominant funnel for new-customer activation. Any one scenario can pass its own behaviors while the *composition* breaks (e.g. registration succeeds but the resulting session does not carry over into checkout). Journeys exist to make that composition auditable.

## Steps

1. `auth/register` — visitor becomes `A:customer`; `DM:user` row created.
2. `catalog/browse` — customer locates a product; cart populated.
3. `checkout/place-order` — `DM:order` transitions `pending`.
4. `checkout/pay` — `DM:order` transitions `paid`; payment captured.
5. `fulfillment/track` — customer observes shipment status updates until delivery.

## Composition invariants

- The session established at step 1 must remain valid through step 4 without re-authentication.
- The `DM:order` created at step 3 must reference the same `DM:user` created at step 1.

<!-- AUDIT: coherence — step 5 spans days/weeks; consider whether "single journey" framing still holds across asynchronous fulfillment. severity: low -->
