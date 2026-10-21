---
description: Ship working changes (or a committed feature branch) into dev via a feature-branch PR — commit, push, open the PR, merge with a merge commit, and clean up.
---

Load the `github` skill (`Skill(github)`), then **read and follow** `sub-skills/ship/SKILL.md` to run its `ship` operation. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(github:ship)`.

An optional message may supply a branch name and/or commit message; otherwise infer them and
confirm via `AskUserQuestion`.

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Do not narrate steps.
