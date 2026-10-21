---
name: sm-retire
description: >
  Sub-skill of `session-manager`. Post-merge cleanup gate for a dispatched session: five checks
  (branch merged into origin base, local base synced to origin, tests pass, human confirmed via
  -Confirmed, delegation tally logged for the prompt) — reports every check and deletes nothing
  unless all pass. Then retires the prompt file, worktree and branch. Use for "/retire-session",
  "clean up that handoff", "retire the session", "remove the worktree now the PR merged".
---

# retire

_Stub — authored by the session-manager build (checklist item for `retire`)._
