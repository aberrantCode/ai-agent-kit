---
description: Sync active task files — parse completion sentinels in docs/tasks/active/, update plan statuses, archive completed tasks. Idempotent.
---

Load the `project-manager` skill (`Skill(project-manager)`), then **read and follow** `sub-skills/update-tasks/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(project-manager:update-tasks)`.
