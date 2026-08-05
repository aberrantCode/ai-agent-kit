---
description: Stage all changes, pull latest (resolving conflicts), commit with a conventional-commit message, and push. Responds with minimal output — a concise summary at the end, errors as they occur.
---

Load the `github` skill (`Skill(github)`), then **read and follow** `sub-skills/commit/SKILL.md` to run its `commit` operation. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(github:commit)`.

An optional message may supply the commit message; otherwise draft one from the staged diff.

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Do not narrate steps.
