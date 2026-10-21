---
description: Turn this session's open decision items into a handoff prompt and launch it in a fresh Claude session in a new Windows Terminal tab
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/handoff/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:handoff)`.

This is **launch mode** (the default): recover the open decision items from this conversation, write the claim-tagged prompt, and hand the file to `dispatch` to launch. If the arguments name `copy` or `chain`, follow that mode instead; if they supply a task description, follow scope mode. Never start a handoff the user did not ask for.
