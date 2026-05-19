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

## Suggested Implementation Order

1. Phase 1: references installer fix and manifest/README clarity.
2. Phase 3: sentinel and approved-spec enforcement.
3. Phase 2: `/add-feature` ambiguity.
4. Phase 5: blocked/stale recovery behavior.
5. Phase 4: verification gate.
6. Phase 6: roadmap/reporting alignment.
7. Phase 7: sub-skill expansion and final consistency pass.

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

The skill should leave no unhandled lifecycle state and no command should depend on missing templates after remote install.
