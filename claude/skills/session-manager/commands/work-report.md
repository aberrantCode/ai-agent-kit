---
description: Read-only where-do-things-stand snapshot for this repo — classify recent sessions and report the ranked picture without executing anything
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/resume/SKILL.md` in **read-only report** mode. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:resume)`.

An optional message narrows the recall window (`14d`, `10s`, a date, or `all`); otherwise use the smart default.

Mode: **read-only report**. Run the scan and classification, reconcile enough git state to label each thread honestly, and present the ranked shortlist with a one-line status per session, followed by the next approved action from `references/plan-nextstep.md`. This is a pure FYI snapshot: do NOT execute a next action, do NOT open any `AskUserQuestion` prompt, and do NOT mutate git or files. To act on it, the operator can follow up with `/work-resume`.
