---
id: CON:gdpr
last_audit:
  consistency: 2026-05-01
  coverage: 2026-05-01
  ambiguity: null
  traceability: null
---

# Constraint group: GDPR

External regulatory constraints derived from the EU General Data Protection Regulation. Verification is procedural — these are not metric-based; treat each as an authority-rooted "must" or "must not".

## consent-on-signup

**Statement**: a registration flow must record explicit, opt-in consent for processing personal data before `DM:user` is created.
**Source**: GDPR Art. 6(1)(a), Art. 7.
**Verification**: PR-time review checks that any code path creating a `DM:user` is preceded by a recorded consent event; spec-side, `auth/register` must reference `CON:gdpr#consent-on-signup` in its behaviors.

## data-deletion

**Statement**: on customer request, all personal data identifiable to the customer must be deleted or irreversibly anonymized within 30 days.
**Source**: GDPR Art. 17.
**Verification**: a documented runbook exists; quarterly tabletop exercise replays a deletion request end-to-end across `DM:user`, `DM:order`, and log retention.

## auth-event-logging

**Statement**: authentication events (login success, login failure, password reset, session revocation) must be logged with timestamp, actor, source IP, and outcome.
**Source**: GDPR Art. 32 (security of processing); aligns with ISO 27001 A.12.4.
**Verification**: log-schema review at PR time; spec-side, every behavior under `auth/` references this constraint.

## no-pii-export

**Statement**: personal data of EU customers must not be transferred to processors outside the EU/EEA without an approved transfer mechanism (SCCs, adequacy decision).
**Source**: GDPR Art. 44–49.
**Verification**: data-flow review at PR time for any code that calls an external service with customer fields.

<!-- AUDIT: traceability — `data-deletion` is not yet referenced by any scenario; either no scenario implements it or the reference is missing. severity: medium -->
