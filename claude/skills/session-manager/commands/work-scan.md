---
description: Low-level inspection of this repo's recent sessions — dump the raw per-session digest the resume scanner sees, with no classification or action
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/resume/SKILL.md` in **scan** mode. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:resume)`.

An optional message sets the recall window (`14d`, `10s`, a date, or `all`).
