---
description: Decide what to work on next in the current repo. Analyses structure, detects the PM framework, prioritises pending tasks with a weighted heuristic, and — after you pick from the top three — hands the chosen task to the right specialist agent. Caches findings to docs/what-next.md so subsequent runs skip re-analysis.
---

Use the `what-next` skill to decide the next action for this repository.

Arguments passed to this command (if any): $ARGUMENTS

If the argument contains `update` or `refresh`, run the Update Flow (force re-analysis and
reconcile the backlog). Otherwise walk the Master Decision Flow, using the cache when fresh.
