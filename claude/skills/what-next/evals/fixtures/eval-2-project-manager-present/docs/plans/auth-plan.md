---
feature: auth
failures: 0
---

# Auth Implementation Plan

## Phase 1 - Core login

| Task | Role | Status |
|------|------|--------|
| P1-T1: Scaffold login API endpoint | tdd-guide | done |
| P1-T2: Add password hashing utility | tdd-guide | done |
| P1-T3: Implement rate-limiting middleware | tdd-guide | todo |
| P1-T4: Add login integration tests | e2e-runner | todo |

## Phase 2 - Password reset

| Task | Role | Status |
|------|------|--------|
| P2-T1: Design reset token schema | architecture | todo |
| P2-T2: Implement reset email sender | tdd-guide | blocked |
