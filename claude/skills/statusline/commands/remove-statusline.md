---
description: Unwire the status line from settings.json (deleting the statusLine block without clobbering other settings) and optionally back up/remove the deployed script. Reversible via /install-statusline. Confirms the delete-the-script choice via AskUserQuestion.
---

Load the `statusline` skill (`Skill(statusline)`), then **read and follow**
`sub-skills/remove/SKILL.md` to run its `remove` operation. The sub-skill is a file in the loaded
bundle to read — not a skill to dispatch; do not call `Skill(statusline:remove)`.

Follow the inlined Output Contract — back up the settings file, delete only the `statusLine` key
via `jq del`, confirm the file is still valid JSON, then ask via `AskUserQuestion` whether to
remove or retain the script (back it up rather than hard-delete unless told otherwise). End with
one concise summary.
