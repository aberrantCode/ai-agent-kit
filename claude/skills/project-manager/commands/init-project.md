---
description: Initialize a project for the project-manager workflow — scaffolds docs/ tree, copies canonical templates, installs AGENTS.md, CLAUDE.md fragment, pre-commit guard, Claude Code hook, PR template, and ROADMAP. Idempotent.
---

Load the `project-manager` skill (`Skill(project-manager)`), then **read and follow** `sub-skills/init-project/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(project-manager:init-project)`.
