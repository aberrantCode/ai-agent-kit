---
description: Ship current working changes (or an already-committed feature branch) into dev through a feature-branch PR — stage, commit, push, open the PR, merge with a merge commit, and clean up. Responds with minimal output — a concise summary at the end, errors as they occur.
---

Load the `github` skill (`Skill(github)`), then **read and follow** `sub-skills/ship/SKILL.md` to run its `ship` operation. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(github:ship)`.

An optional message may supply a branch name and/or commit message; otherwise infer them and
confirm via `AskUserQuestion`.

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Do not narrate steps.
