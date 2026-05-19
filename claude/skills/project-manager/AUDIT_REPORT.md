# Project Manager Skill Audit Report

Date: 2026-05-19

Scope: `claude/skills/project-manager` and immediately related repository files that affect command discovery, installation, and lifecycle behavior.

## Executive Summary

The Claude `project-manager` skill has a coherent feature-driven project management concept and includes thin slash command wrappers, sub-skills, templates, and enforcement artifacts. It covers the broad outline of a project lifecycle: bootstrap, feature capture, planning, task delegation, task reconciliation, failure recovery, and status review.

However, several implementation and workflow assumptions are inconsistent enough to make the lifecycle unreliable in real use. The highest-risk issues are missing installation of `references/`, ambiguous completion sentinel detection, missing approved-spec enforcement during plan generation, command/name collisions around `/add-feature`, and the absence of a mandatory verification gate before marking implementation tasks done.

## Files Reviewed

- `claude/skills/project-manager/SKILL.md`
- `claude/skills/project-manager/commands/*.md`
- `claude/skills/project-manager/sub-skills/*/SKILL.md`
- `claude/skills/project-manager/references/*.md`
- `claude/skills/project-manager/references/init-project/*.template`
- `claude/skills/add-feature/SKILL.md`
- `install-skills.ps1`
- `manifest.json`
- `README.md`

## Findings

### 1. Remote Installer Does Not Copy Required References

Severity: Critical

`install-skills.ps1` installs a skill's `SKILL.md`, `commands/`, and `sub-skills/`, but it does not copy `references/`. The project-manager skill depends on reference templates for feature specs, plans, task files, and `/init-project` scaffolding.

Impact:

- A user installing the skill remotely can receive command wrappers and sub-skills without the templates needed to execute them.
- `/init-project`, `/add-feature`, `/init-features`, and `/continue-tasks` can fail or produce non-canonical artifacts.

Recommended fix:

- Update `install-skills.ps1` to recursively install skill-local `references/`.
- Consider also copying other known support directories if future skills need them, but keep this scoped and predictable.

### 2. Thin Commands Exist in Skill Folder, but Not as Top-Level Claude Commands

Severity: Medium

All eight project-manager thin commands exist under `claude/skills/project-manager/commands/`:

- `add-feature`
- `analyze-features`
- `continue-tasks`
- `init-features`
- `init-project`
- `reinit`
- `review-tasks`
- `update-tasks`

No equivalent files exist under top-level `claude/commands/`. This may be valid if Claude Code loads skill-bundled commands from installed skills, but it conflicts with README language that says global slash commands live in `claude/commands/`.

Impact:

- Users may expect `/continue-tasks` or `/init-project` to be globally available from the archive's `claude/commands/`.
- Install behavior may differ depending on how Claude Code discovers skill-bundled commands.

Recommended fix:

- Decide whether project-manager commands are skill-scoped or global.
- If skill-scoped, document this clearly in README and installer output.
- If global, add top-level thin command wrappers that delegate to `project-manager:*`.

### 3. `/add-feature` Name Collision Creates Ambiguous Routing

Severity: High

The repository contains both:

- `claude/skills/project-manager/commands/add-feature.md`
- `claude/skills/add-feature/SKILL.md`

The standalone `add-feature` skill also triggers on `/add-feature`, but it writes a different date-prefixed feature spec format and does not conform to the project-manager CAP-ID/template workflow.

Impact:

- A user invoking `/add-feature` may enter the wrong feature workflow.
- The resulting spec may not satisfy project-manager assumptions around CAP-IDs, feature registry rows, approval status, or plan coverage.

Recommended fix:

- Rename one surface or make the standalone skill detect project-manager scaffolding and defer to `project-manager:add-feature`.
- At minimum, update descriptions so project-manager repositories prefer the project-manager command.

### 4. Approved-Spec Gate Is Stated but Not Enforced in `/continue-tasks`

Severity: High

The skill says, "Never generate a task for a feature without an approved spec." Templates and SDLC artifacts reinforce that `status: approved` is required before plan generation.

But `/continue-tasks` Step 2 says to generate a plan for each feature spec missing a matching plan, without checking `status: approved`.

Impact:

- Draft or incomplete specs can be planned and implemented.
- Open questions and unapproved scope can become code.

Recommended fix:

- Update `/continue-tasks` to scan only specs whose frontmatter `status` is `approved`.
- Report draft specs separately with the next action: review/approve or run `/analyze-features`.
- Ensure `/review-tasks` includes spec status and flags plans generated from non-approved specs.

### 5. Completion Sentinel Detection Has a False Positive

Severity: High

`task-file-template.md` contains a `## Completion` heading as part of the template instructions. The orchestrator polls task files for the presence of a `## Completion` heading to decide when a worker has finished.

Impact:

- A newly created task file can appear complete before a worker appends anything.
- `/update-tasks` and `/continue-tasks` can archive tasks or parse empty/instructional sentinel content incorrectly.

Recommended fix:

- Change the template heading to something like `## Completion Instructions`.
- Instruct workers to append a final `## Completion` block.
- Update polling to require a final `## Completion` heading plus parseable `Status:` field after that heading.

### 6. Claude Code PreToolUse Hook Does Not Enforce What It Claims

Severity: Medium

The `.claude/settings.json` hook claims to warn before Edit/Write when no active task exists. The guard script inspects staged git files, so at PreToolUse time it generally sees no changed file and exits successfully.

Impact:

- Users may believe edits are being checked before they happen.
- The real enforcement only occurs at pre-commit time.

Recommended fix:

- Reword the PreToolUse hook as advisory-only and explain its limits.
- Or implement a hook mode that reads Claude Code tool input, if available, and checks target paths before editing.
- Keep the Git pre-commit guard as the hard gate.

### 7. Verification Stage Is Declared but Not Implemented

Severity: High

`SDLC.md.template` says the Verify phase is owned by `code-reviewer`, but `/continue-tasks` marks tasks `done` immediately when it sees `Status: success`.

Impact:

- Code can be marked complete without a review pass, test verification, or quality gate.
- The lifecycle describes a stronger process than it actually runs.

Recommended fix:

- Add a verification task after implementation tasks, or require plans to include explicit review/test tasks for each phase.
- Do not mark a phase or feature done until verification tasks pass.
- Parse `Tests:` from completion blocks and escalate when `passing: false`.

### 8. Sub-Skills Are Unevenly Detailed

Severity: Medium

`init-project`, `init-features`, `add-feature`, and `analyze-features` contain substantial workflow detail. `continue-tasks`, `update-tasks`, and `reinit` mostly bounce back to the top-level skill.

Impact:

- The most operationally sensitive loops have the least precise local instructions.
- Delegated command execution depends on the model resolving references back to the parent skill correctly.

Recommended fix:

- Expand `continue-tasks`, `update-tasks`, and `reinit` sub-skills with full local procedures.
- Keep top-level `SKILL.md` as summary plus routing.

### 9. Blocked Status Is Under-Specified

Severity: Medium

The task completion template allows `Status: blocked`, and plan status includes `blocked`, but `/continue-tasks` only defines success and failure behavior.

Impact:

- Workers can return `blocked`, but the orchestrator has no explicit next action.
- A blocked task could be misclassified as failure or ignored.

Recommended fix:

- Define blocked handling separately from failure.
- Mark plan task `blocked`, write an issue file, preserve the active task or archive it with blocked status, and ask the user for a decision.

### 10. Dependency-Aware Ordering Is Missing

Severity: Medium

Feature specs include `depends_on`, but `/continue-tasks` selects tasks by earlier phase and feature alphabetically. It does not mention dependency ordering.

Impact:

- Downstream features may be planned or implemented before prerequisites.
- Corrective tasks may not be inserted in the right dependency context.

Recommended fix:

- Build a feature dependency graph before selecting tasks.
- Skip or block tasks whose feature dependencies are incomplete.
- Report cycles or missing dependency slugs.

### 11. ROADMAP Refresh Is Claimed but Not Implemented

Severity: Low

`ROADMAP.md.template` says `/review-tasks` refreshes roadmap content, but `/review-tasks` is explicitly read-only and says not to modify files.

Impact:

- The roadmap can become stale.
- Users receive conflicting expectations about `/review-tasks`.

Recommended fix:

- Either make `/review-tasks` purely report-only and remove refresh language from `ROADMAP.md.template`, or add a separate `/refresh-roadmap` command.

### 12. Manifest Descriptions Are Empty for Project Manager

Severity: Low

`manifest.json` shows empty descriptions for `project-manager` and standalone `add-feature`, despite rich frontmatter. The manifest generator only reads one-line `description:` values and does not handle folded YAML blocks well.

Impact:

- Installer selection UI shows poor descriptions.
- Users cannot distinguish project-manager from adjacent workflow skills.

Recommended fix:

- Improve `scripts/generate-manifest.py` frontmatter parsing for folded descriptions.
- Regenerate `manifest.json`.

## Lifecycle Coverage Assessment

Implemented:

- Repository scaffolding through `/init-project`
- Initial product intent capture via `docs/INITIAL_PROMPT.md`
- Feature interview and spec generation
- Single feature addition
- Feature audit and authorized repair
- Plan generation from specs
- Serial task creation
- Worker delegation instructions
- Completion sentinel reconciliation
- Task archive
- Failure budget and issue logging
- Read-only project status review
- Legacy state reinitialization

Incomplete or missing:

- Reliable installation of required templates
- Approved-spec enforcement before planning
- Dependency-aware feature/task ordering
- Clear stale `in-progress` task recovery
- Explicit `blocked` handling
- Mandatory post-task verification
- Phase-level and feature-level completion marking
- Roadmap refresh or explicit roadmap update command
- PR/merge/release handoff beyond a template
- Hard scope enforcement against task allowed-files lists
- Conflict resolution between standalone `/add-feature` and project-manager `/add-feature`

## Recommended Priority

1. Fix installation of `references/`.
2. Fix completion sentinel false positives.
3. Enforce approved specs before plan/task generation.
4. Resolve `/add-feature` command/skill ambiguity.
5. Add verification/review handling before marking work done.
6. Define blocked and stale in-progress behavior.
7. Add dependency-aware task selection.
8. Align roadmap behavior and documentation.
9. Expand thin operational sub-skills.
10. Improve manifest description generation.
