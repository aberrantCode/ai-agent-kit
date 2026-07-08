---
description: Audit and remove stale git worktrees, local branches, and remote (origin) branches already merged into dev, protecting anything with uncommitted changes. Responds with minimal output — a concise summary at the end, errors as they occur.
---

Apply the `github` skill and execute its `prune` operation (`sub-skills/prune`).

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Present the stale list and
confirm deletions via `AskUserQuestion`, but do not narrate the scan itself.
