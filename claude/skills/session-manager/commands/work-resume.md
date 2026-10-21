---
description: Pick up where you left off in this repo — scan recent sessions (including worktrees), reconcile against git, present a ranked shortlist, and stop for approval
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/resume/SKILL.md` in **propose-and-stop** mode. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:resume)`.

An optional message narrows the recall window (`14d`, `10s`, a date, or `all`); otherwise use the smart default.

Mode: **propose-and-stop**. Run the full pipeline (scan, classify, reconcile, shortlist) against the current repo, recommend the strongest resumable thread, and pose the choice via `AskUserQuestion` (always include a "None / show next approved action" option that routes to `references/plan-nextstep.md`). Once the operator picks a thread, show its resume brief (reconstructed goal and acceptance criteria, git-reconciled status, the single recommended next action) and STOP for approval before touching anything.
