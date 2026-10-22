---
description: Mine prior Claude Code transcripts for domain knowledge about a service or codebase, or turn repeated corrections into proposed (never applied) CLAUDE.md/rule patches
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/mine/SKILL.md` in **knowledge mode**. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:mine)`.

The argument names the service, codebase, or topic to mine for.

Default: knowledge mode (mine transcripts for what is known about the topic). If the operator asks to turn repeated corrections into rules, use the "proposed patches" option in the SKILL: diff-style CLAUDE.md/rule proposals with session-id evidence, presented for approval and never applied.
