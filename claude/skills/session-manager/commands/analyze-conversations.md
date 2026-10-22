---
description: Review recent Claude Code sessions for recurring mistakes, repeated friction, and operator corrections, then propose (never apply) prevention patches
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/mine/SKILL.md` in **friction mode**. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:mine)`.

An optional message sets the window (`7d`, `10s`, a date, or `all`).

Run the extractor (`sub-skills/mine/scripts/analyze-conversations.py --window <window>`), cluster the report, and deliver the concise list then drafted patches for approval; apply nothing until approved. Default window `7d`.
