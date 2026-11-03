---
name: reinit
description: Archive legacy plans and tasks, normalize all feature specs to the current template, then launch the full orchestration loop
---

# Reinit

Invoke the `project-manager` skill and execute the `/reinit` command exactly as specified there.

Steps in order:
1. **Archive existing plans** — move all files from `docs/plans/` (non-archive) to `docs/plans/archive/`
2. **Archive existing tasks** — move all files from `docs/tasks/active/` and any loose files in `docs/tasks/` to `docs/tasks/archive/`
3. **Normalize feature specs** — for each `.md` in `docs/features/` (excluding `README.md` and `template.md`): verify required frontmatter and sections; rewrite to template structure if non-conforming, preserving all content
4. **Launch** — run `/continue-tasks` from Step 1

Use this when recovering from an inconsistent state or after manual planning work.
