---
description: Measure the startup (first-turn) context cost of Claude Code sessions and explain why a newly launched session already shows tokens > 0 (read-only)
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/usage/SKILL.md` in **startup-baseline mode**. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:usage)`.

Pass through `--project <substring>`, `--top N`, `--dev-root <path>`, `--json`. Pure measurement: change no setting, model, or file.

Run the bundled `scripts/startup-context.py` (absolute path inside the sub-skill's directory) and present its two parts: the current repo's fresh-baseline decomposition, then the per-repo baseline table. Lead with the headline -- the repo's fresh baseline and how much of it is the on-disk instruction stack versus the harness remainder.
