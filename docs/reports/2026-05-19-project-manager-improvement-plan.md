# Project Manager Skill Improvement Plan

Date: 2026-05-19

Goal: make the Claude `project-manager` skill dependable as a full project management lifecycle orchestrator while preserving its existing markdown-driven design.

## Phase 1 — Fix Installability and Discoverability

Objective: installed users receive a complete, runnable skill and understand the command surface.

Tasks:

1. Update `install-skills.ps1` to recursively copy `references/` for skill bundles.
2. Add a small helper in `install-skills.ps1` for recursive GitHub directory download so future support directories can be added safely.
3. Decide command exposure:
   - Option A: keep project-manager commands skill-scoped and document that installed skill commands live under the skill bundle.
   - Option B: add top-level `claude/commands/*.md` wrappers for all eight project-manager commands.
4. Update README command documentation to match the chosen command exposure model.
5. Improve `scripts/generate-manifest.py` so folded YAML descriptions are captured.
6. Regenerate `manifest.json`.

Acceptance criteria:

- Installing `project-manager` also installs `references/feature-spec-template.md`, `references/plan-template.md`, `references/task-file-template.md`, and `references/init-project/*`.
- Manifest description for `project-manager` is non-empty and useful.
- README no longer implies a command location that is not true.

## Phase 2 — Remove Workflow Ambiguity

Objective: users invoking feature workflows enter the correct project-manager path.

Tasks:

1. Resolve the standalone `add-feature` conflict.
2. Preferred implementation: update `claude/skills/add-feature/SKILL.md` to detect project-manager scaffolding (`docs/workflow/SDLC.md`, `docs/features/template.md`, `docs/tasks/`) and defer to `project-manager:add-feature`.
3. Alternative implementation: rename the standalone skill/command surface to `feature-spec` or `draft-feature`.
4. Update descriptions and README entries to explain which feature-spec workflow should be used in project-manager repositories.

Acceptance criteria:

- A user in a project-manager repo who asks to add a feature is routed to the canonical CAP-ID workflow.
- The standalone add-feature workflow no longer silently creates specs incompatible with project-manager.

## Phase 3 — Harden Core Orchestration Rules

Objective: `/continue-tasks` only advances authorized work and can safely detect task completion.

Tasks:

1. Update `/continue-tasks` plan generation rules to include only feature specs with frontmatter `status: approved`.
2. Update `/continue-tasks` review output to list draft, deprecated, and implemented specs separately.
3. Add dependency graph handling based on `depends_on`.
4. Skip or block tasks whose feature dependencies are incomplete.
5. Detect dependency cycles and missing dependency slugs.
6. Replace the `## Completion` heading in `task-file-template.md` with `## Completion Instructions`.
7. Update worker instructions to append a final `## Completion` block.
8. Update polling/reconciliation instructions to require a parseable `Status:` field after the final `## Completion` heading.

Acceptance criteria:

- Draft specs do not produce plans or tasks.
- Task files are not treated as complete immediately after creation.
- Feature dependencies affect task selection.
- Dependency errors are surfaced as issues, not silently ignored.

## Phase 4 — Add Verification and Quality Gates

Objective: successful implementation work is reviewed before being marked done.

Tasks:

1. Define task categories that require verification, such as implementation, API, build, security, and UI work.
2. Add orchestration behavior that creates a follow-up verification task after implementation success, unless the plan already contains an explicit review task for the same CAP-ID.
3. Require review tasks to inspect changed artifacts listed in the implementation completion block.
4. Parse `Tests:` from completion blocks.
5. If `passing: false`, do not mark implementation as complete; create a corrective build/test task.
6. Update `SDLC.md.template` so Verify behavior matches the actual orchestrator flow.

Acceptance criteria:

- Implementation tasks do not become final without review or equivalent verification.
- Failed tests create corrective work.
- SDLC documentation and `/continue-tasks` behavior agree.

## Phase 5 — Define Failure, Blocked, and Stale Task Recovery

Objective: the orchestration loop can recover predictably from non-happy paths.

Tasks:

1. Define explicit handling for `Status: failure`.
2. Define explicit handling for `Status: blocked`.
3. Add issue-file templates or required fields for blocked and failure states.
4. Specify stale `in-progress` detection, such as active task files with no sentinel and older than a configurable age.
5. Add `/update-tasks` behavior for success, failure, blocked, malformed sentinel, and stale active task files.
6. Clarify whether blocked task files are archived or kept active.

Acceptance criteria:

- `success`, `failure`, and `blocked` each have deterministic plan updates.
- Malformed completion blocks are surfaced without corrupting plan state.
- Stale active tasks appear in `/review-tasks` and `/update-tasks` output.

## Phase 6 — Align Roadmap and Reporting

Objective: status artifacts do what they claim.

Tasks:

1. Decide whether `ROADMAP.md` is generated, manually maintained, or report-only.
2. If generated, add a `/refresh-roadmap` command or make `/review-tasks --write` style behavior explicit.
3. If report-only, remove claims from `ROADMAP.md.template` that `/review-tasks` refreshes it.
4. Expand `/review-tasks` to include spec statuses, dependency blockers, stale active tasks, open issues, and verification backlog.

Acceptance criteria:

- `/review-tasks` remains read-only unless explicitly changed.
- Roadmap documentation accurately describes how it is updated.
- Project status reporting covers the full lifecycle state.

## Phase 7 — Expand Operational Sub-Skills

Objective: each thin command target has enough local expertise to run without relying on the parent file for critical details.

Tasks:

1. Expand `sub-skills/continue-tasks/SKILL.md` with the full updated orchestration loop.
2. Expand `sub-skills/update-tasks/SKILL.md` with full reconciliation logic.
3. Expand `sub-skills/reinit/SKILL.md` with full archive, normalization, and launch behavior.
4. Keep top-level `SKILL.md` as a concise overview and routing reference.
5. Remove duplicate or contradictory lifecycle language during the split.

Acceptance criteria:

- Each command wrapper invokes a sub-skill that contains complete executable guidance.
- Top-level and sub-skill instructions do not disagree.

## Phase 8 — Add Deterministic Reporting and Validation

Objective: make read-only project state reporting repeatable, cheap, and testable instead of relying
on LLM reconstruction every time.

External inspiration:

- CCPM uses script-first status, standup, search, next, blocked, and validate helpers.
- TICK.md includes protocol validation as part of its coordination model.

Tasks:

1. Add `references/scripts/` to the project-manager skill bundle.
2. Implement read-only helpers:
   - `pm-status`
   - `pm-next`
   - `pm-blocked`
   - `pm-stale`
   - `pm-validate`
3. Keep helpers portable where practical: PowerShell for Windows-first installs, with either POSIX
   shell equivalents or documented fallback behavior.
4. Add validation rules for:
   - Feature-spec frontmatter and allowed statuses
   - Plan frontmatter and task status values
   - CAP-ID format and coverage
   - Dependency slugs and cycles
   - Task-file completion sentinel shape
   - Verification backlog markers
5. Update `/review-tasks` to run deterministic helpers when present and summarize their output.
6. Update `/update-tasks` and `/continue-tasks` to run validation before mutating plans.
7. Add fixture repositories or fixture folders for validation scenarios.

Acceptance criteria:

- `pm-validate` catches draft-planned specs, malformed sentinels, missing dependencies, dependency
  cycles, stale tasks, and invalid statuses.
- `/review-tasks` output is stable for the same fixture state.
- Deterministic helpers are installed with `references/`.

## Phase 9 — Add Claim, Lease, and Handoff Artifacts

Objective: make the workflow safe across multiple sessions, resumable under context pressure, and
ready for future parallelism.

External inspiration:

- TICK.md and Codepakt/cpk model task claim/release explicitly.
- APM uses Memory, Task Logs, Report Bus, and Handoff artifacts.
- CommonTools task-management uses `FOCUS.md` for easy takeover between sessions.

Tasks:

1. Add task-file frontmatter fields:
   - `claimed_by`
   - `claimed_at`
   - `lease_expires_at`
2. Add `docs/tasks/locks/` convention and a lock file template.
3. Define claim, renew, release, expire, and manual cancellation behavior.
4. Add `docs/workflow/FOCUS.md` template for current focus, active work, blockers, and next action.
5. Add `docs/workflow/INDEX.md` template for durable decisions, discoveries, and cross-feature
   observations.
6. Add task log/report guidance:
   - either `docs/tasks/logs/{task-id}.md`
   - or a structured archived-task appendix if separate logs are too much overhead
7. Add `/handoff` command or integrate handoff output into `/review-tasks`.
8. Teach `/continue-tasks` to update focus/index after reconciliation and before long pauses.
9. Teach `/review-tasks` to report expired leases and handoff readiness.

Acceptance criteria:

- Two sessions can detect a claimed task and avoid duplicate work.
- Expired leases are visible but not automatically destructive.
- A fresh session can read `FOCUS.md`, `INDEX.md`, active tasks, and recent task logs to resume
  without rereading every archived task.

## Phase 10 — Optional External Tracker Sync

Objective: keep local markdown authoritative while allowing teams to mirror work into GitHub issues
or another tracker.

External inspiration:

- CCPM mirrors epics/tasks to GitHub issues and stores progress in issue comments.
- Codepakt/cpk exposes board status and task state through a CLI.

Tasks:

1. Add an optional `/sync-tracker` command wrapper and sub-skill.
2. Start with GitHub issues only, gated on `gh auth status`.
3. Add `external_issue` and `external_url` fields to plan/task frontmatter where needed.
4. Define idempotent sync behavior:
   - Create issue when no external ID exists
   - Update labels/status comments when a local task changes
   - Never overwrite local markdown from remote state without user approval
5. Add tracker labels for `project-manager`, feature slug, CAP-ID, priority, status, and blocker
   state.
6. Add `/review-tasks` output for synced vs unsynced tasks.

Acceptance criteria:

- A plan can be mirrored to GitHub issues without changing local task selection rules.
- Re-running sync does not create duplicate issues.
- Local markdown remains the source of truth.

## Phase 11 — Future Parallel Execution Mode

Objective: preserve serial execution as the default while offering an explicit, guarded path for
independent work streams.

External inspiration:

- CCPM analyzes issues into parallel streams with file scopes, shared-file coordination, and
  worktree requirements.
- APM dispatches parallel work only when dependencies and stage boundaries allow it.
- Sub-Agents Skills shows a portable way to route task-specific agents across multiple LLM backends.

Tasks:

1. Add `parallel`, `conflicts_with`, `files_allowed`, `files_shared`, and `depends_on_tasks` fields
   to task metadata.
2. Add `/analyze-parallelism` or `/continue-tasks --parallel` documentation.
3. Require a parallel analysis artifact before spawning more than one worker.
4. Require isolated worktrees for parallel batches.
5. Define shared-file ownership rules:
   - one stream owns package/config/schema files
   - other streams wait or consume after merge
6. Add batch-level verification and merge coordination before marking the batch complete.
7. Consider optional cross-LLM backend routing after the local serial workflow is stable.

Acceptance criteria:

- Parallel execution is opt-in.
- No task can run in parallel without file scope and conflict metadata.
- Parallel batches have a single verification/merge checkpoint.

## Suggested Implementation Order

1. Phase 1: references installer fix and manifest/README clarity.
2. Phase 3: sentinel and approved-spec enforcement.
3. Phase 2: `/add-feature` ambiguity.
4. Phase 5: blocked/stale recovery behavior.
5. Phase 4: verification gate.
6. Phase 6: roadmap/reporting alignment.
7. Phase 7: sub-skill expansion and final consistency pass.
8. Phase 8: deterministic reporting and schema validation.
9. Phase 9: claim/lease and handoff artifacts.
10. Phase 10: optional tracker sync.
11. Phase 11: opt-in parallel execution.

## Validation Checklist

After implementation, validate with a fixture repository that exercises:

- Fresh `/init-project`
- `/init-features` with approved and draft specs
- `/continue-tasks` with approved-only planning
- An implementation task that succeeds
- An implementation task with failing tests
- A blocked task
- A malformed completion block
- A stale active task
- A feature dependency that is incomplete
- `/review-tasks`, `/update-tasks`, and `/reinit`
- Deterministic helper output for status, next, blocked, stale, and validate
- Expired task leases and claimed active tasks
- Handoff recovery from `FOCUS.md`, `INDEX.md`, and recent task logs
- Optional GitHub issue sync idempotency
- Parallel analysis fixture with disjoint file scopes and one shared-file conflict

The skill should leave no unhandled lifecycle state and no command should depend on missing templates after remote install.
