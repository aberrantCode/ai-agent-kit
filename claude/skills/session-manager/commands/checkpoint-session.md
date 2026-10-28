---
description: Write or advance the durable session state file so work survives context resets, /loop iterations, and new sessions
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/checkpoint/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:checkpoint)`.
