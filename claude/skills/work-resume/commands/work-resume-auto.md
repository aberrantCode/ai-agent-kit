---
description: Auto-resume the single best in-flight thread in this repo — no picker, no confirmation gate. Scans recent sessions (including worktrees), reconciles against git, takes the top-ranked resumable candidate, and immediately begins executing its next action. Use when you already know you want to continue and don't need to choose.
---

Apply the `work-resume` skill and run its full pipeline against the current repo,
in **auto-resume** mode.

Skip the shortlist prompt entirely: rank the recent sessions, reconcile the top
candidate against git, and begin executing its next action immediately — no
`AskUserQuestion` gate. Still respect hard git-workflow rules (never push to
`dev`/`main` directly; branch/PR as normal) while carrying the work forward.

If — and only if — there is genuinely nothing to resume (every recent session is
complete), fall through to `sub-skills/plan-nextstep` and offer the next approved
action rather than doing nothing.

An optional message narrows the recall window (`14d`, `10s`, a date, or `all`);
otherwise use the smart default.
