---
description: Read-only report of the live Claude Code status line — which settings layer defines it, the resolved script and its token source (native context_window vs. transcript parsing), dependency availability, and a live simulation — ending with a recommendation. Never mutates settings or the script.
---

Load the `statusline` skill (`Skill(statusline)`), then **read and follow**
`sub-skills/inspect/SKILL.md` to run its `inspect` operation. The sub-skill is a file in the
loaded bundle to read — not a skill to dispatch; do not call `Skill(statusline:inspect)`.

This operation is strictly read-only: it never writes settings.json, deploys, or edits the
script. Follow the inlined Output Contract — stay silent while gathering, then emit exactly one
report ending with a recommendation. It may offer to launch the top follow-up via
`AskUserQuestion`, but never invokes one itself.
