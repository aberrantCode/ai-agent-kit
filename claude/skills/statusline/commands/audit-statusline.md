---
description: Read-only health check of the live status-line script against the three known root causes of vanishing token counts (mtime fallback, transcript-only token source, unsanitized numbers) plus archive drift and exit-code hygiene. Emits a pass/fail table and a recommended fix. Never mutates anything.
---

Load the `statusline` skill (`Skill(statusline)`), then **read and follow**
`sub-skills/audit/SKILL.md` to run its `audit` operation. The sub-skill is a file in the loaded
bundle to read — not a skill to dispatch; do not call `Skill(statusline:audit)`.

Strictly read-only. Follow the inlined Output Contract — stay silent while checking, then emit one
`| Check | Result | Detail |` table (most-severe failure first) and a recommendation. Offer to
launch the top fix via `AskUserQuestion`; never launch it yourself.
