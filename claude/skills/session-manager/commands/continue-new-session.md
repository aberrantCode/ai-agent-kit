---
description: Alias of /handoff copy mode — print a copy-ready prompt for a fresh Claude/Codex/Gemini session to start the next action from this session's latest recap; launches nothing
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/handoff/SKILL.md` in **copy mode**. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:handoff)`.

Back-compat alias (was `project-manager`); removed in the release after the `session-handoff` retirement.
