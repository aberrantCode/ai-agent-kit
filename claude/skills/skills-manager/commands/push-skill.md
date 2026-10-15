---
description: Push a skill bundle from the archive to the global user profile (~/.claude/skills/) so it is available in all projects — runs scripts/push-to-profile.ps1, never hand-copies
---

Apply the `skills-manager` skill and execute the /push-skill operation, passing any provided skill name as the target to push. If no name is provided, the skill will use AskUserQuestion to confirm pushing all archive skills to the global profile.

Deployment is script-driven: preview with `scripts/push-to-profile.ps1 -Name <name>`, confirm via AskUserQuestion, then re-run with `-Force`. Never author profile files with the editor — the script stamps provenance, nests sub-skills, relocates companion commands to `~/.claude/commands/`, backs up any existing bundle, and skips drafts.
