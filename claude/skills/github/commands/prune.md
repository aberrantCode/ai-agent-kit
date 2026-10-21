---
description: Remove stale worktrees and local/remote branches already merged into dev, protecting anything with uncommitted changes.
---

Load the `github` skill (`Skill(github)`), then **read and follow** `sub-skills/prune/SKILL.md` to run its `prune` operation. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(github:prune)`.

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Present the stale list and
confirm deletions via `AskUserQuestion`, but do not narrate the scan itself.
