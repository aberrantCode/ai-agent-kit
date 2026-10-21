---
description: Launch any prompt file in a fresh Claude session — create or reuse a per-task worktree, open a new Windows Terminal tab, and verify the launch
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/dispatch/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:dispatch)`.

The argument is the prompt file path (any prompt file, not only one `/handoff` wrote).
