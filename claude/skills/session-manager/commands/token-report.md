---
description: Report historical Claude Code token burn from local JSONL logs and apply the 11 rules for reducing usage
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/usage/SKILL.md` in **historical-burn mode**. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:usage)`.

Pass through `--days N`, `--project <substring>`, `--json`.

Run the bundled `scripts/usage-report.py`, share the headline numbers (cache-hit % and model mix), then diagnose and apply the 2-4 matching rules as the sub-skill directs. Recommend only; change no setting or model without confirmation.
