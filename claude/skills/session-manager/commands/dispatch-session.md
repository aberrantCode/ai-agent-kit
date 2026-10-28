---
description: Launch any prompt file in a fresh Claude session — create or reuse a per-task worktree, open a new Windows Terminal tab, and verify the launch
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/dispatch/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:dispatch)`.

The argument is the prompt file path (any prompt file, not only one `/handoff` wrote).

Steps:

1. Validate that the prompt file exists and is non-empty; if no argument was given, ask for the path.
2. Reuse a supplied worktree, or create one with `scripts/new-task-worktree.ps1` (derive a hyphenated slug from the filename).
3. Launch with `scripts/launch-claude-session.ps1` (`-WorkingDirectory` = the worktree; pin the model with `-SetEnv "ANTHROPIC_MODEL=<id>"` when the task warrants it). Use `-DryRun` first if the environment changed.
4. Confirm the PID from the script output and report: worktree path, branch, prompt path, PID, model.
