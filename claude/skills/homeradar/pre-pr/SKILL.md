---
name: homeradar-pre-pr
description: Use before opening any HomeRadar pull request — three self-gates must all pass
---

# HomeRadar Pre-PR Gate

**Open `docs/workflow/self-gate-checklist.md` and work through all three gates.**

## Gate 1 — Test Gate

Run the full test suite for every stack you touched:

| Stack | Command |
|-------|---------|
| API | `cd api && uv run pytest` |
| Extension | `cd extension && npm test` |
| Web | `cd web && npm test` |
| Web E2E | `cd web && npm run e2e` |

All touched stacks must pass before moving to Gate 2.

## Gate 2 — Quality Gate

Run lint + type-check for every stack you touched. Zero new errors allowed:

| Stack | Command |
|-------|---------|
| API | `uv run ruff check src && uv run mypy src --exclude src/generated` |
| Extension | `npm run type-check` |
| Web | `npm run lint && npm run build` |

## Gate 3 — Spec Gate

```bash
# Every commit must have a Refs: line
git log origin/dev..HEAD --format="%s%n%b" | grep -c "Refs:"
# Must equal total number of implementation commits

# No console.log introduced
git diff origin/dev..HEAD -- '*.ts' '*.tsx' '*.py' | grep '^\+.*console\.log'
# Must return no matches
```

Also verify: PR description includes a Spec Coverage table (CAP-ID → ACs → test).

**A PR without all three gates passing will be rejected at review.**
