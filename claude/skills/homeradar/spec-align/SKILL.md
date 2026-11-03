---
name: homeradar-spec-align
description: Use when the user provides a HomeRadar feature spec name, filename, or topic and wants the codebase brought into full alignment with that spec — from gap analysis through implementation, tests, and merge to dev
---

# HomeRadar Spec Align

End-to-end workflow: find spec → gap analysis → plan → implement → ship → start app.

---

## Phase 0 — Find the Spec

**If the user gave a filename** (e.g. `authentication.md` or `docs/features/authentication.md`):
- Read that file directly.

**If the user gave a topic or subject** (e.g. "auth", "extension login"):
- Search `docs/features/` for specs whose title, overview, or capabilities section matches.
- If multiple match, present them with one-line summaries and ask the user which to target.
- If none match, stop and ask the user to confirm the spec path.

---

## Phase 1 — CAP-ID Check

Inspect the spec's Capabilities section. If any capability bullet lacks a `[XX-CAP-NN]` prefix:

1. Invoke **`homeradar-retro-fit-spec`** to add CAP-IDs.
2. Commit the retro-fit alone before any other work:
   ```
   docs: retro-fit CAP-IDs to <spec-name>.md
   ```
3. Continue once the retro-fit commit is made.

If all capabilities already have CAP-IDs, skip this phase.

---

## Phase 2 — Gate 1: Spec Approval

Check the spec's `Status` field.

| Status | Action |
|--------|--------|
| `Approved` or `In Progress` | Continue to Phase 3 |
| `Draft` or `In Review` | STOP — surface the spec to the user and ask them to set `Status: Approved` before continuing |
| `Implemented` or `Archived` | STOP — spec is closed; ask user to confirm they want to re-open it |
| Missing (no Status field) | Add the metadata table using `docs/features/template.md` as reference; STOP and ask user to set `Status: Approved` |

> You cannot self-approve Gate 1. Wait for the user to confirm before proceeding.

---

## Phase 3 — Gap Analysis

Read every capability row (each `[XX-CAP-NN]` bullet) and every Acceptance Criteria row in the spec.
For each, determine its implementation state by searching the codebase.

**Search strategy per capability:**

1. **Test coverage** — grep `api/tests/`, `web/src/__tests__/`, `extension/src/__tests__/` for the CAP-ID string or a test name/description that maps to the AC.
2. **Implementation files** — check the modules named in the spec's Components section for the relevant logic.
3. **Use cases and edge cases** — for behavioral requirements (UI guards, CTA suppression, sync events), scan the referenced source files for the described behavior.

**Classify each capability:**

| State | Criteria |
|-------|----------|
| ✅ Implemented | Named test exists AND passes; implementation logic present in the expected module |
| ⚠️ Partial | Implementation exists but has no test, or test exists but logic is incomplete/incorrect |
| ❌ Missing | No test and no implementation found |

**Output a gap table:**

```
| CAP-ID     | Capability (short)                    | State          | Notes                          |
|------------|---------------------------------------|----------------|--------------------------------|
| AU-CAP-01  | User registration                     | ✅ Implemented  |                                |
| AU-CAP-07  | Cross-surface auth sync (web→ext)     | ❌ Missing      | No storage.onChanged listener  |
| AU-CAP-09  | Unauthenticated UI guard ("Sign out") | ⚠️ Partial      | Logic present, no test         |
```

If everything is ✅ Implemented, stop here and tell the user the spec is fully aligned — no plan needed.

---

## Phase 4 — Write the Implementation Plan

For every capability that is ⚠️ Partial or ❌ Missing, write a B-style task contract.

**Save to:** `docs/plans/YYYY-MM-DD-<spec-slug>-align-impl.md`

Each task must follow this exact format (from `docs/workflow/SDLC.md` Phase 2):

```markdown
### Task N: <imperative title>

**CAP-ID:** XX-CAP-NN
**Files (modify):** path/to/file.py, path/to/test_file.py
**Files (create):** path/to/new_file.py   ← omit if none
**Test:** test_function_name_exactly_as_written
**Done when:** named test passes + AC row [XX-CAP-NN] checked off in spec

#### Steps
1. Write failing test `test_function_name_exactly_as_written`
2. <concrete implementation step>
3. Verify test passes
```

**Task ordering:** schema/model changes → service/route changes → extension changes → web UI changes.

**Every P0 capability gap must have at least one task. Every task maps to exactly one CAP-ID.**

---

## Phase 5 — Gate 2: Plan Approval

Present the gap table and the implementation plan to the user.

Ask:
```
AskUserQuestion(
  questions: [{
    question: "Gap analysis and implementation plan are ready. Approve the plan to begin implementation?",
    header: "Gate 2 — Plan Approval",
    options: [
      { label: "Approved — begin implementation", description: "I'll create a worktree and start Phase 6" },
      { label: "Revise the plan first", description: "Tell me what to change" },
      { label: "Stop here", description: "I'll implement manually later" }
    ]
  }]
)
```

> Do not write any implementation code until the user explicitly approves.

---

## Phase 6 — Implementation

Once plan is approved:

1. **Create worktree** off latest `dev`:
   ```bash
   git fetch origin
   git worktree add .worktrees/feat/align-<spec-slug> -b feat/align-<spec-slug> origin/dev
   ```

2. **Update spec status** to `In Progress` in the spec file. Commit:
   ```
   docs: set authentication.md Status → In Progress
   ```

3. **Work each task in plan order** using strict TDD:
   - **RED:** Write the named failing test first. Commit: `test: scaffold [XX-CAP-NN] <description>`
   - **GREEN:** Write minimal implementation to pass. Commit:
     ```
     feat(<scope>): <description>

     Refs: XX-CAP-NN
     Spec: docs/features/<spec-name>.md
     ```
   - Check off the corresponding AC row in the spec after each GREEN.
   - Do not start the next task until the current test is green.

4. **Never skip the RED step.** A commit touching feature code without `Refs: XX-CAP-NN` is a policy violation — do not push it.

---

## Phase 7 — Pre-PR Gate

Invoke **`homeradar-pre-pr`** and work through all three gates:
- Gate 1: Full test suite for all touched stacks
- Gate 2: Lint + type-check, zero new errors
- Gate 3: Every commit has a `Refs:` line; no `console.log`; PR description includes Spec Coverage table

Do not proceed to Phase 8 until all three gates pass.

---

## Phase 8 — Ship to Dev

Invoke **`ship-to-dev`** from the worktree.

The PR description **must** include a Spec Coverage section:

```markdown
## Spec Coverage
| CAP-ID | Capability | AC Rows | Tests |
|--------|-----------|---------|-------|
| AU-CAP-07 | Cross-surface auth sync (web→ext) | AC-3, AC-4 | test_storage_sync_on_login, test_storage_cleared_on_logout |
```

After the PR merges to `dev`, update the spec `Status` to `Implemented`:
```
docs: set <spec-name>.md Status → Implemented
```
Commit this directly to `dev` after the merge.

---

## Phase 9 — Start App

After the merge and status update, run the start-app script to verify the stack comes up cleanly with the aligned implementation:

```bash
pwsh -NonInteractive -File scripts/Start-App.ps1
```

Report the result to the user. If any service fails to start, diagnose before declaring success.

---

## Quick Reference

```
0.  Find spec (filename or topic search)
1.  Retro-fit CAP-IDs if missing        → homeradar-retro-fit-spec
2.  Gate 1: Status = Approved           → human sets this; STOP if not
3.  Gap analysis                        → classify each CAP-ID: ✅ / ⚠️ / ❌
    (skip phases 4-9 if all ✅)
4.  Write plan                          → docs/plans/YYYY-MM-DD-<slug>-align-impl.md
5.  Gate 2: Plan approved               → AskUserQuestion; STOP until approved
6.  Implement                           → worktree + TDD per task + spec ACs checked off
7.  Pre-PR gate                         → homeradar-pre-pr (all 3 gates)
8.  Ship to dev                         → ship-to-dev + Spec Coverage table
9.  Start app                           → pwsh scripts/Start-App.ps1
```

---

## Hard Rules

- **Never self-approve Gate 1 or Gate 2.** Both require explicit user confirmation.
- **Never write implementation code before Gate 2 passes.**
- **Never skip the RED (failing test) step** for any task.
- **Every implementation commit must have `Refs: XX-CAP-NN`** — no exceptions.
- **Retro-fit commits must be isolated** — never bundled with implementation commits.
- **If start-app fails, do not declare success.** Diagnose the failure first.
