---
description: Run the full project orchestration loop — pick up the next todo task, spawn the appropriate agent, and iterate until all tasks complete
---

Load the `project-manager` skill (`Skill(project-manager)`), then **read and follow** `sub-skills/continue-tasks/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(project-manager:continue-tasks)`.
