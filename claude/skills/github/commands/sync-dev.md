---
description: Fast-forward the local checkout to its upstream (dev ↔ origin/dev) without touching uncommitted work. Never rebases, merges divergent history, or discards changes.
---

Load the `github` skill (`Skill(github)`), then **read and follow** `sub-skills/sync-dev/SKILL.md` to run its `sync-dev` operation. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(github:sync-dev)`.

An optional message may name the branch to sync; otherwise sync the current branch to its upstream.

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Do not narrate steps.
