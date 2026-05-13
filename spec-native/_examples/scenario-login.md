---
id: auth/login
capability: auth
actor: registered-user
preconditions:
  - DM:user (must exist, status=active)
references:
  - NFR:api#p95-latency
  - CON:gdpr#auth-event-logging
  - DM:user
last_audit:
  consistency: 2026-05-01
  coverage: 2026-05-01
  quality: null
  coherence: null
---

# Scenario: Login

User authenticates using credentials to obtain a session.

## Behaviors

### valid-credentials
**Trigger**: user submits username + correct password
**System response**: session created, session token returned
**Evidence**: HTTP 200 with `Set-Cookie: session=...`; `DM:session` row exists with `user_id=$user.id`
**References**: DM:session, NFR:api#p95-latency

### invalid-password
**Trigger**: user submits username + incorrect password
**System response**: authentication rejected, no session created
**Evidence**: HTTP 401 with body `{"error": "invalid_credentials"}`; no `DM:session` row created; failed-attempt counter on `DM:user` incremented
**References**: DM:user, DM:user#locked-after-5-failures

<!-- AUDIT: coverage — missing behavior for locked account (>5 failed attempts). Suggested: locked-account. severity: medium -->
<!-- CONFIDENCE: medium — failed-attempts counter behavior assumed; no NFR/CON pins it explicitly -->
