---
id: NFR:api
last_audit:
  consistency: 2026-05-01
  coverage: 2026-05-01
  quality: null
  ambiguity: null
  testability: null
  traceability: null
---

# NFR group: HTTP API

Measurable properties that apply to every public HTTP endpoint unless an individual behavior negotiates an exception in DECISIONS.md.

## p95-latency

**Statement**: 95th-percentile end-to-end response time, measured at the edge load balancer, stays within budget for every public endpoint.
**Measurement**: rolling 7-day p95 from edge access logs, grouped by route.
**Threshold**: ≤ 300 ms for read endpoints; ≤ 800 ms for write endpoints.
**Rationale**: read latency drives perceived snappiness; write latency is bounded by payment-gateway round-trips, hence the looser write budget (recorded in `dec-0042`).

## error-rate

**Statement**: fraction of 5xx responses over total responses stays below threshold.
**Measurement**: rolling 1-hour 5xx-rate per route from edge access logs.
**Threshold**: < 0.1% per route; sustained breach of 5 minutes pages oncall.
**Rationale**: customer-visible failures erode trust faster than slow responses.

## no-password-in-logs

**Statement**: cleartext passwords, password hashes, and password-reset tokens never appear in any log stream.
**Measurement**: nightly grep of the structured-log warehouse for known sensitive field names and a regex for bcrypt/argon2 hash prefixes.
**Threshold**: zero matches over a rolling 7-day window.
**Rationale**: a prohibition phrased as a measurable absence — belongs in NFR, not in `CON:` (no external authority pins it; the measurement is metric-based).

<!-- CERTAINTY: medium — write-path threshold of 800 ms assumed from current payment-gateway p99; revisit when the new processor lands -->
