---
description: Read-only "where do things stand" snapshot for this repo. Scans recent Claude Code sessions (including worktrees), classifies each as completed / interrupted / awaiting-you, and reports the ranked picture plus the next approved action — without executing anything or touching git. Use to get your bearings before deciding.
---

Apply the `work-resume` skill in **read-only report** mode.

Run the scan and classification, reconcile enough git state to label each thread
honestly, and present the ranked shortlist with a one-line status per session,
followed by the next approved action from `sub-skills/plan-nextstep`. This is a
pure FYI snapshot: do NOT execute a next action, do NOT open any
`AskUserQuestion` prompt, and do NOT mutate git or files. If the operator wants
to act on it, they can follow up with `/work-resume`.

An optional message narrows the recall window (`14d`, `10s`, a date, or `all`);
otherwise use the smart default.
