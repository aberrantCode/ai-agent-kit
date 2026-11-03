---
name: homeradar-feature-start
description: Use when starting any HomeRadar feature — before reading code, writing plans, or creating a worktree
---

# HomeRadar Feature Start

Before ANY feature work, in order:

1. **Find and read the spec:** `docs/features/<feature-name>.md`
2. **Verify `Status: Approved`** — if not, STOP and surface to user. No exceptions.
3. **Create worktree** off latest `dev`:
   ```bash
   git worktree add .worktrees/<branch> -b feat/<branch>
   ```
4. **Write an implementation plan** in `docs/plans/` using B-style task contracts (CAP-ID + files + named test + done condition). See `docs/workflow/SDLC.md` Phase 2 for the format.
5. **Get plan approved** (Gate 2) before writing any implementation code.

**Hard gates you cannot self-approve:**
- Gate 1: Spec `Status = Approved` (human sets this)
- Gate 2: Implementation plan approved by Erik
- Gate 3: PR review
- Gate 4: Release to `main`

**Every implementation commit must include:**
```
Refs: XX-CAP-NN
Spec: docs/features/<spec-name>.md
```

**Reference:** `docs/workflow/SDLC.md` — full 6-phase Feature Track
**Per-phase checklist:** `docs/workflow/feature-checklist.md`
