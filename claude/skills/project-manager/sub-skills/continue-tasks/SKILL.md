---
name: continue-tasks
description: Run the full project orchestration loop with approved-spec gating, dependency ordering, verified completion, and deterministic failure/blocked handling
---

# Continue Tasks

Run the project-manager orchestration loop. This command may create plans, create one active task
file, spawn one worker, reconcile a completed task, insert corrective or verification work, and then
continue until there is no eligible work or the loop must pause for the user.

## Required Inputs

Load these local artifacts before acting:

- `docs/features/*.md`, excluding `README.md` and `template.md`
- `docs/plans/*.md`, excluding `archive/`
- `docs/tasks/active/*.md`
- `docs/tasks/archive/*.md`
- `docs/tasks/locks/*.md`
- `docs/tasks/logs/*.md`
- `docs/issues/*.md`
- `docs/workflow/FOCUS.md`
- `docs/workflow/INDEX.md`
- `docs/features/template.md`, `docs/plans/template.md`, `docs/tasks/template.md`

If `docs/features/` has no real specs, run the Feature Interview from `project-manager:init-features`
first. If scaffolding is missing, stop and tell the user to run `/init-project`.

## Step 1 - Classify Feature Specs

If `references/scripts/pm-validate.ps1` exists, run it before plan or task mutation. Treat errors as
blockers unless they are the exact active completion state being reconciled in Step 4. If the helper
is not available, perform the validation checks manually.

For each feature spec, parse YAML frontmatter. Required fields for orchestration are `slug`,
`status`, `priority`, and `depends_on`.

Classify specs:

- `approved`: eligible for plan generation and task selection
- `draft`: report as not eligible; next action is user review/approval or `/analyze-features`
- `deprecated`: report as ignored
- `implemented`: report as complete; do not generate new plans unless the user asks
- missing or malformed status: treat as `draft` and report the problem

Never generate a plan or task for a spec unless its frontmatter has `status: approved`.

## Step 2 - Build Dependency Graph

Build a graph from approved specs using `depends_on` slugs.

- If a dependency slug is missing from `docs/features/`, write an issue in `docs/issues/` and skip
  the dependent feature.
- If a dependency exists but is not `implemented` and its plan is not complete, skip the dependent
  feature and report it as dependency-blocked.
- If a cycle exists, write an issue describing the cycle and pause the loop for user resolution.
- Pick eligible features by dependency order first, then priority (`p0`, `p1`, `p2`, `p3`), then slug.

## Step 3 - Generate Missing Plans

For each eligible approved spec without a matching `docs/plans/{slug}-plan.md`:

1. Read the spec and extract all CAP-IDs from `## Capabilities`.
2. Generate a phased plan from `docs/plans/template.md`.
3. Cover every CAP-ID in at least one task.
4. Include explicit review/test tasks for implementation-heavy phases when obvious.
5. Write `docs/plans/{slug}-plan.md`.

Do not plan draft, deprecated, implemented, dependency-blocked, or malformed specs. Report them
separately in the command output.

## Step 4 - Reconcile Active Tasks First

Before spawning anything new, inspect every file in `docs/tasks/active/`.

Completion detection is strict:

- Ignore `## Completion Instructions`.
- Find the final `## Completion` heading in the file.
- Treat it as complete only if the text after that final heading contains a parseable `Status:`
  field with one of `success`, `failure`, or `blocked`.
- If a `## Completion` heading exists without a parseable `Status:`, leave the task active, report it
  as malformed, and do not update the plan.
- If no sentinel exists and the file is older than 24 hours, report it as stale. Do not archive it
  automatically.

Handle complete active tasks using the reconciliation rules below. If any active task remains
in-progress, malformed, blocked, or stale after reconciliation, pause before spawning new work.

## Step 5 - Reconciliation Rules

### `Status: success`

Parse `Summary:`, `Artifacts:`, `Tests:`, and `Notes:`.

- If `Tests: passing: false`, do not mark the task done. Add a corrective build/test task before
  downstream work, mark the original plan task `blocked` or back to `todo` depending on whether the
  worker can proceed after fixes, archive the active file with a failure note, and return to task
  selection.
- If the task role/category requires verification, insert or activate a verification task unless a
  matching review/test/security/e2e task already exists for the same CAP-ID and artifact set.
- Only mark the implementation task `done` after its verification task succeeds. Until then, set its
  plan notes to `implementation complete; verification pending`.
- Archive successful task files to `docs/tasks/archive/` after plan reconciliation.

Verification-required categories include roles or task text containing:
`implementation`, `feature`, `api`, `build`, `types`, `errors`, `security`, `ui`, `frontend`,
`backend`, `database`, `migration`, `refactor`, or `cleanup`.

Verification tasks must review the artifacts listed in the completion block, confirm tests, check
spec alignment for covered CAP-IDs, and append their own `## Completion` block.

### `Status: failure`

Read `Error:` and diagnose the missing prerequisite.

1. Increment the plan frontmatter `failures:` count.
2. Add 1-3 corrective tasks before the failed task, with appropriate roles.
3. Mark the original failed task back to `todo` unless the failure is unrecoverable.
4. Archive the failed active file to `docs/tasks/archive/` with status preserved.
5. If failures reach 5, mark the plan `blocked`, write `docs/issues/{slug}-failure-{YYYYMMDD-HHMM}.md`,
   report what was tried, and pause.

Failure issue files must include: feature, plan, task file, status, root cause, what was tried,
corrective tasks added, failure count, and decision needed.

### `Status: blocked`

Do not treat blocked as failure.

1. Mark the plan task `blocked`.
2. Write `docs/issues/{slug}-blocked-{YYYYMMDD-HHMM}.md`.
3. Move the task file to `docs/tasks/archive/` with blocked status preserved.
4. Report the blocker and ask the user for the decision needed.
5. Pause the loop.

Blocked issue files must include: feature, plan, task file, blocker reason, decision needed,
artifacts touched, and recommended next actions.

## Step 6 - Select the Next Task

If `references/scripts/pm-next.ps1` exists, run it and use its output as the deterministic first
pass. Still verify the selected task against the current approved spec and plan before writing files.

Scan eligible plans in dependency order. Pick the first task with `Status` `todo` whose earlier
phase tasks and feature dependencies are complete.

If no eligible todo tasks remain:

- If some approved plans have blocked, stale, malformed, or verification-pending work, report those
  states and stop.
- If all approved plans are done, report "All approved plans complete." For specs whose P0
  capabilities are verified, suggest setting the spec `status: implemented`.
- Also list draft specs, deprecated specs, implemented specs, and approved specs without eligible
  work.

## Step 7 - Write One Task File

Create `docs/tasks/active/{feature-slug}-p{N}-t{M}.md` from `docs/tasks/template.md`.

Include:

- Full task description and expected outcome from the plan
- Relevant capability and acceptance-criteria excerpts from the approved spec
- Phase goal and exit criteria
- Related archived task summaries for the same feature
- Allowed files and forbidden files
- Completion instructions requiring a final `## Completion` block with parseable `Status:`
- Claim fields: `claimed_by`, `claimed_at`, and `lease_expires_at`
- Optional tracker fields: `external_issue` and `external_url`
- Future parallel fields, with `parallel: false` unless an explicit approved parallel analysis exists

Update the plan task status to `in-progress`.

Create `docs/tasks/locks/{task-id}.lock.md` when `docs/tasks/locks/` exists. Create or append
`docs/tasks/logs/{task-id}.md` when `docs/tasks/logs/` exists. Refresh `docs/workflow/FOCUS.md`
with the active task, lease expiry, blockers, and next action. Append durable discoveries or
cross-feature decisions to `docs/workflow/INDEX.md` only when there is a factual note worth keeping.

## Step 8 - Spawn the Worker

Map the plan role to the agent type:

| Role | Agent Type |
|---|---|
| `architecture`, `design`, `planning` | `planner` |
| `feature`, `implementation`, `api` | `tdd-guide` |
| `review`, `quality` | `code-reviewer` |
| `security` | `security-reviewer` |
| `build`, `types`, `errors` | `build-error-resolver` |
| `e2e`, `testing` | `e2e-runner` |
| `docs`, `documentation` | `doc-updater` |
| `cleanup`, `refactor` | `refactor-cleaner` |
| anything else | `general-purpose` |

Spawn with:

> Read the task file at `{path}`. Perform all actions described. When complete, append a final
> `## Completion` block to the bottom of the task file exactly as specified in the template. Do not
> delete or modify any existing content above the appended completion block.

## Step 9 - Monitor

Poll only the spawned task file. Use the strict completion detection from Step 4. When a valid
completion block appears, return to Step 5. If the task becomes stale or malformed, report and pause.

Before any long pause, update `docs/workflow/FOCUS.md` with the current task state and the exact next
command to run. If context-critical information is buried in the task file, append it to the task log
or `docs/workflow/INDEX.md`.
