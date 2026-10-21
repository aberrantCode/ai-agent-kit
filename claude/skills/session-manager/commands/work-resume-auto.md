---
description: Auto-resume the single best in-flight thread in this repo — no picker, no confirmation gate
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/resume/SKILL.md` in **auto-resume** mode. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:resume)`.

An optional message narrows the recall window (`14d`, `10s`, a date, or `all`); otherwise use the smart default.
