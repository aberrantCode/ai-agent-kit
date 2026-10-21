---
description: Self-perpetuating iteration — merge the pending PR, run the recap's next action in a fresh subagent, and emit the prompt for the action after. Pair with /loop.
---

Load the `project-manager` skill (`Skill(project-manager)`), then **read and follow** `sub-skills/iterate-tasks/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(project-manager:iterate-tasks)`.
