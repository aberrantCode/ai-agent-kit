---
name: project-manager
description: >
  Automated project implementation orchestrator that drives feature-driven development from a single
  initial prompt through to completed code. Manages the full lifecycle: extracting feature specs via
  interview, generating phased implementation plans, delegating tasks to worker agents, monitoring
  completion sentinels, recovering from failures, and archiving finished work — all driven by
  markdown files that act as shared state.
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
  guides/                    # Supporting docs, architecture notes (optional)
  issues/                    # Logged failures and blockers
```

Read `references/feature-spec-template.md`, `references/plan-template.md`, and
`references/task-file-template.md` for the exact file formats to use.

---

## Commands

### `continue-tasks` — Full Orchestration Loop

This is the main driver. It runs the complete pipeline end-to-end.

**Step 1 — Bootstrap check**
Check whether `docs/features/` contains any `.md` files.
- If **empty**: run the Feature Interview (see below) before proceeding.
- If **partial** (some features have no plan yet): offer the user a choice — complete the interview
  for remaining features first, or proceed with existing specs.
- If **complete**: skip to Step 2.

**Step 2 — Plan generation**
For each feature spec that does not yet have a matching plan in `docs/plans/`:
- Read the feature spec
- Generate a phased plan (see plan template) and write it to `docs/plans/{feature-slug}-plan.md`
- Plans must include: phases, task list per phase, role/agent-type per task, expected outcome, and
  a status column (todo / in-progress / done / blocked)

**Step 3 — Find next task**
Scan all plan files for the first task with status `todo`. Pick the highest-priority incomplete
task (earlier phase > earlier feature alphabetically).

If no `todo` tasks remain: report "All plans complete." and stop.

**Step 4 — Write task file**
Create `docs/tasks/active/{feature-slug}-p{N}-t{M}.md` using the task file template. Include:
- The full task description and expected outcome from the plan
- Relevant context: feature spec excerpt, plan phase goals, any related completed tasks
- The completion sentinel instructions (agent must write `## Completion` at the bottom)

Update the plan: mark the task as `in-progress`.

**Step 5 — Select and delegate agent**
Map the task's `role` field to a worker type using this table:

| Role | Worker Type |
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

Delegate to a worker agent by providing the task file path and this instruction:
> "Read the task file at `{path}`. Perform all actions described. When complete, append a
> `## Completion` sentinel to the task file exactly as specified in the template. Do not delete or
> modify any existing content above the sentinel."

**Step 6 — Monitor completion**
Poll the task file for the presence of a `## Completion` heading. When found:

- Read the sentinel block for `Status:` field
- If **success**: archive the task file (move to `docs/tasks/archive/`), update plan task to `done`,
  log any notes from the sentinel into the plan, then return to Step 3.
- If **failure**: enter the **Error Recovery Loop** (see below).

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

### `continue-new-session` — Generate a Session-Handoff Prompt

Use when the user wants to pause this session and resume the recommended next action in a brand new
session (typically because the current context is getting long or they want to switch runtime).

Read-only. Produces a single copy-ready Markdown code block the user can paste into a fresh session.

**Step 1 — Locate the recap-recommended next action**
Scan your own most recent assistant turn for an explicit "next step" / "next" / "follow-up"
recommendation in its recap. Capture: the action verb + object, the plan/feature/task identifier
if mentioned, and any follow-on guidance.

**Step 2 — Resolve file paths**
For each identifier, resolve (without reading full content): feature spec at `docs/features/{slug}.md`,
plan at `docs/plans/{slug}-plan.md`, active task at `docs/tasks/active/{slug}-p{N}-t{M}.md` (if it
exists). Also include `docs/workflow/FOCUS.md` and `docs/workflow/INDEX.md` when present. Capture a
2–3 line excerpt of each. Note any path that does not exist.

**Step 3 — Emit the prompt**
Print a single fenced Markdown code block with: the recap-recommended action restated as an
imperative, the project pointers (with excerpts), the work pointers (with excerpts), explicit
instructions for the new session (read pointers in full, follow project-manager conventions, only
one active task at a time, append `## Completion` sentinel when done, never edit specs without user
confirmation), and constraints (stay on current branch, do not regenerate existing plans, do not
skip verification).

**Fallback** — if no recap recommendation exists (e.g., first turn of the session), derive a
substitute from `docs/workflow/FOCUS.md`, then from the first unblocked `todo` task in the
highest-priority approved feature's plan. Prefix the prompt's action line with
`(derived from {source})` so the receiving session knows the provenance. If no candidate exists,
print "No recap recommendation found and no eligible next task exists. Run `review-tasks` for a
project snapshot or `init-features` if specs are missing." and stop without emitting a prompt block.

Never modify project state. Never embed full file contents — paths plus 2–3 line excerpts only.

---

### `review-tasks` — Dry-Run Analysis (no agents spawned)

Produce a read-only status report. Do not modify any files.

1. Count feature specs in `docs/features/`
2. Count plans in `docs/plans/` and identify specs missing a plan
3. For each plan: count tasks by status (todo / in-progress / done / blocked)
4. List any active task files in `docs/tasks/active/`
5. List any open issues in `docs/issues/`
6. Output a structured markdown report showing:
   - Overall completion percentage
   - Per-feature progress table
   - Next recommended action

This command is safe to run at any time to get a project snapshot.

---

### `update-tasks` — Sync Active Task Files

Use this when you suspect task agents have completed work but the plan hasn't been updated yet.

1. Read every file in `docs/tasks/active/`
2. For each file, check for a `## Completion` sentinel
3. If found:
   - Parse the `Status:` and `Summary:` fields
   - Update the corresponding plan task status
   - Archive the task file
   - Log any notes
4. Report what was updated

This command is idempotent — safe to run multiple times.

---

### `reinit` — Archive Legacy State, Normalize Specs, Then Launch

Use when starting the orchestration loop on a project that has existing (possibly non-conforming)
plans, tasks, and feature specs — e.g., after manual planning work, importing legacy docs, or
recovering from an inconsistent state. Produces a clean slate conforming to the directory
conventions, then immediately runs `continue-tasks`.

**Step 1 — Archive existing plans**
Move every file in `docs/plans/` (non-archive) to `docs/plans/archive/`. Create
`docs/plans/archive/` if it doesn't exist. If a filename collision would occur, prefix the
destination with today's date (`YYYY-MM-DD-`). Do not delete any files.

**Step 2 — Archive existing tasks**
Move every file currently in `docs/tasks/active/` to `docs/tasks/archive/`. Move any loose
task files sitting directly in `docs/tasks/` (not in a subdirectory) to `docs/tasks/archive/`
as well. Do not delete any files.

**Step 3 — Audit feature specs (report by default)**

Reinit is recovery tooling. Mass-rewriting specs in place is surprising and hard to undo,
so this step audits and reports first, and only rewrites with explicit user consent.

For each `.md` file in `docs/features/` that is not `README.md` and not `template.md`:

1. Read the file in full.
2. Check whether it has the required YAML frontmatter block with all fields:
   `feature`, `slug`, `status`, `priority`, `area`, `depends_on`, `last_updated`.
3. Check whether it has all required sections:
   `## Overview`, `## Capabilities`, `## Requirements`, `## Acceptance Criteria`, `## Out of Scope`.
4. Classify each file as `ok` (fully conforming) or `non-conforming`, and record the specific
   gaps (missing frontmatter fields, missing sections) for the report.

Do **not** rewrite anything yet. Print the audit table:

| File | Result | Missing frontmatter | Missing sections |
|------|--------|---------------------|------------------|
| auth.md | ok | — | — |
| property-data-model.md | non-conforming | `priority`, `area` | `## Out of Scope` |

If every spec is `ok`, continue to Step 4.

If one or more specs are `non-conforming`, ask the user how to proceed. Default
(first / recommended) option must be `report-only`:

- **report-only** — leave all specs untouched and continue to Step 4. Downstream
  `continue-tasks` only operates on `status: approved` specs, so non-conforming specs are
  effectively quarantined until the user fixes them.
- **rewrite-selected** — present the list of non-conforming files and let the user pick which
  ones to normalize using the rules below.
- **rewrite-all** — normalize every non-conforming spec using the rules below.

Only files explicitly selected by the user are rewritten. `ok` files are never rewritten.

Normalization rules (apply only to user-selected rewrites):

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

Report a final summary table that reflects the actual disposition of each spec:

| File | Result | Notes |
|------|--------|-------|
| auth.md | ok | already conforming |
| property-data-model.md | normalized | user-selected rewrite; added frontmatter, remapped Metadata table |
| legacy.md | reported only | non-conforming; user opted not to rewrite |

**Step 4 — Launch**
Run `continue-tasks` from Step 1 (bootstrap check).

---

## Feature Interview

Run this when `docs/features/` is empty or when new features need to be captured.

### Step 1 — Extract feature areas from the prompt
Read `docs/INITIAL_PROMPT.md`. Group the implied features into 3–6 functional areas (e.g., "Data
Models & Engine", "Onboarding & Profiles", "Dashboard & Logging", "Planner & Visualization",
"Recovery & Reminders"). List the areas to the user and ask if the grouping makes sense before
proceeding.

### Step 2 — Interview one area at a time
For each area, use interactive prompts to collect:
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
2. An agent that has confirmed the change with the user via an interactive prompt

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
spec. Never delegate an agent for a task that isn't in a plan. The pipeline flows in one direction.
