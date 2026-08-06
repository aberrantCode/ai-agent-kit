---
description: Self-perpetuating iteration — merge any pending PR, dispatch the recap's next action as a fresh subagent (clean context per iteration), then emit a copy-ready prompt for the action that comes after. Pair with /loop for unattended runs.
---

Load the `project-manager` skill (`Skill(project-manager)`), then **read and follow** `sub-skills/iterate-tasks/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(project-manager:iterate-tasks)`.
