---
description: Promote dev to main as a versioned production release — rebase dev if behind, auto-derive the next semantic version from conventional commits, merge with a merge commit, tag, publish a GitHub Release, and sync dev. Responds with minimal output — a concise summary at the end, errors as they occur.
---

Load the `github` skill (`Skill(github)`), then **read and follow** `sub-skills/release/SKILL.md` to run its `release` operation. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(github:release)`.

An optional message may pin the version (e.g. `v0.3.0`); otherwise derive it from conventional
commits and confirm via `AskUserQuestion`.

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Do not narrate steps.
