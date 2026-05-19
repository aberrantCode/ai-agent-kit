---
name: project-manager
description: >
  Automated project implementation orchestrator that drives feature-driven development from a single
  initial prompt through to completed code. Use this skill when the user invokes /init-project,
  /init-features, /add-feature, /continue-tasks, /review-tasks, /update-tasks, /analyze-features,
  or /reinit. Also trigger proactively when docs/INITIAL_PROMPT.md exists and the user says
  anything like "move forward", "keep building", "what's next", "continue the implementation",
  or "start working on the project", AND when the user says "set up project management",
  "bootstrap a new project", "initialize the project workflow", or "make sure agents follow the
  project plan". This skill manages the full lifecycle: scaffolding a new project with enforcement
  artifacts, extracting feature specs via interview, generating phased implementation plans,
  spawning typed agents to execute tasks, monitoring completion sentinels, recovering from
  failures, and archiving finished work — all driven by markdown files that act as the shared
  state between orchestrator and worker agents.
requires: [base]
---

# Project Manager Skill

This skill implements a self-driving project pipeline. Markdown files in `docs/` are the single
source of truth — they persist across sessions and coordinate between the orchestrator (you) and
worker agents.

## Directory Conventions

```
docs/
  INITIAL_PROMPT.md          # Source of truth for product intent (never modified)
  features/                  # Feature specs — final authority on scope
    {feature-slug}.md
  plans/                     # One plan per feature spec
    {feature-slug}-plan.md
  tasks/                     # Active task files (one at a time per phase)
    active/
      {feature-slug}-p{N}-t{M}.md
    archive/
      {feature-slug}-p{N}-t{M}.md
    locks/                   # Claim/lease records for active work
      {feature-slug}-p{N}-t{M}.lock.md
    logs/                    # Append-only task timeline and handoff notes
      {feature-slug}-p{N}-t{M}.md
  guides/                    # Supporting docs, architecture notes (optional)
  issues/                    # Logged failures and blockers
  workflow/
    FOCUS.md                 # Current focus and next action
    INDEX.md                 # Durable decisions and discoveries
```

Read `references/feature-spec-template.md`, `references/plan-template.md`, and
`references/task-file-template.md` for the exact file formats to use. These templates ship with
the skill and are also copied into target projects by `/init-project` (as `docs/features/template.md`,
`docs/plans/template.md`, and `docs/tasks/template.md`).

When present, read-only helpers under `references/scripts/` provide deterministic status,
next-task, blocked, stale, and validation reports. Prefer those helpers for mechanical scans and
fall back to markdown scanning when they are unavailable.

---

## Commands

### `/init-project` — Bootstrap a New Project

Use when the project does not yet have the `docs/` scaffolding, AGENTS.md, hooks, PR template, or
ROADMAP. Idempotent. Detailed flow lives in `sub-skills/init-project/SKILL.md`. The four enforcement
layers installed are:

1. **AGENTS.md + CLAUDE.md fragment** — soft guidance every agent reads
2. **`scripts/guard-pm-flow.ps1` + Git `pre-commit` hook** — blocks commits to source files when
   no active task file exists
3. **`.claude/settings.json` PreToolUse hook** — advisory warning inside Claude Code
4. **`.github/pull_request_template.md` + `ROADMAP.md`** — human review layer

Run **before** `/init-features`. After `/init-project` completes, the user fills in
`docs/INITIAL_PROMPT.md` and then runs `/init-features` to seed feature specs.

---

### `/init-features` — Feature Interview

Use when `docs/INITIAL_PROMPT.md` exists but `docs/features/` is empty or incomplete. Extracts 3-6
functional areas from the prompt, interviews the user one area at a time via `AskUserQuestion`, and
writes one feature spec per area to `docs/features/`. Detailed flow lives in
`sub-skills/init-features/SKILL.md`.

---

### `/add-feature` — Add a Single Feature Spec

Use when `docs/features/` is already populated and a new feature is needed. Runs requirement
gathering, overlap detection against existing specs, template population, optional diagram
generation, and feature-index/CAP-ID-registry updates. Detailed flow lives in
`sub-skills/add-feature/SKILL.md`.

---

### `/continue-tasks` — Full Orchestration Loop

This is the main driver. It runs the complete pipeline end-to-end.

**Step 1 — Bootstrap check**
Check whether `docs/features/` contains any `.md` files.
- If **empty**: run the Feature Interview (see below) before proceeding.
- If **partial** (some features have no plan yet): offer the user a choice — complete the interview
  for remaining features first, or proceed with existing specs.
- If **complete**: skip to Step 2.

**Step 2 — Plan generation**
Run `references/scripts/pm-validate.ps1` first when present. If validation reports errors, stop and
surface them before mutating plans. If helpers are missing, perform the markdown checks manually.

Classify specs by frontmatter status before planning. Only specs with `status: approved` are
eligible. Report `draft`, `deprecated`, `implemented`, malformed, and dependency-blocked specs
separately with the next action for each.

For each eligible approved feature spec that does not yet have a matching plan in `docs/plans/`:
- Read the feature spec
- Build the `depends_on` graph first; skip specs with incomplete dependencies, missing dependency
  slugs, or dependency cycles
- Generate a phased plan (see plan template) and write it to `docs/plans/{feature-slug}-plan.md`
- Plans must include: phases, task list per phase, role/agent-type per task, expected outcome, and
  a status column (todo / in-progress / done / blocked)
- Plans should include explicit review/test tasks where implementation-heavy phases are known.

**Step 3 — Find next task**
Run `references/scripts/pm-next.ps1` when present and use its output as the deterministic first pass;
then verify any selected task against the current plan before writing files.

Scan eligible approved plans for the first task with status `todo`. Pick the highest-priority
incomplete task by dependency order, priority, phase, then feature slug. Skip tasks whose feature
dependencies are incomplete.

If no `todo` tasks remain: report "All plans complete." and stop.

**Step 4 — Write task file**
Create `docs/tasks/active/{feature-slug}-p{N}-t{M}.md` using the task file template. Include:
- The full task description and expected outcome from the plan
- Relevant context: feature spec excerpt, plan phase goals, any related completed tasks
- The completion sentinel instructions (agent must append a final `## Completion` block at the bottom)
- Claim metadata (`claimed_by`, `claimed_at`, `lease_expires_at`)
- Optional tracker fields (`external_issue`, `external_url`)
- Future parallelism fields, defaulting to serial execution (`parallel: false`)

Also create `docs/tasks/locks/{task-id}.lock.md` and `docs/tasks/logs/{task-id}.md` when those
directories exist. Claims are advisory coordination artifacts: expired leases are reported and
require an operator decision; they are not automatically deleted or stolen.

Update the plan: mark the task as `in-progress`.

**Step 5 — Select and spawn agent**
Map the task's `role` field to an agent type using this table:

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

Spawn the agent with the task file path and this instruction:
> "Read the task file at `{path}`. Perform all actions described. When complete, append a
> final `## Completion` sentinel to the task file exactly as specified in the template. Do not delete or
> modify any existing content above the sentinel."

**Step 6 — Monitor completion**
Poll the task file for a valid completion block. Ignore `## Completion Instructions`. A task is
complete only when the final `## Completion` heading has a parseable `Status:` field after it.

- Read the sentinel block for `Status:` field
- If **success**: parse `Artifacts:`, `Tests:`, and `Notes:`. If tests are failing, create
  corrective build/test work and do not mark the implementation final. If the task changed code and
  no matching verification task exists, insert a review/test task and mark the implementation
  `verification pending`. Mark work `done` only after required verification succeeds, archive the
  task file, log notes into the plan, then return to Step 3.
- If **failure**: enter the **Error Recovery Loop** (see below).
- If **blocked**: mark the plan task `blocked`, write a blocker issue in `docs/issues/`, archive the
  task with blocked status preserved, report the decision needed, and pause.
- If the sentinel is malformed or the active task is stale (older than 24 hours with no valid
  sentinel), report it and pause without changing plan state.

---

### Error Recovery Loop (up to 5 iterations)

When a task fails, do NOT retry the same task blindly. Instead:

1. Read the failure message from the sentinel's `Error:` field.
2. Diagnose the root cause — what is missing that would allow this task to succeed?
3. Add 1–3 corrective tasks to the plan *before* the failed task (or as prerequisites):
   - Give them role assignments appropriate to the correction needed
   - Mark the original failed task back to `todo`
4. Increment the failure counter on the plan (stored in a `failures:` frontmatter field).
5. If `failures` < 5: return to Step 3 (the corrective tasks will be picked up next).
6. If `failures` >= 5: **pause the loop**, write a detailed issue file to `docs/issues/`, report
   to the user what has been tried and ask how to proceed. Do not continue automatically.

---

### Verification Gate

Implementation, API, build, security, UI, backend/frontend/database, migration, refactor, cleanup,
and other code-changing tasks require verification before final completion. A plan task is not
final until a matching review/test/security/e2e task covering the same CAP-ID and artifacts succeeds.
If no such task exists, `/continue-tasks` inserts one after implementation success.

If a completion block reports `Tests: passing: false`, create corrective build/test work and do not
mark the implementation done.

---

### `/review-tasks` — Dry-Run Analysis (no agents spawned)

Produce a read-only status report. Do not modify any files.

If `references/scripts/pm-status.ps1`, `pm-blocked.ps1`, `pm-stale.ps1`, and `pm-validate.ps1` are
present, run them first and summarize their output. If they are unavailable, perform the markdown
scan below.

1. Count feature specs in `docs/features/`
2. Count plans in `docs/plans/` and identify specs missing a plan
3. Report spec statuses: draft, approved, implemented, deprecated, malformed
4. Report dependency blockers, missing dependency slugs, and dependency cycles
5. For each plan: count tasks by status (todo / in-progress / done / blocked)
6. List active task files in `docs/tasks/active/`, including stale or malformed completion blocks
7. List verification backlog and open issues in `docs/issues/`
8. Report claim/lease state from task frontmatter and `docs/tasks/locks/`, including expired leases
9. Report handoff readiness from `docs/workflow/FOCUS.md`, `docs/workflow/INDEX.md`, and recent
   `docs/tasks/logs/` entries
10. Report optional tracker sync coverage from `external_issue` / `external_url`
11. Output a structured markdown report showing:
   - Overall completion percentage
   - Per-feature progress table
   - Next recommended action

This command is safe to run at any time to get a project snapshot. It is read-only and does not
refresh `ROADMAP.md`; update the roadmap manually from the report if desired.

---

### `/update-tasks` — Sync Active Task Files

Use this when you suspect task agents have completed work but the plan hasn't been updated yet.

Run `references/scripts/pm-validate.ps1` before mutating plans when present. If validation reports
errors unrelated to the active completion being reconciled, surface them and avoid broad plan edits.

1. Read every file in `docs/tasks/active/`
2. For each file, check for a final `## Completion` sentinel with parseable `Status:`
3. If found:
   - Parse the `Status:`, `Summary:`, `Artifacts:`, `Tests:`, and `Notes:` fields
   - Apply success, failure, blocked, verification-pending, and failing-test rules from
     `/continue-tasks`
   - Archive reconciled task files
   - Release the matching lock and append a task-log summary
   - Leave malformed or stale files active and report them
4. Run `pm-validate.ps1` again when present and report any remaining warnings/errors.
5. Report what was updated and what still needs user or worker attention

This command is idempotent — safe to run multiple times.

---

### `/sync-tracker` — Optional External Tracker Mirror

Use only when the user wants GitHub issue visibility. It requires `gh auth status` to pass and keeps
local markdown authoritative. It creates or updates GitHub issues idempotently, records issue
identity in `external_issue` and `external_url`, and never imports remote changes into local
markdown without user approval. Detailed flow lives in `sub-skills/sync-tracker/SKILL.md`.

---

### `/analyze-parallelism` — Read-Only Future Parallelism Check

Serial execution remains the default. This command only analyzes whether todo tasks have enough
metadata for a future explicit parallel batch: `parallel`, `depends_on_tasks`, `conflicts_with`,
`files_allowed`, and `files_shared`. It does not spawn agents. Detailed flow lives in
`sub-skills/analyze-parallelism/SKILL.md`.

---

### `/reinit` — Archive Legacy State, Normalize Specs, Then Launch

Use when starting the orchestration loop on a project that has existing (possibly non-conforming)
plans, tasks, and feature specs — e.g., after manual planning work, importing legacy docs, or
recovering from an inconsistent state. Produces a clean slate conforming to the directory
conventions, then immediately runs `/continue-tasks`.

**Step 1 — Archive existing plans**
Move every file in `docs/plans/` (non-archive) to `docs/plans/archive/`. Create
`docs/plans/archive/` if it doesn't exist. If a filename collision would occur, prefix the
destination with today's date (`YYYY-MM-DD-`). Do not delete any files.

**Step 2 — Archive existing tasks**
Move every file currently in `docs/tasks/active/` to `docs/tasks/archive/`. Move any loose
task files sitting directly in `docs/tasks/` (not in a subdirectory) to `docs/tasks/archive/`
as well. Do not delete any files.

**Step 3 — Normalize feature specs**
For each `.md` file in `docs/features/` that is not `README.md` and not `template.md`:

1. Read the file in full.
2. Check whether it has the required YAML frontmatter block with all fields:
   `feature`, `slug`, `status`, `priority`, `area`, `depends_on`, `last_updated`.
3. Check whether it has all required sections:
   `## Overview`, `## Capabilities`, `## Requirements`, `## Acceptance Criteria`, `## Out of Scope`.
4. If **fully conforming**: mark as `ok`, skip.
5. If **non-conforming**: rewrite the file using the template structure. Rules:
   - **Never discard content.** Every sentence, table, list, code block, and edge-case note from
     the original must appear somewhere in the rewritten file.
   - Map existing content to the nearest matching section. If it doesn't fit cleanly into any
     required section, place it in a `## Notes` section at the bottom.
   - Infer missing frontmatter fields from the file's content and filename:
     - `slug` → derive from filename (strip `.md`)
     - `status` → look for a `Status` field in a `## Metadata` table or similar; default `draft`
     - `priority` → look for explicit priority signal; default `p2`
     - `area` → infer from the feature name or existing metadata
     - `depends_on` → look for dependency references in the text; default `[]`
     - `last_updated` → today's date
   - Keep the `## Capabilities` section as a checklist (`- [ ] ...`), promoting bullet lists
     from the original where needed.
   - Keep `## Acceptance Criteria` as Given/When/Then bullets where possible.
6. After rewriting, report the file as `normalized`.

Report a summary table when done:

| File | Result | Notes |
|------|--------|-------|
| auth.md | ok | already conforming |
| property-data-model.md | normalized | added frontmatter, remapped Metadata table |

**Step 4 — Launch**
Run `/continue-tasks` from Step 1 (bootstrap check).

---

## Feature Interview

Run this when `docs/features/` is empty or when new features need to be captured.

### Step 1 — Extract feature areas from the prompt
Read `docs/INITIAL_PROMPT.md`. Group the implied features into 3–6 functional areas (e.g., "Data
Models & Engine", "Onboarding & Profiles", "Dashboard & Logging", "Planner & Visualization",
"Recovery & Reminders"). List the areas to the user and ask if the grouping makes sense before
proceeding.

### Step 2 — Interview one area at a time
For each area, use the AskUserQuestion tool to collect:
- Which capabilities in this area are must-have vs. nice-to-have
- Any constraints or non-obvious requirements not captured in the prompt
- Acceptance criteria: what does "done" look like for this area?
- Known dependencies on other areas

After each area interview, immediately write the feature spec(s) to `docs/features/`. Do not batch
writes — specs are useful immediately and the user may stop at any time.

### Step 3 — Feature spec format
Read `references/feature-spec-template.md` for the exact format. Key fields:
- `status`: `draft` | `approved` | `implemented`
- `priority`: `p1` | `p2` | `p3`
- Capabilities list (what the feature can do)
- Requirements (must/should/may)
- Acceptance criteria (testable, binary pass/fail)
- Out-of-scope (explicit exclusions to prevent scope creep)

### Spec Authority Rule
Feature specs are the final authority on scope. They may only be changed by:
1. The user directly editing the file
2. An agent that has used AskUserQuestion to confirm the change with the user

Never silently update a spec during implementation to match what was built. If an implementation
diverges from a spec, pause and surface the discrepancy.

---

## Working Principles

**One task at a time.** The orchestration loop processes tasks serially. Parallel execution of tasks
in the same feature creates merge conflicts and makes failure harder to diagnose.

**Plans are living checklists.** A plan file is both the specification and the progress tracker.
When reading a plan, the status column tells you exactly where things stand.

**Task files carry full context.** An agent should be able to read only its task file and perform
the work correctly. Do not rely on agents having prior session context — embed all relevant excerpts
from specs and plans into the task file.

**Archive aggressively.** Completed task files move immediately to `archive/`. The `active/`
directory should contain at most one file per active work stream.

**Specs before plans, plans before tasks.** Never generate a task for a feature without an approved
spec. Never spawn an agent for a task that isn't in a plan. The pipeline flows in one direction.

---

## Pipeline Order

```
/init-project        →  scaffold the repo (docs/, AGENTS.md, hooks, PR template)
/init-features       →  capture feature specs from INITIAL_PROMPT.md
/add-feature         →  add a new spec at any later point
/analyze-features    →  audit specs for template/CAP-ID/plan-coverage gaps
/continue-tasks      →  generate plans, spawn agents, iterate
/update-tasks        →  reconcile active task files with plan statuses
/review-tasks        →  read-only progress snapshot
/sync-tracker        →  optional GitHub issue mirror; markdown stays authoritative
/analyze-parallelism →  read-only opt-in future parallel batch analysis
/reinit              →  archive legacy state, normalize, then run /continue-tasks
```

The first three commands are *one-time-per-feature* (or one-time-per-project); the rest are
*repeatable* and idempotent.

## Diagram

[View diagram](diagram.html)
