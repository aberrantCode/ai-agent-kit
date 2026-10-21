---
description: Alias of /handoff scope mode — turn a supplied task scope into a handoff prompt and launch it in a fresh Claude session in a new Windows Terminal tab
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/handoff/SKILL.md` in **scope mode**. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:handoff)`.

Treat the arguments/message that invoked this command as the task scope. Back-compat alias; removed in the release after the `session-handoff` retirement.
