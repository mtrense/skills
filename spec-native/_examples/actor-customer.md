---
id: A:customer
last_audit:
  consistency: 2026-05-01
  coverage: 2026-05-01
  quality: null
  coherence: null
  ambiguity: null
---

# Actor: Customer

A person who browses the catalog, places orders, and tracks shipments on their own behalf. The default end-user actor for the storefront.

## Wants

- Find products that match their need without friction.
- Complete a purchase in as few steps as the payment provider allows.
- See the status of past orders without contacting support.

## Authority

- May read and write their own account, cart, and orders.
- May not read or modify other customers' data.
- May not change pricing, inventory, or fulfillment state — those are operated by `A:admin` and the fulfillment system.

## Distinguishing notes

A `customer` is always authenticated against `DM:user` with `role=customer`. Anonymous browsers are a separate actor (`A:visitor`) — promoting `visitor` to `customer` happens at first checkout (`auth/register`).
