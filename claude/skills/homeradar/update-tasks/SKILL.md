---
name: update-tasks
description: Sync active task files — checks for completion sentinels and updates plan status without re-running any tasks
---

# Update Tasks

Invoke the `project-manager` skill and execute the `/update-tasks` command exactly as specified there.

1. Read every file in `docs/tasks/active/`
2. For each file, check for a `## Completion` sentinel
3. If found: parse `Status:` and `Summary:` fields, update the plan task status, archive the task file, log notes
4. Report what was updated

**This command is idempotent — safe to run multiple times.**
