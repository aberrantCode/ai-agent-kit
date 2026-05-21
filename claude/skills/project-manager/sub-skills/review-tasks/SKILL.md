---
name: review-tasks
description: >
  Dry-run project status report. Produces a read-only snapshot of feature specs, dependency
  blockers, plans, active tasks, stale work, verification backlog, and open issues without spawning
  agents or modifying files.
---

# Review Tasks

Produce a read-only status report. Do not modify any files, including `ROADMAP.md`.

## Scan

Prefer deterministic helpers when they are installed:

1. Run `references/scripts/pm-status.ps1`.
2. Run `references/scripts/pm-blocked.ps1`.
3. Run `references/scripts/pm-stale.ps1`.
4. Run `references/scripts/pm-validate.ps1`.
5. Summarize their output in the final report.

If any helper is missing, fall back to the markdown scan below for that category.

1. Read feature specs in `docs/features/`, excluding `README.md` and `template.md`.
2. Parse frontmatter status, priority, slug, owner, and `depends_on`.
3. Read plans in `docs/plans/`, excluding `archive/`.
4. Count plan tasks by `todo`, `in-progress`, `done`, and `blocked`.
5. Identify plans generated for specs that are not `status: approved` or `status: implemented`.
6. Read active task files in `docs/tasks/active/`.
7. For each active task, classify sentinel state:
   - complete: final `## Completion` with parseable `Status:`
   - malformed: final `## Completion` exists but no valid `Status:`
   - stale: no valid sentinel and older than 24 hours
   - in-progress: no sentinel and not stale
8. List open issues in `docs/issues/`.
9. Report claim and lease metadata from active tasks and `docs/tasks/locks/`, including expired
   leases and manually cancelled locks.
10. Report handoff readiness from `docs/workflow/FOCUS.md`, `docs/workflow/INDEX.md`, and recent
   `docs/tasks/logs/` files.
11. Report optional tracker coverage from `external_issue` and `external_url`.

## Dependency Report

Build a feature dependency graph from `depends_on`.

- Report missing dependency slugs.
- Report cycles.
- Report approved specs blocked by dependencies that are not implemented or whose plans are not
  complete.

## Verification Report

List implementation-like tasks that appear complete but still have pending verification:

- Plan notes containing `verification pending`
- Successful implementation task archived without a matching review/test/security/e2e task for the
  same CAP-ID
- Active or todo verification tasks

## Output

Return a markdown report with:

- Overall completion percentage across approved/implemented planned work
- Spec status counts: draft, approved, implemented, deprecated, malformed
- Specs missing plans, limited to approved specs
- Draft specs that need approval before planning
- Dependency blockers
- Per-feature progress table
- Active task table with sentinel state and age
- Claim/lease table with expired leases
- Handoff readiness summary
- Synced vs unsynced tracker items
- Verification backlog
- Open issues
- Next recommended action

State clearly that `/review-tasks` is read-only and that `ROADMAP.md` must be updated manually from
the report if the user wants a persistent roadmap snapshot.

## Related Commands

- `/continue-tasks` - run the full orchestration loop
- `/update-tasks` - reconcile active task files without spawning agents
- `/reinit` - archive legacy state, normalize specs, then launch
