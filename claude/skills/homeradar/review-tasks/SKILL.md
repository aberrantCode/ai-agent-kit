---
name: review-tasks
description: Dry-run project status report — counts specs, plans, and tasks by status without modifying any files
---

# Review Tasks

Invoke the `project-manager` skill and execute the `/review-tasks` command exactly as specified there.

Produce a read-only status report:
1. Count feature specs in `docs/features/`
2. Count plans in `docs/plans/` and identify specs missing a plan
3. For each plan: count tasks by status (todo / in-progress / done / blocked)
4. List any active task files in `docs/tasks/active/`
5. List any open issues in `docs/issues/`
6. Output a structured markdown report with overall completion %, per-feature progress table, and next recommended action

**Do not modify any files.**
