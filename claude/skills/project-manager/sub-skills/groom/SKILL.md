---
name: groom
description: Triage and promotion — the moment the feature-vs-chore lane is decided. Asks "does this change product scope?" and offers per-item: promote-to-feature (for ideas), materialize-as-chore-task (with spec-authority guard), merge-into-plan, or close. Triggers on `/pm-groom`, "groom the backlog", "triage BL-###", "promote this item".
---

# Groom

Triage and promotion. Decides which lane (feature vs. chore) an item belongs to. Accepts both backlog items (`BL-NNN`) and homeless issues (`docs/issues/*.md`). For each, asks the pivotal question and offers four outcomes. Never commits.

**Prerequisite:** The project must have been initialized with `/init-project`.

- `docs/backlog.md` — must exist
- Optional: `docs/issues/` — directory of homeless issues

---

## Phase 1 — Load the Item

Check the invocation for an argument. Accept either:

- A **backlog id**: `BL-NNN` (e.g., `BL-042`)
- An **issue path**: `docs/issues/something.md`

If **no argument** is provided, use `AskUserQuestion` to ask the user to pick from:

- (a) An open backlog row (`Status: open`) — list the top 5 by priority
- (b) A homeless open issue in `docs/issues/` — list the top 5 by modification time

### 1a — Load a Backlog Row

If a `BL-NNN` id is given:

1. Read `docs/backlog.md`
2. Find the row with that ID
3. Extract: Type, Area, Priority, Status, Item, Link

If the row's `Status` is not `open`, tell the user:

> "Backlog row {{BL-NNN}} has `Status: {{status}}`. Only open rows can be groomed. Check `/pm-status` for current state."

Stop and do not proceed.

### 1b — Load an Issue

If an issue path is given (e.g., `docs/issues/avatar-404.md`):

1. Read the file
2. Extract the title/summary and any key details

### 1c — Summarize Back

Summarize the loaded item back to the user:

> "**{{BL-NNN | issue-name}}**
>
> {{type}}, {{area}}, {{priority}} (if backlog row)
>
> {{item-text or issue-summary}}"

---

## Phase 2 — Decide the Lane

Use `AskUserQuestion` to ask the **pivotal question**:

> "Does this item change product scope or behavior, or is it purely internal/mechanical?
>
> - **Yes (scope/behavior change)** → promote to feature (or merge into a feature plan)
> - **No (internal/mechanical only)** → materialize as a chore task
> - **Not sure** → I can help you think it through
> - **Neither — close it** → mark done or wontfix"

Based on the response, proceed to the appropriate phase below.

---

## Phase 3 — Execute the Chosen Outcome

### Option A: Promote to Feature

**For ideas or new capabilities that warrant their own feature spec.**

1. Invoke `/add-feature` and seed it with the captured text:
   > "Create a feature spec for: {{item-text}}"

2. Allow the user to complete the full feature spec following the `/add-feature` flow (requirements gathering, overlap detection, spec creation, etc.).

3. Once the feature spec is created at `docs/features/{{feature-slug}}.md`:
   - If this came from a backlog row: Set the row's `Status: promoted` and fill the `Link` column with the feature slug (e.g., `→ feature-slug`).
   - If this came from an issue: Move the issue to `docs/issues/archive/` or mark it `promoted_to: feature-slug`. (Details depend on your issue-archival convention.)

**Note on ideas:** An `idea`-type backlog row can ONLY go this route. It may never be materialized as a chore task (ideas are not mechanical work).

---

### Option B: Materialize as a Chore Task

**For genuine bugs, chores, or tech-debt — internal/mechanical only.**

**SPEC-AUTHORITY RE-ASSERTION (CRITICAL):**

Before writing any chore task file, re-examine the item. Ask yourself:

> "On reflection, does this change product behavior, user experience, or external-facing scope?"

If the answer is **yes**, STOP. Route it to **promote-to-feature** instead. Do NOT let a mis-triaged chore bypass spec review. Surface this explicitly:

> "On review, this appears to touch product behavior. Route to /add-feature instead of materializing as a chore."

If the answer is **no** (it is purely internal/mechanical), proceed:

1. **Read the chore-task template:** Open `references/chore-task-file-template.md` and read it in full.

2. **Determine the chore area:** From the backlog row or issue, extract the `area` (e.g., `ui`, `api`, `infra`).

3. **Create the task file:**

   - Path: `docs/tasks/active/chore-{{area}}-{{BL-NNN}}.md`
   - Copy the template content
   - Fill in the frontmatter:
     - `feature: "chore-{{area}}"` (chore-ui, chore-api, etc.)
     - `backlog_ref: "{{BL-NNN}}"`
     - `role:` — person or role owning this (ask via `AskUserQuestion` if unclear)
     - `agent:` — agent type (e.g., `refactor-cleaner`, `build-error-resolver`, or `general-purpose`)
     - `status: in-progress` (you are starting it now; if future work, use appropriate status)
     - `covers: []` — list any capabilities this chore touches (if known; can be empty)
     - `files_allowed: []` — glob patterns of files this chore may modify (ask via `AskUserQuestion` for scope)
   - Leave `authz_snapshot` commented out for now (see build-sequencing note below)

4. **Fill the action plan:** Replace the example action items with concrete steps for this chore.

5. **Record what the chore may modify:** Populate `files_allowed` (e.g., `["src/ui/**/*.tsx"]`).

6. **Update the backlog row:**
   - Set `Status: promoted`
   - Set `Link: chore-{{area}}-{{BL-NNN}}` (the task id)

**Build Sequencing & Authorization Snapshot:**

The frozen `authz_snapshot` field (containing `bl_type`, `bl_status`, `manifest_sha`, and `files_allowed`) is written by the guard-enforcement build step AFTER `docs/workflow/scope-manifest.md` is created. Until the scope-manifest and machine guard exist, the chore lane is inert — the authorization guard is not yet enforcing.

**If `docs/workflow/scope-manifest.md` exists:**
  - Include the `authz_snapshot:` block in the frontmatter (populated by the build-enforcement step later)
  - Document this in the task file: "Authorization enforced by scope-manifest guard at build time."

**If `docs/workflow/scope-manifest.md` does NOT exist:**
  - Omit `authz_snapshot:` for now
  - Add a note: "When docs/workflow/scope-manifest.md is created, this chore's authorization will be frozen and enforced at build time."

---

### Option C: Merge Into Plan

**For items that are part of an existing feature plan.**

1. Identify the feature and plan phase. Use `AskUserQuestion` to ask:
   > "Which feature plan should this become part of? (List active features and their plan phases.)"

2. Open the plan file: `docs/plans/{{feature-slug}}-plan.md`

3. Append a task row to the appropriate phase, matching the plan's existing column format — `| # | Task | Covers | Role | Status | Notes |` — with a fresh phase-local task number and status `todo` (plan rows use `todo`, not the backlog's `open`). Reference the backlog id in Notes:
   ```markdown
   | {{next-#}} | {{description}} | {{covers or —}} | {{role}} | todo | from {{BL-NNN}} |
   ```

4. Update the backlog row:
   - Set `Status: promoted`
   - Set `Link:` to the plan phase reference (e.g., `→ feature-slug-plan P2`)

---

### Option D: Close

**For duplicates, wontfix, or genuinely resolved items.**

1. Use `AskUserQuestion` to confirm the close reason:
   > "Why close this? Choose one:
   >  - (a) Duplicate (merge into another item)
   >  - (b) Wontfix (rejected, no plans to address)
   >  - (c) Done (already fixed/implemented)"

2. Update the backlog row:
   - Set `Status: done` or `Status: wontfix` (per your choice)
   - Clear or update the `Link` column if needed

---

## Phase 4 — Report and Do Not Commit

Tell the user the outcome:

> "✓ Groomed {{BL-NNN | issue-name}}.
>
> **Outcome:** {{option-chosen}} → {{destination}}
>
> **Updated row:** `Status: {{new-status}}`"

**Important:** Do NOT stage or commit. The user or orchestrator owns git.

---

## Completion Checklist

Verify before reporting done:

- [ ] `docs/backlog.md` exists
- [ ] Item loaded (backlog row or issue); summarized back to user
- [ ] Pivotal question asked and answered
- [ ] Chosen outcome executed fully:
  - [ ] **Promote-to-feature**: `/add-feature` invoked; feature spec path recorded in backlog `Link`
  - [ ] **Materialize-as-chore**: Spec-authority re-asserted BEFORE writing chore file; chore task file created with complete frontmatter and action plan; backlog row updated with `Link`
  - [ ] **Merge-into-plan**: Plan identified; task row appended to plan phase; backlog row updated
  - [ ] **Close**: Close reason confirmed; backlog row status set to `done` or `wontfix`
- [ ] Backlog row `Status` updated appropriately (`promoted` or `done`/`wontfix`)
- [ ] **No commit made.** Rows are updated in the file; user owns git.
