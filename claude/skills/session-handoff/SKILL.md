---
name: session-handoff
description: >
  Deprecated alias — use `session-manager`. Routes any request that still names
  "session-handoff" (handing off open work to a fresh session, or auditing whether past sessions
  followed a stated rule) to the `session-manager` bundle: `handoff` for "continue in a new
  session" / "hand this off" / "/handoff", and `audit` for "did I actually follow rule X" /
  "/hand-off-audit". Remove in the next release.
category: Foundations & Workflow
status: deprecated
requires: [session-manager]
---

# Session Handoff (deprecated alias)

> **Deprecated 2026-10-21 — remove in the next release.** Everything this bundle did now lives in
> [`session-manager`](../session-manager/SKILL.md). This file only routes; it has no sub-skills,
> scripts, or commands.

| You want to… | Go to |
|---|---|
| Hand off open work to a fresh session (`/handoff`, `/dispatch-session-prompt`) | `session-manager` → `sub-skills/handoff/SKILL.md` |
| Create a worktree and launch a prompt file | `session-manager` → `sub-skills/dispatch/SKILL.md` |
| Retire a finished session (`complete-task-session.ps1`) | `session-manager` → `sub-skills/retire/SKILL.md` |
| Log or report delegation outcomes | `session-manager` → `sub-skills/delegation-ledger/SKILL.md` |
| Audit past sessions against a rule (`/hand-off-audit`) | `session-manager` → `sub-skills/audit/SKILL.md` |

Load `Skill(session-manager)` and read the sub-skill named above.
