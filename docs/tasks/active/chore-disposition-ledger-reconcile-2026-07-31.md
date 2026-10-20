---
feature: "master-skills-reorg"
phase: 0
task: 1
covers: ["REORG-CAP-DATA-01"]
role: "data-custodian"
agent: "general-purpose"
status: todo
created: "2026-07-31"
claimed_by: ""
claimed_at: ""
lease_expires_at: ""
assignee: ""
external_issue: ""
external_url: ""
parallel: false
conflicts_with: []
files_allowed: ["docs/reorg/disposition-ledger.md", "docs/reorg/charter.md"]
files_shared: []
depends_on_tasks: []
---

# Task — `master-skills-reorg-p0-t1`

> **Agent contract.** Read this entire file. Perform every action in the Action Plan section. When done, append a final `## Completion` block at the bottom exactly as specified. Do not modify any content above your appended `## Completion` block.

> **Claim contract.** This task is claimed by `claimed_by` until `lease_expires_at`. If the lease is
> expired, stop and ask the orchestrator to renew, release, or cancel the lock before editing source
> files. Do not remove lock files yourself.

---

## Spec excerpt

**Data-correctness chore:** `docs/reorg/disposition-ledger.md` has drifted from the live filesystem (`claude/skills/` directory inventory) and from `CATALOG.md` (generated manifest). This task reconciles the ledger as a separate pass from feature-work execution.

---

## Plan excerpt

**Phase 0 goal.** Establish single source of truth for skill disposition tracking before iteration 1 ships.

**This task.** Audit the disposition ledger for missing rows (shipped skills not yet recorded), incorrect dispositions (skills marked for one action but actually deleted/retained), and stale counts (header and charter §10 figures). Record findings and correct the ledger.

**Exit criteria.** Ledger rows and counts match the live filesystem and `CATALOG.md`; charter §10 counts are reconciled or explicitly frozen-with-caveat.

---

## Related completed work

None — this is foundational data cleanup prior to the 27-iteration execution plan.

---

## Action plan

1. **Verify the five missing skills exist in `claude/skills/` and `CATALOG.md`:**
   - `claim-discipline`
   - `continue-new-session-prompt`
   - `design-taste-frontend`
   - `opbta-service`
   - `work-resume`
   
   Add a row for each to the ledger with:
   - Disposition: `TBD-pending-review` (placeholder; the actual disposition will be assigned in the relevant iteration PR)
   - Target: `—` (blank)
   - Iter: blank (will be assigned when the skill is processed)
   - Status: `pending`
   - Notes: "Added 2026-07-31 reconciliation pass — shipped skill not in original 2026-07-10 audit"

2. **Correct the `what-next` row:**
   - Current disposition: `move-into-bundle`
   - Actual state: skill was DELETED (git log shows removal)
   - Correct to: disposition = `delete`, Status = `done` (or `deleted` as applicable per charter rule 3)
   - Notes: "Skill deleted prior to reorganization execution; row corrected 2026-07-31"

3. **Revise the `workspace` row:**
   - Current Target: `project-manager / what-next (repo-picker half); API-contract half DELETED`
   - Issue: `what-next` is deleted, so the target reference is stale
   - Correct to: `project-manager / workspace-picker` (or similar, reflecting the actual absorbing sub-skill if it exists; otherwise, align with the final what-next absorption from iteration 9 once that ships)
   - Verify against iteration 9 PR once it lands and update if needed
   - Notes: "Target reference updated 2026-07-31 to reflect what-next deletion"

4. **Reconcile counts (charter §10 and ledger header):**
   - Live filesystem: 143 Claude skill directories (verified 2026-07-31), 84 Codex (matches charter)
   - Charter §10 current figure: 141 Claude (after what-next-workspace deletion in iteration 0)
   - Ledger header current figure: 142 Claude (at 2026-07-10 audit time, pre-iteration-0 deletion)
   - **Action:** Update ledger header from "142 directories" to "143 directories (verified 2026-07-31 live audit)"
   - **Action:** Cross-check charter §10 counts. If what-next was actually deleted, recalculate and update §10 if needed. If the discrepancy is unexplained, surface it in Notes for the orchestrator to resolve.
   - Update summary table counts if the five newly-added skills change the disposition subtotals.

5. **Verification step:**
   - Ensure every row in the updated ledger corresponds to a real `claude/skills/*/` directory
   - Ensure `CATALOG.md` (next-generation manifest) reflects all rows in the ledger
   - Generate `manifest.json` and confirm the count matches

**Files you may create or modify**

- `docs/reorg/disposition-ledger.md` — add rows, correct dispositions, update header

**Files you must not touch**

- `docs/features/**` — specs are authority; if a change is needed, surface it in completion notes
- `docs/plans/**` — orchestrator-owned
- `docs/reorg/charter.md` — changes to charter only via orchestrator after human resolution
- Other task files

**Parallel execution metadata**

- `parallel` is `false`; this is a sequential data-cleanup task
- `files_allowed` scope edits to the disposition ledger and charter (read-only for verification)

---

## Constraints

- Do not invent dispositions for the five newly-added skills; use "TBD-pending-review" placeholders and note that the actual disposition will be assigned when those skills are processed in an iteration PR
- Do not delete any rows; corrections are amendments + updated Status fields
- Preserve git history: all previous edits to the ledger remain as-is

---

## Completion Instructions

> **The agent appends the block below at the bottom of the file under a new final `## Completion` heading. The orchestrator only treats the task as complete when the final `## Completion` heading has a parseable `Status:` field after it. Use the exact field names.**

```
## Completion

Status: success | failure | blocked
Summary: One-sentence outcome.
Artifacts:
  - relative/path/changed-file.md
Tests:
  added: 0
  changed: 0
  passing: true
Notes:
  - Findings surface in the completion section; no test suite for data reconciliation
  - Any unresolved count discrepancies flagged here
  - Indicate if charter §10 requires manual update after ledger correction
Handoff:
  - Ledger is now authoritative for the 27-iteration execution plan; next orchestrator loop can rely on it
  - Five newly-added skills awaiting disposition assignment in future iteration PRs
Error: (only present when Status is failure)
  Root cause: ...
  What was tried: ...
  Suggested corrective task: ...
Blocked: (only present when Status is blocked)
  Reason: ...
  Decision needed: ...
```
