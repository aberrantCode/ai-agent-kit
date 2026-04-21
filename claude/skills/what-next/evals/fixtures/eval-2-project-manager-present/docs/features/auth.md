---
feature: Authentication
slug: auth
status: approved
priority: p1
area: auth
depends_on: []
last_updated: 2026-04-15
---

# Authentication

## Overview
Login, signup, password reset.

## Capabilities
- [ ] Email/password login
- [ ] Password reset email
- [ ] 2FA TOTP

## Requirements
- Must use bcrypt for password hashing
- Must rate-limit login attempts

## Acceptance Criteria
- Given valid creds, when user logs in, then a session is created.

## Out of Scope
- Social login (deferred to v2)
