---
description: Auto-resume the single best in-flight thread in this repo — no picker, no confirmation gate
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/resume/SKILL.md` in **auto-resume** mode. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:resume)`.

An optional message narrows the recall window (`14d`, `10s`, a date, or `all`); otherwise use the smart default.

Mode: **auto-resume**. Skip the shortlist prompt entirely: rank the recent sessions, reconcile the top candidate against git, and begin executing its next action immediately, with no `AskUserQuestion` gate. Still respect hard git-workflow rules (never push to `dev`/`main` directly; branch and PR as normal). If, and only if, there is genuinely nothing to resume (every recent session is complete), fall through to `references/plan-nextstep.md` and offer the next approved action rather than doing nothing.
