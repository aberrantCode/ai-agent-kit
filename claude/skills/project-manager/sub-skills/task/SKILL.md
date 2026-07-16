---
name: task
description: Express path for chore-task fast-lane — capture + materialize as chore in one shot for "I just need to fix this now". The construct that makes docs/tasks honored. Chore lane only; spec-authority guard re-asserts scope. Triggers on `/pm-task` and "just fix", "quick chore task".
---

# Task

Express lane for the "I just need to fix this now" case. Combines `/pm-capture` and `/pm-groom → materialize-as-chore` in one shot. Allocates a `BL-NNN` row, re-asserts spec authority (fails closed if the item touches product behavior), and materializes a chore task with a frozen authorization snapshot.

**Chore lane only.** Anything scope-changing is redirected to `/pm-capture` + `/pm-groom → feature`.

**Prerequisite:** The project must have been initialized with `/init-project`.

- `docs/backlog.md` — must exist
- `docs/workflow/scope-manifest.md` — must exist (the chore express lane is inert without it; the guard will reject any chore without an authorization snapshot)

If either is missing, stop and tell the user: "The chore express lane is inert until `docs/workflow/scope-manifest.md` exists. Run `/init-project` or `/reinit` to scaffold it, or run `/pm-capture` + `/pm-groom → feature` instead."

---

## Phase 1 — Gather the Item

Check whether the invocation contains meaningful item text (the thing being captured).

If **no text** was provided, use `AskUserQuestion` to ask:

> "What do you want to fix right now? Describe the bug, chore, or tech-debt (a few sentences is enough.)"

After receiving text, summarize it back to the user to confirm you understood it correctly before proceeding.

---

## Phase 2 — Infer Type, Area, and Priority

Examine the text to infer:

- **Type** ∈ {`bug`, `chore`, `debt`}
  - `bug` — a defect or regression
  - `chore` — mechanical, routine, or maintenance work
  - `debt` — refactoring, optimization, or technical-debt reduction
  - **Note:** `idea`-type items cannot use this express lane. Redirect to `/pm-capture` + `/pm-groom`.

- **Area** — a short system area or component name (e.g., `ui`, `api`, `infra`, `db`, `auth`, `discovery`). If unclear, ask via `AskUserQuestion`.

- **Priority** — one of `p0`, `p1`, `p2`, `p3`. Default to `p2` unless the text signals urgency.

---

## Phase 3 — Atomic ID Allocation

Follow the **lease pattern** from `/pm-capture` exactly:

### 3a — Check for an Existing Lock

Read `docs/backlog.lock` if it exists. If it is held (lease not expired), stop. If it is expired or missing, proceed.

### 3b — Acquire the Lock

Write `docs/backlog.lock` with:

```yaml
---
task: "backlog-capture"
feature: "intake"
claimed_by: "{{agent-or-user}}"
claimed_at: "{{ISO 8601 TIMESTAMP}}"
lease_expires_at: "{{ISO 8601 TIMESTAMP, 2 minutes from now}}"
status: active
reason: "task {{item-summary}}"
---
```

### 3c — Compute the Next ID

Scan both `docs/backlog.md` and `docs/backlog-archive.md` to find `max(all_ids)`. Increment by 1: `next_id = max + 1`. Format as zero-padded 3-digit: `BL-{{next_id}}`.

### 3d — Append the New Row to `docs/backlog.md`

```markdown
| {{BL-NNN}} | {{type}} | {{area}} | {{pri}} | open | {{item}} | |
```

### 3e — Release the Lock

Overwrite `docs/backlog.lock` with `status: released` or delete it.

---

## Phase 4 — Spec-Authority Re-Assertion (CRITICAL)

**Before materializing the chore task, re-examine the item:**

> "On reflection, does this change product behavior, user experience, or external-facing scope?"

If **yes** — STOP and redirect:

> "This touches product behavior. Use `/pm-capture` + `/pm-groom → feature` instead. The feature lane ensures spec review."

If **no** (purely internal/mechanical) — proceed.

---

## Phase 5 — Materialize the Chore Task

1. **Read the chore-task template:** Open `references/chore-task-file-template.md` and read it in full.

2. **Determine the chore area:** From the inferred area above.

3. **Create the task file:**

   - Path: `docs/tasks/active/chore-{{area}}-{{BL-NNN}}.md`
   - Copy the template content
   - Fill in the frontmatter:
     - `feature: "chore-{{area}}"`
     - `backlog_ref: "{{BL-NNN}}"`
     - `role:` — ask via `AskUserQuestion` if unclear
     - `agent:` — agent type (e.g., `refactor-cleaner`, `build-error-resolver`, or `general-purpose`)
     - `status: in-progress`
     - `covers: []` — capabilities this chore touches (can be empty)
     - `files_allowed: []` — glob patterns; ask via `AskUserQuestion` for scope
     - **FREEZE THE AUTHORIZATION SNAPSHOT:**
       - `scope_confirmed: false`
       - `authz_snapshot:`
         - `bl_type: "{{type}}"` — the inferred type from Phase 2 (bug|chore|debt)
         - `bl_status: "promoted"` — frozen copy of the BL row's status at promotion (always "promoted" when written here)
         - `manifest_sha: "{{sha256_of_scope_manifest}}"` — compute `Get-FileHash -Path docs/workflow/scope-manifest.md -Algorithm SHA256 | Select-Object -ExpandProperty Hash` NOW

4. **Fill the action plan:** Replace the example action items with concrete steps for this chore.

5. **Update the backlog row:**
   - Set `Status: promoted`
   - Set `Link: chore-{{area}}-{{BL-NNN}}` (the task id)

---

## Phase 6 — Report and Do Not Commit

Tell the user:

> "✓ Materialized `{{chore-{{area}}-{{BL-NNN}}}}`
>
> Backlog: `{{BL-NNN}}` — {{type}}, {{area}}, {{pri}}
>
> Authorization snapshot frozen (scope-manifest SHA256 recorded).
>
> Next: Claim the task and begin the action plan."

**Important:** Do NOT stage or commit. The user or orchestrator owns git.

---

## Completion Checklist

Verify before reporting done:

- [ ] `docs/backlog.md` and `docs/workflow/scope-manifest.md` exist (if not, user was directed to `/init-project`)
- [ ] Advisory lock acquired and released cleanly (no stale lock left behind)
- [ ] Next ID computed by scanning **both** `docs/backlog.md` **and** `docs/backlog-archive.md`
- [ ] New backlog row appended with: `Status: open`, empty `Link` column
- [ ] Type ∈ {`bug`, `chore`, `debt`} inferred; `idea` redirected to `/pm-capture` + `/pm-groom`
- [ ] **Spec-authority re-asserted:** Item reviewed for product-behavior impact; if yes, redirected to feature lane
- [ ] Chore task file created at `docs/tasks/active/chore-{{area}}-{{BL-NNN}}.md` with complete frontmatter
- [ ] `scope_confirmed: false` present in frontmatter
- [ ] `authz_snapshot:` block frozen with:
   - `bl_type` = inferred type (bug|chore|debt)
   - `bl_status: "promoted"`
   - `manifest_sha` = sha256 of `docs/workflow/scope-manifest.md` (computed NOW, not a placeholder)
- [ ] `files_allowed:` populated with scope globs
- [ ] Backlog row `Status: promoted`, `Link: chore-{{area}}-{{BL-NNN}}`
- [ ] **No commit made.** Rows are updated in files; user owns git.
