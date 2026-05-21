---
name: update-tasks
description: Reconcile active task files with plans without spawning new workers, including success, failure, blocked, malformed, and stale states
---

# Update Tasks

Synchronize `docs/tasks/active/` back into `docs/plans/`. This command is idempotent and never
spawns agents.

## Scan Rules

Run `references/scripts/pm-validate.ps1` first when present. If validation fails, reconcile only the
specific active completion files that are valid enough to parse; avoid broad plan edits until the
reported schema problems are fixed.

For each `docs/tasks/active/*.md`:

1. Parse frontmatter for `feature`, `phase`, `task`, `covers`, `role`, and `created`.
2. Locate the matching plan file (`docs/plans/{feature}-plan.md` preferred).
3. Ignore the template section `## Completion Instructions`.
4. Find the final `## Completion` heading.
5. Treat the task as complete only when the text after that final heading contains
   `Status: success`, `Status: failure`, or `Status: blocked`.
6. If no valid sentinel exists and `created` or file modified time is older than 24 hours, report
   the task as stale.

## Reconciliation

### Success

Parse `Summary:`, `Artifacts:`, `Tests:`, and `Notes:`.

- If `Tests: passing: false`, add a corrective build/test task and do not mark the implementation
  final.
- If the task requires verification and no matching verification task exists, insert a review/test
  task for the same CAP-ID and artifacts, record `verification pending` in the notes, and archive the
  active file.
- If verification is not required, or this task is the verification task and it succeeded, mark the
  matching plan row `done`, append the summary to plan notes, and archive the active file.

Verification is required for implementation, API, build, security, UI/frontend/backend/database,
migration, refactor, cleanup, and other code-changing work.

### Failure

- Increment the plan frontmatter `failures:` count.
- Add 1-3 corrective tasks before the failed task.
- Mark the failed task back to `todo` unless unrecoverable.
- Archive the active task file with its failure sentinel intact.
- Mark the matching `docs/tasks/locks/{task-id}.lock.md` as `released`.
- Append a concise result and handoff note to `docs/tasks/logs/{task-id}.md` when present.
- If failures reach 5, mark the plan `blocked`, write a failure issue under `docs/issues/`, and
  report that user input is required.

### Blocked

- Mark the matching plan row `blocked`.
- Write a blocker issue under `docs/issues/` with the reason and decision needed.
- Archive the active task file with its blocked sentinel intact.
- Mark the matching lock as `released` and preserve the blocker in the task log.
- Report the blocker and stop automatic reconciliation for that feature.

### Malformed

If a final `## Completion` heading exists but no valid `Status:` follows it:

- Leave the active task file in place.
- Do not update plan status.
- Report the file path and the missing or invalid fields.

### Stale

If no valid sentinel exists and the task is older than 24 hours:

- Leave the active task file in place.
- Do not update plan status.
- Report the file as stale and recommend checking the worker session or marking it blocked.
- If `lease_expires_at` is also expired, report the lease as expired. Do not take or cancel the
  claim automatically.

## Claims and Leases

- **Claim**: active task frontmatter names `claimed_by`, `claimed_at`, and `lease_expires_at`; a
  matching lock file records the same lease under `docs/tasks/locks/`.
- **Renew**: only the same owner or orchestrator extends `lease_expires_at`.
- **Release**: success, failure, and blocked reconciliation mark the lock `released`.
- **Expiry**: expired leases stay on disk and appear in reports until the user renews, releases, or
  manually cancels them.
- **Manual cancellation**: set lock status to `cancelled`, record the reason, and leave the task
  active unless the user authorizes archiving.

## Output

Return a concise report with:

- Archived tasks
- Plan rows updated
- Verification tasks inserted
- Corrective tasks inserted
- Blocked/failure issues written
- Malformed active files
- Stale active files
- Released or expired leases
- Task logs updated
- Features still waiting on user decisions
