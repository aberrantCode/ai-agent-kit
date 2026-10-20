---
description: Change what the status line displays (segments, color thresholds, padding/refresh) or reconcile drift between the live script and the archive asset — editing the canonical asset first, then redeploying so live and archive stay in lockstep. Verifies by simulation.
---

Load the `statusline` skill (`Skill(statusline)`), then **read and follow**
`sub-skills/modify/SKILL.md` to run its `modify` operation. The sub-skill is a file in the loaded
bundle to read — not a skill to dispatch; do not call `Skill(statusline:modify)`.

An optional message may describe the change; if ambiguous, elicit it via `AskUserQuestion` —
never guess a display the user didn't ask for. Follow the inlined Output Contract: edit
`assets/statusline.sh` (the source of truth) first, redeploy via the install operation, verify by
simulation, then report. Persisting the archive change to the repo is a separate `/ship`.
