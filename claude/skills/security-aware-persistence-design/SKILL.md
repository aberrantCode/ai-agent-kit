---
name: security-aware-persistence-design
description: Use when designing or reviewing a feature that persists user-supplied data (new DB table/API, exposing a service, or writing multi-statement Create/Update/Delete flows) — apply parameterized queries, PII handling, DoS caps, and transaction safety, and gate any network-exposure decision on real (not speculative) use.
status: active
version: 2026-07-05
---

# Security-Aware Persistence Design

## When to use

Any time you're adding a feature that writes user-supplied data to storage, exposing a service/endpoint beyond its original boundary, or implementing multi-step database writes (update-then-delete-then-reinsert patterns). Also use when someone asks "can we expose X now that we have Y auth layer?" — that question needs an audit, not a reflexive yes.

## Method

### Data-handling hygiene
1. **Parameterize every query.** All user-supplied values go through bind parameters (`?` placeholders); never string-build SQL by concatenation or interpolation.
2. **Treat PII (especially IP addresses) as first-class.** Store fields like `client_ip` as nullable, and explicitly document where that data could be exposed — particularly in multi-tenant deployments where one tenant's request metadata could leak to another's view.
3. **Add defense-in-depth caps even without a full threat model.** E.g., a read-limit cap prevents storage-exhaustion DoS even in a single-user, no-auth tool. Cheap mitigations are worth adding even when the full auth/rate-limit stack isn't in place.
4. **Document your assumptions explicitly, don't bury them.** State things like "single-user, no-auth design" or "no rate-limiter, because the app has none anywhere" directly in the code/PR, so the trade-off is a conscious, reviewable decision rather than a silent gap. Route CRITICAL/HIGH findings through security review before shipping.

### Transactional integrity
5. **Wrap multi-statement writes in a single transaction with rollback.** The anti-pattern `UPDATE → DELETE → re-insert` executed as separate statements is a data-loss vector: if any insert fails after the DELETE has already run, every item in that operation's scope is permanently gone. Wrap the whole sequence in one transaction so a failure anywhere rolls back the whole operation.
6. **Audit the codebase for the correct pattern already in use** (e.g., a `SaveApplyResultAsync`-style method that transactions correctly) and apply that same pattern to every other multi-statement operation you find.
7. **Verify transaction semantics with integration tests against a real database** (e.g., real SQLite, not an in-memory mock). Unit tests with mocked DB calls cannot catch rollback bugs — only a real engine enforces real transaction rules.

### Exposure decisions
8. **Gate every "should we expose this" question on real, current use** — ask "does anything authenticate against this right now?" If the use is real and routine (e.g., off-network laptops connecting regularly), the surface is justified. If it's speculative ("we might need it someday"), retire it; re-adding a tunnel/route later takes minutes.
9. **Audit the actual auth model per service before trusting a blanket claim like "we have SSO now."** App-layer forward-auth (e.g., Authentik) is useless against direct backend access if network isolation is bypassed. Separate services into: genuinely forward-auth-gated with no bypass path (safe to expose), vs. network-isolated-by-assumption infra surfaces with `auth:none` (never expose directly).
10. **Never recommend opening a network boundary wholesale.** Always scope to an allowlist or a narrow route instead.

## Gotchas

- "It works" is not the bar — a working feature with unparameterized SQL or an un-transacted multi-write is a regression waiting for the first concurrent failure.
- Mocked unit tests give false confidence on transaction correctness; only integration tests against a real engine catch rollback bugs.
- Speculative future need is not a justification for present-day attack surface — require a concrete, currently-authenticating consumer.
- A service being "behind SSO" doesn't mean it's safe to expose if the SSO is forward-auth only and the backend itself has no auth.

## Diagram

[View diagram](diagram.html)
