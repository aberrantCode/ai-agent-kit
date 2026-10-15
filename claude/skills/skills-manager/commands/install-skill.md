---
description: Deploy a skill bundle from the archive to the global profile or a project — runs scripts/push-to-profile.ps1 (never hand-copies), resolving the target from install-target frontmatter
---

Apply the `skills-manager` skill and execute the /install-skill operation with the provided skill name and optional target.

Deployment is script-driven: resolve the target (explicit instruction → the skill's `install-target:` frontmatter → `global` when not in a repo → `global` default), then run `scripts/push-to-profile.ps1` — `-Name <name>` for the global profile, or `-Name <name> -TargetDir "<project>/.claude/skills"` for a project. Preview first (no `-Force`), confirm via AskUserQuestion, then re-run with `-Force`. Never author bundle files with the editor.
