---
description: Low-level inspection of this repo's recent sessions — dump the raw per-session digest the resume scanner sees, with no classification or action
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/resume/SKILL.md` in **scan** mode. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:resume)`.

An optional message sets the recall window (`14d`, `10s`, a date, or `all`).

Mode: **scan**. From the repo, run the extractor (script path relative to `sub-skills/resume/`):

```bash
python scripts/resume-scan.py --repo . --format md
```

If the operator's message gives a recall window, pass it as `--window <value>` (`14d` = last 14 days, `10s` = last 10 sessions, `YYYY-MM-DD` = since a date, `all` = full corpus). With no argument, omit the flag and use the smart default (newest-first, last 21 days, clamped to 6-15 sessions). Show the Markdown output largely as-is; this command is deliberately transparent, for seeing which sessions and worktrees the scanner found and what signal each carries. Do not classify, reconcile, or act; that is `/work-resume`'s job.
