---
description: Merge one or more open pull requests into dev with a merge commit, then clean up the worktree, local branch, and remote branch. Accepts an optional message naming a PR number, branch, worktree, a set of them, or nothing (uses the current context). Responds with minimal output — a concise summary at the end, errors as they occur.
---

Apply the `github` skill and execute its `merge` operation (`sub-skills/merge`).

Parse the invocation message per the parent skill's **Parameter Contract**. It is optional and
may name:
- a PR number (`1209`)
- a branch name
- a worktree path
- a set of the above (space/comma separated)
- nothing — in which case use the current context (the current branch's open PR, or the
  worktree you are standing in)

If no target can be resolved, use `AskUserQuestion` to elicit one — never inline-print a
free-text question.

Follow the parent skill's **Output Contract** strictly: stay silent during execution, surface
errors the moment they occur, and end with a single concise summary. Do not narrate steps.
