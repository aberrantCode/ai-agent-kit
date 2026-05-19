# Validation Invalid Fixture

Synthetic project-manager repo used to exercise `references/scripts/pm-validate.ps1`.

Expected findings include:

- Plan exists for a draft spec
- Missing dependency slug
- Dependency cycle
- Malformed active task completion sentinel
- Stale active task
- Verification backlog warning
