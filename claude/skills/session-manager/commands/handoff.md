---
description: Turn this session's open decision items into a handoff prompt and launch it in a fresh Claude session in a new Windows Terminal tab (`copy [cli]` prints a copy-ready prompt instead; `scope <task>` hands off a supplied task)
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/handoff/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:handoff)`.

Pick the mode from the first word of the arguments:

| Invocation | Mode |
|---|---|
| `/handoff` (no arguments) | **launch** (default): recover the open decision items from this conversation, write the claim-tagged prompt, and hand the file to `dispatch` to launch |
| `/handoff copy [claude\|codex\|gemini]` | **copy**: print one copy-ready fenced block for the named CLI. Launch nothing, write no file, and do not call `dispatch` |
| `/handoff scope <task>` | **scope**: treat everything after `scope` as the task scope, write the prompt, and hand it to `dispatch` |
| `/handoff chain ...` | **chain** |
| `/handoff <task description>` (any other first word) | **scope**, with the whole argument string as the task |

Never start a handoff the user did not ask for.
