---
description: Report historical Claude Code token burn from local JSONL logs and apply the 11 rules for reducing usage
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/usage/SKILL.md` in **historical-burn mode**. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:usage)`.

Pass through `--days N`, `--project <substring>`, `--json`.
