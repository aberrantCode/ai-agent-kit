---
description: Initialize or retrofit a repo for the project-manager workflow — docs/ tree, templates, AGENTS.md, CLAUDE.md fragment, pre-commit guard, hook, PR template, ROADMAP. Idempotent.
---

Load the `project-manager` skill (`Skill(project-manager)`), then **read and follow** `sub-skills/init-project/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(project-manager:init-project)`.
