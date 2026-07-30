---
description: Pick up where you left off in this repo. Scans recent Claude Code sessions (including this repo's git worktrees), reconstructs what each expected next, reconciles it against git, and presents a ranked shortlist of resumable threads — you pick one, then it shows the resume brief and stops for your approval before doing anything.
---

Apply the `work-resume` skill and run its full pipeline (scan → classify →
reconcile → shortlist) against the current repo.

Operate in **propose-and-stop** mode: present the ranked shortlist, recommend the
strongest resumable thread, and pose the choice via `AskUserQuestion` (always
include a "None / show next approved action" option that routes to
`sub-skills/plan-nextstep`). Once the operator picks a thread, show its resume
brief — reconstructed goal + acceptance criteria, the git-reconciled status, and
the single recommended next action — then STOP for approval before touching
anything.

An optional message narrows the recall window (`14d`, `10s`, a date, or `all`);
otherwise use the smart default.
