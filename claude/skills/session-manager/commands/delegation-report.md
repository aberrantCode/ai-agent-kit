---
description: Report delegated-subagent outcomes (escalations, redos, failures, ok totals) from the delegation ledger
---

Load the `session-manager` skill (`Skill(session-manager)`), then **read and follow** `sub-skills/delegation-ledger/SKILL.md`. The sub-skill is a file in the loaded bundle to read -- not a skill to dispatch; do not call `Skill(session-manager:delegation-ledger)`.

Run `scripts/delegation-report.ps1` from that sub-skill (pass `-LedgerPath`, `-MinSample`, `-FailureThreshold`, `-Since` as the user asks), then relay the per-category failure shares and any flagged category/model pairs, noting when the report withholds a recommendation for insufficient data.
