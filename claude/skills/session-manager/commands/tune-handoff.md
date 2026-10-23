---
description: Measure how well past handoff prompts worked (join coverage, rubric score, child-session churn, token cost) and propose evidence-backed enhancements to the handoff skill — read-only on history, changes land as a reviewed PR
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/handoff-tuner/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:handoff-tuner)`.

Run the loop from that sub-skill — `scripts/mine_handoffs.py`, `scripts/score_rubric.py` (reading `references/rubric.json`), `scripts/measure_churn.py` — then write the report, propose the handoff enhancements, and self-tune the rubric. Keep every history read read-only and land all changes through a reviewed PR.
