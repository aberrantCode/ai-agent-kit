---
description: Read-only report of repo state — working tree, branch tracking, worktrees, open PRs, and merged-stale branches — ending with a recommendation for which lifecycle command (ship/merge/release/prune) applies next. Never mutates repo or GitHub state.
---

Apply the `github` skill and execute its `inspect` operation (`sub-skills/inspect`).

The current working directory is the repo under inspection. This operation is strictly
read-only: it never stages, commits, pushes, merges, branches, deletes, or prunes anything.
Follow the parent skill's Output Contract as adapted in `sub-skills/inspect` — stay silent while
gathering state, then emit exactly one report ending with a recommendation. It may offer to
launch the top recommended follow-up via `AskUserQuestion`, but never invokes one itself.
