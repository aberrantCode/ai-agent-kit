---
name: continue-tasks
description: Run the full HomeRadar project orchestration loop — picks up the next todo task, spawns the appropriate agent, and iterates until all tasks are complete
---

# Continue Tasks

Invoke the `project-manager` skill and execute the `/continue-tasks` command exactly as specified there.

Follow all steps in the `/continue-tasks` section:
1. Bootstrap check — verify feature specs exist
2. Generate any missing plans
3. Find the next `todo` task
4. Write the task file
5. Spawn the appropriate agent
6. Monitor for completion sentinel and loop
