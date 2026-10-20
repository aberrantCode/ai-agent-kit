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

## Comparative Review of Other LLM Project-Management Workflows

External review date: 2026-05-19

Sources reviewed:

- [CCPM — The Project Manager Agent](https://github.com/automazeio/ccpm)
- [Agentic Project Management (APM)](https://github.com/sdi2200262/agentic-project-management)
- [APM Workflow Overview](https://agentic-project-management.dev/docs/workflow-overview/)
- [APM Agent Types](https://agentic-project-management.dev/docs/agent-types/)
- [TICK.md](https://www.tick.md/)
- [Codepakt/cpk](https://github.com/codepakt/cpk)
- [CommonTools task-management skill](https://raw.githubusercontent.com/commontoolsinc/labs/main/skills/task-management/SKILL.md)
- [Sub-Agents Skills](https://github.com/shinpr/sub-agents-skills)

### Command and Sub-Skill Comparison

| System | Command / Skill Surface | Agent Roles / Sub-Skills | State Model | Relevant Ideas |
|--------|--------------------------|---------------------------|-------------|----------------|
| This project-manager skill | `/init-project`, `/init-features`, `/add-feature`, `/analyze-features`, `/continue-tasks`, `/update-tasks`, `/review-tasks`, `/reinit` | Command-specific sub-skills plus role mapping to planner, tdd-guide, reviewer, security, build, e2e, docs, refactor | Markdown under `docs/` | Strong spec-to-plan-to-task traceability; conservative serial execution |
| CCPM | Natural language triggers for PRD, epic parse, task breakdown, GitHub sync, issue start, status, standup, blocked, merge | Reference modules: plan, structure, sync, execute, track, conventions; deterministic script helpers | `.claude/prds`, `.claude/epics`, GitHub issues, worktrees | Script-first status/validation, GitHub issue sync, explicit parallel stream analysis, file-scope conflict rules |
| APM | `/apm-1-initiate-planner`, `/apm-2-initiate-manager`, worker check/report commands, handoff/recover/summarize commands | Planner, Manager, Workers, archive explorer, debug subagents | `.apm/` planning docs, tracker, message bus, report bus, memory index, task logs | Context-scoped agents, structured handoff, message/report bus, manager review of worker logs, stage-level verification |
| TICK.md | `tick next`, `tick claim`, `tick comment`, `tick done`, `tick sync` | Agent roster in task file rather than named sub-skills | Single Markdown task protocol with YAML metadata and append-only history | Atomic claim/release protocol, agent roster, append-only history, JSON schema validation |
| Codepakt/cpk | `cpk init`, `task add/list/show/update/pickup/done/block/unblock/mine`, `docs write/search/list/read`, `board status`, `generate` | Agent names are dynamic; protocol generated into AGENTS/CLAUDE files | SQLite-backed per-project board plus generated agent docs | Atomic pickup, explicit review state before done, blocked/unblocked lifecycle, searchable decisions/learnings knowledge base |
| CommonTools task-management | Skill guidance around Linear, `bd` issues, local todos, `FOCUS.md` | Session-level task management rather than full project orchestrator | Beads issues plus `FOCUS.md` | Lightweight resumability: current focus, subtasks, decisions, and handoff-friendly notes |
| Sub-Agents Skills | `$runner:sub-agents` and markdown agent definitions with `run-agent` backend | Portable task-specific agents across Codex, Claude Code, Cursor, Gemini | Skill-local runner and markdown agent definitions | Cross-LLM backend routing for specialized work |

### New Recommendations from Comparative Review

#### 13. Deterministic Status and Validation Commands Are Missing

Severity: Medium

CCPM separates reasoning-heavy work from deterministic reporting by using scripts for status,
standup, search, next, blocked, and validate operations. The current project-manager skill asks the
LLM to reconstruct status by reading markdown every time.

Impact:

- Status reports can vary between runs.
- Validation of artifact shape is implicit and model-dependent.
- Large projects can spend unnecessary context and latency on mechanical scans.

Recommended fix:

- Add optional `references/scripts/` helpers for project-manager installs:
  - `pm-status`
  - `pm-next`
  - `pm-blocked`
  - `pm-validate`
  - `pm-stale`
- Keep scripts read-only and deterministic.
- Update `/review-tasks` and `/update-tasks` to prefer scripts when present and fall back to manual
  markdown scanning.

#### 14. No Explicit Task Claim / Lock Protocol

Severity: Medium

TICK.md and Codepakt both make claiming work a first-class operation. This project-manager skill
assumes one orchestrator and one active task stream, but installed repositories can still be touched
by multiple users or agents.

Impact:

- Two orchestrators could create or reconcile active task files concurrently.
- A stale active task may be overwritten or duplicated instead of claimed/released.
- Future parallel execution would be unsafe without locks.

Recommended fix:

- Add claim metadata to task files: `claimed_by`, `claimed_at`, `lease_expires_at`.
- Add a lock file convention under `docs/tasks/locks/`.
- Define release behavior for success, failure, blocked, stale, and manual cancellation.
- Teach `/review-tasks` to report expired leases.

#### 15. No Durable Memory / Handoff Layer Beyond Archived Tasks

Severity: Medium

APM uses a Memory Index, Task Logs, Report Bus, and Handoff artifacts so new manager/worker sessions
can recover context without rereading all raw history. The CommonTools task-management skill uses
`FOCUS.md` plus issue state for similar resumability.

Impact:

- Long projects require repeated rediscovery from specs, plans, and archived task files.
- Important implementation decisions may be buried in completion notes.
- Context pressure has no formal handoff/recovery path.

Recommended fix:

- Add `docs/workflow/FOCUS.md` for current project focus and active decisions.
- Add `docs/workflow/INDEX.md` for durable observations and cross-feature decisions.
- Add per-task logs under `docs/tasks/logs/` or a structured appendix in archived tasks.
- Add `/handoff` or fold handoff behavior into `/review-tasks` and `/continue-tasks` when context
  pressure is detected.

#### 16. Optional External Tracker Sync Is Not Defined

Severity: Low

CCPM syncs epics/tasks to GitHub issues and uses comments as a shared audit trail. The current
project-manager skill intentionally remains local markdown only, which is appropriate as a default,
but it has no documented optional bridge for teams that already live in GitHub issues, Linear, or
similar systems.

Impact:

- Team visibility is limited to repo markdown unless users manually mirror tasks.
- PR traceability stops at local files.
- Multi-human collaboration is harder than necessary.

Recommended fix:

- Keep local markdown as the source of truth.
- Add an optional `/sync-tracker` command that can mirror approved plans/tasks to GitHub issues when
  `gh` is authenticated.
- Store external IDs in plan/task frontmatter (`external_issue`, `external_url`).
- Make sync idempotent and append-only where possible.

#### 17. Parallel Execution Model Is Underdeveloped

Severity: Low

This skill currently chooses serial execution, which is safer for correctness. CCPM and APM show a
more advanced path: parallelize only after explicit stream analysis, file-scope assignment,
dependency checks, and conflict rules.

Impact:

- Large independent phases may take longer than necessary.
- Users may manually parallelize without the workflow's safety constraints.

Recommended fix:

- Preserve serial execution as the default.
- Add an explicit future `/analyze-parallelism` or `/continue-tasks --parallel` workflow.
- Require task metadata: `parallel: true`, `conflicts_with`, `files_allowed`, `files_shared`,
  `depends_on_tasks`.
- Use isolated worktrees for parallel streams.
- Require merge/review coordination before marking a parallel batch complete.

#### 18. Validation Should Include Schema-Level Checks

Severity: Medium

TICK.md advertises JSON Schema validation for its protocol. Project-manager templates are currently
human-readable but not machine-validated.

Impact:

- Malformed frontmatter, status values, CAP-IDs, dependency slugs, and completion sentinels can drift
  until an LLM notices.
- Installer and command changes are harder to regression-test.

Recommended fix:

- Add JSON Schema or equivalent validation references for specs, plans, task files, and completion
  blocks.
- Add fixture-based tests for approved/draft specs, dependency cycles, blocked tasks, malformed
  sentinels, stale tasks, and verification backlog.
- Wire schema validation into `pm-validate` and the repository's manifest generation checks.

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
11. Add deterministic status/validation helpers.
12. Add claim/lease metadata before enabling any parallel execution.
13. Add durable memory/handoff artifacts.
14. Add optional external tracker sync.
15. Add schema-level validation and fixtures.
