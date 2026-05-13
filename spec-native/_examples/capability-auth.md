---
id: auth
actor: registered-user
value: "Authenticate users to obtain a session for protected actions"
preconditions:
  - DM:user
scenarios:
  - auth/login
  - auth/logout
  - auth/password-reset
references:
  - NFR:api#p95-latency
  - CON:gdpr#auth-event-logging
  - DM:session
last_audit:
  consistency: 2026-05-01
  coverage: 2026-05-01
  quality: null
  coherence: null
---

# Capability: Authentication

<!-- one-paragraph framing of what this capability is for -->

## Out of scope

- OAuth / SSO providers (covered by capability `auth-federation`)
- Multi-factor authentication (deferred to milestone M4)

## Scenarios

Ordering reflects typical user flow:
1. `auth/login` — establish session
2. `auth/logout` — terminate session
3. `auth/password-reset` — recover access
