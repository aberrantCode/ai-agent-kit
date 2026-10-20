---
name: security
description: Stack-scoped security checklist (static/docs repos vs. CLI vs. web app/service) — no hardcoded secrets always, input validation/SQLi/XSS/CSRF/auth/rate-limiting only where the surface exists — plus secret-management pattern and the stop-and-fix protocol for a found security issue
category: Security & Credentials
kind: snippet
scope: global
applies-to: [claude, codex, gemini]
targets: security
source: ~/.claude/rules/security.md, archived 2026-08-09
status: active
version: 2026-08-09
---

## Applicability by stack

The checklist below is the **web-app / service** profile (a repo with a runtime,
endpoints, a database, or untrusted input at runtime). Apply each item **only where
the corresponding surface exists** — do not manufacture a finding for a surface the
repo does not have.

- **Static / design-system / token / library / docs repos** (no runtime, no
  endpoints, no DB, no runtime user input — e.g. `AC_DESIGN`): only **"no hardcoded
  secrets"** applies. SQL-injection, XSS, CSRF, rate-limiting, and auth items are
  N/A; the `security-reviewer` agent is not a required pre-commit gate.
- **CLI / desktop repos:** "no hardcoded secrets" + path/argument validation where
  inputs exist; the network/endpoint items are N/A unless the tool makes calls.
- **Web app / service repos:** the full checklist applies.

## Mandatory Security Checks

Before ANY commit (apply the items that match the repo's stack — see
[Applicability by stack](#applicability-by-stack)):
- [ ] No hardcoded secrets (API keys, passwords, tokens) — **always**
- [ ] All user inputs validated — *where inputs exist*
- [ ] SQL injection prevention (parameterized queries) — *if a DB is queried*
- [ ] XSS prevention (sanitized HTML) — *if HTML is rendered from data*
- [ ] CSRF protection enabled — *if there are state-changing endpoints*
- [ ] Authentication/authorization verified — *if there is auth*
- [ ] Rate limiting on all endpoints — *if there are endpoints*
- [ ] Error messages don't leak sensitive data — *where errors surface to users*

## Secret Management

```typescript
// NEVER: Hardcoded secrets (real keys are long; never inline one)
const apiKey = "sk-XXX"

// ALWAYS: Environment variables
const apiKey = process.env.OPENAI_API_KEY

if (!apiKey) {
  throw new Error('OPENAI_API_KEY not configured')
}
```

## Security Response Protocol

If security issue found:
1. STOP immediately
2. Use **security-reviewer** agent
3. Fix CRITICAL issues before continuing
4. Rotate any exposed secrets
5. Review entire codebase for similar issues
