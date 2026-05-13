---
id: DM:order
references:
  - DM:user
state_machine: true
invariants:
  - amount-positive
  - line-items-non-empty
  - status-monotonic
last_audit:
  consistency: 2026-05-01
  coverage: 2026-05-01
  quality: null
  coherence: null
---

# Domain model: Order

A customer's intent to purchase one or more items at a specific moment in time.

## Attributes

| Name        | Type            | Notes                                    |
|-------------|-----------------|------------------------------------------|
| id          | UUID            | server-generated                         |
| user_id     | UUID            | references DM:user                       |
| total       | Money           | derived; equals sum of line item totals  |
| status      | OrderStatus     | see state machine                        |
| line_items  | List<LineItem>  | non-empty (see invariant)                |

## State machine

- `pending` (created, awaiting payment)
  - `pay` → `paid`
  - `cancel` → `cancelled`
- `paid` (payment captured, awaiting fulfillment)
  - `ship` → `shipped`
- `shipped` (terminal)
- `cancelled` (terminal)

## Invariants

### amount-positive
**Statement**: `order.total > 0` for any non-cancelled order.
**Rationale**: zero-total orders signal bugs, not legitimate business cases.
**Enforced at**: order creation, every line-item modification.

### line-items-non-empty
**Statement**: `len(order.line_items) >= 1` for any non-cancelled order.
**Rationale**: an order without items is meaningless.
**Enforced at**: order creation, line-item removal.

### status-monotonic
**Statement**: status transitions only follow the state machine; no backward transitions.
**Rationale**: business and accounting depend on monotonic order lifecycle.
**Enforced at**: every status update.

## Examples

### Generic example: paid order

```yaml
id: 7f3a-...
user_id: a1b2-...
status: paid
line_items:
  - { sku: SKU-001, qty: 2, unit_price: 19.99 }
total: 39.98
```

### Edge case: cancelled order with items

A cancelled order retains its line items and total for audit purposes — the invariants `amount-positive` and `line-items-non-empty` are scoped to non-cancelled orders.
