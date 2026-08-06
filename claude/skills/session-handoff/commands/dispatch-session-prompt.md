---
description: Turn a supplied task scope into a handoff prompt and launch it in a fresh Claude session in a new Windows Terminal tab
---

Load the `session-handoff` skill (`Skill(session-handoff)`), then **read and follow**
`sub-skills/handoff/SKILL.md` in **scope mode** (see its "Entry modes" section), treating the
arguments/message that invoked this command as the task scope. The sub-skill is a file in the
loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-handoff:handoff)`.
