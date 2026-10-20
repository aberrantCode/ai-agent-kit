---
name: testing
description: 80% minimum test coverage, unit/integration/E2E test types required only where the corresponding surface exists, the mandatory RED-GREEN-IMPROVE TDD workflow, and how to troubleshoot test failures without weakening tests
category: Code Quality
kind: snippet
scope: global
applies-to: [claude, codex, gemini]
targets: testing
source: ~/.claude/rules/testing.md, archived 2026-08-09
status: active
version: 2026-08-09
---

## Minimum Test Coverage: 80%

## Test Types — required *where the surface exists*

Include each type **only if the repo has the surface it targets**. A repo with no
web UI is not failing coverage for having no E2E suite.

1. **Unit Tests** - Individual functions, utilities, components — **always required**
2. **Integration Tests** - API endpoints, database operations, or the equivalent
   cross-module contract (e.g. a token-build → generated-artifact drift check) —
   required where the repo has integrated components
3. **E2E Tests** - Critical user flows (Playwright) — **only for repos with a web/UI
   surface**. Library / CLI / token / design-system repos (e.g. `AC_DESIGN`) satisfy
   this requirement with unit + integration tests (e.g. `pytest`); there is no
   Playwright layer to add.

The stack determines the runner — `pytest` for Python, `vitest`/`jest` for JS/TS,
Pester for PowerShell — not just Playwright.

## Test-Driven Development

MANDATORY workflow:
1. Write test first (RED)
2. Run test - it should FAIL
3. Write minimal implementation (GREEN)
4. Run test - it should PASS
5. Refactor (IMPROVE)
6. Verify coverage (80%+)

## Troubleshooting Test Failures

1. Use **tdd-guide** agent
2. Check test isolation
3. Verify mocks are correct
4. Fix implementation, not tests (unless tests are wrong)

## Agent Support

- **tdd-guide** - Use PROACTIVELY for new features, enforces write-tests-first
- **e2e-runner** - Playwright E2E testing specialist
