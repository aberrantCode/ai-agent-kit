---
name: homeradar-fix-start
description: Use when starting any HomeRadar bug fix or regression investigation, before writing any code
---

# HomeRadar Fix Start

**Step 1 — Classify severity** (see `docs/workflow/SDLC.md` SEV table):

| SEV | Definition |
|-----|-----------|
| SEV-1 | Broken / data loss / security regression |
| SEV-2 | Degraded behavior / wrong output |
| SEV-3 | Cosmetic / minor / non-blocking |

**Step 2 — Follow your track:**

**SEV-1:**
1. Write a Fix Brief using `docs/workflow/fix-brief-template.md` — BEFORE creating a worktree
2. Get Erik approval on the Fix Brief (hard gate)
3. Create worktree `fix/<slug>` off latest `dev`
4. TDD fix → self-gate → PR

**SEV-2:**
1. Create worktree `fix/<slug>` off latest `dev`
2. Cite the broken AC from the feature spec in your commit body
3. TDD fix → self-gate → PR

**SEV-3:**
1. Create worktree `fix/<slug>` off latest `dev`
2. Fix → spec reference in commit → PR

**All paths — every commit must include:**
```
Refs: XX-CAP-NN   (or Refs: <spec-filename>#capabilities if spec lacks CAP-IDs)
Spec: docs/features/<spec-name>.md
```

**Reference:** `docs/workflow/SDLC.md` — Fix Track
