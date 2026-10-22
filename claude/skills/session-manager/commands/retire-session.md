---
description: Run the post-merge cleanup gate for a dispatched session — five checks, deletes nothing unless all pass and a human passes -Confirmed
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/retire/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:retire)`.

Never pass `-Confirmed` yourself; that flag is a human-only gate.

Arguments: the repo path, the prompt file, and the task branch. Run `scripts/complete-task-session.ps1` first without `-Confirmed` and show the user all five check results; if only "user confirmed" fails, ask the user whether the work is right, and rerun with `-Confirmed` only if they say so. Pass `-SkipTests` / `-NoDelegation` only when their stated conditions hold.
