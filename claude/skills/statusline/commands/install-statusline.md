---
description: Deploy the canonical, worktree/handoff-safe status-line script to ~/.claude/statusline.sh and wire the statusLine block into settings.json — idempotently, with a backup, merging into existing settings without clobbering other keys. Verifies by simulation before declaring done.
---

Load the `statusline` skill (`Skill(statusline)`), then **read and follow**
`sub-skills/install/SKILL.md` to run its `install` operation. The sub-skill is a file in the
loaded bundle to read — not a skill to dispatch; do not call `Skill(statusline:install)`.

An optional message may name a non-default deploy target; otherwise deploy to
`~/.claude/statusline.sh`. Follow the inlined Output Contract — stay silent during execution, back
up any existing script, merge settings.json without clobbering, and verify by simulation (a
worktree-shaped payload plus the empty-payload exit-0 case) before reporting success. All prompts
via `AskUserQuestion`.
