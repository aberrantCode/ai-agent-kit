---
name: retro
description: Systematic close-out learning harvest — collects archived task Notes/Handoff fields and resolved issues into the workflow ledger with idempotent dedup. Triggers on `/pm-retro`, "retro", "harvest learnings", "close-out digest".
---

# Retro

Systematic close-out learning harvest. Collects Notes and Handoff fields from archived task files and resolution summaries from resolved issues, then appends them to the workflow learning ledger with a dedup contract ensuring idempotency.

**Prerequisite:** The project must have been initialized with `/init-project` (or equivalent manual scaffolding). Specifically, this skill assumes:

- `docs/workflow/INDEX.md` — durable learning ledger (created by `/init-project`)

If missing, stop and tell the user to run `/init-project` first.

---

## Scope Note (Read-Mostly)

Retro NEVER modifies specs, plans, or task files. It only appends to `docs/workflow/INDEX.md`. It never stages or commits.

---

## Phase 1 — Scope the Harvest

Accept an optional `feature-slug` argument to narrow the scope. If provided, harvest only archived task files for that feature. If no argument, harvest all archived tasks plus any recent task files and all resolved issues.

Identify the source files:
- **Archived task files:** `docs/tasks/archive/*.md` (tasks that have been completed and archived)
- **Resolved issues:** `docs/issues/*.md` with `status: resolved` or `status: closed` or `status: accepted`

Record the list of candidates before proceeding.

---

## Phase 2 — Extract Learnings

For each archived task file, locate the `## Completion` block. From that block, pull:
- **`Notes:`** field — implementation/technical findings from the task
- **`Handoff:`** field — handoff notes, cross-feature decisions, or operational insights

For each resolved issue file, pull its resolution summary (usually in a `## Resolution` or closing comment section).

Each candidate learning gets a **stable dedup key** in the format:
```
{completion-date or issue-date} + {task-id or issue-id}
```

For example:
- Task `docs/tasks/archive/task-001.md` with completion date `2026-07-15` → key: `2026-07-15 + task-001`
- Issue `docs/issues/issue-042.md` with resolved date `2026-07-14` → key: `2026-07-14 + issue-042`

---

## Phase 3 — Dedup Against the Existing Ledger (CRITICAL)

Read `docs/workflow/INDEX.md` in full. For each candidate learning:
- Check the `## Discoveries` table: if its stable key (task-id or issue-id) already appears in the `Links` column, SKIP it.
- Check the `## Cross-Feature Notes` table: if its stable key already appears in the `Links` column, SKIP it.

**`/pm-retro` MUST be idempotent.** Running it twice appends nothing the second time. If `continue-tasks` already logged the same task-id/issue-id in a `Links` cell, that learning is already captured and must not be duplicated.

---

## Phase 4 — Append the Dated Digest

For each new (non-deduplicated) learning, append a row to the appropriate table in `docs/workflow/INDEX.md`:

### For Technical/Implementation Findings (from task `Notes:` fields):

Append to the `## Discoveries` table:
```
| {completion-date} | {finding from Notes field (1-2 sentences, concise)} | {impact on future work or known limitation} | {task-id} |
```

### For Cross-Feature Decisions/Handoffs (from task `Handoff:` fields):

Append to the `## Cross-Feature Notes` table:
```
| {completion-date} | {note from Handoff field (1-2 sentences, concise)} | {feature name or component affected} | {task-id} |
```

Keep entries concise — one or two sentences max. The `Links` column preserves the stable key for future dedup.

---

## Phase 5 — Report, Do Not Commit

Summarize:
- How many learnings were harvested from archived tasks and resolved issues
- How many were skipped as duplicates (already in the INDEX.md ledger)
- How many new rows were appended (split by Discoveries vs. Cross-Feature Notes)

Example output:
> "Harvested 8 learnings from 4 archived tasks and 2 resolved issues.
> Skipped 1 (already logged by continue-tasks).
> Appended 5 new Discoveries and 2 new Cross-Feature Notes to the workflow ledger."

**Important:** Do NOT stage or commit. The user or orchestrator owns git. The rows are now in `docs/workflow/INDEX.md` and ready for review.

---

## Completion Checklist

Verify before reporting done:

- [ ] `docs/workflow/INDEX.md` exists (if not, user was directed to `/init-project`)
- [ ] Identified archived task files in `docs/tasks/archive/*.md` and resolved issues in `docs/issues/*.md`
- [ ] Extracted `Notes:` and `Handoff:` fields from archived task `## Completion` blocks
- [ ] Created stable dedup keys for each candidate: `{date} + {task-id or issue-id}`
- [ ] Read `docs/workflow/INDEX.md` in full and checked `Links` columns for existing keys
- [ ] Deduplicated against existing ledger (skipped rows already present)
- [ ] Appended new learnings to correct tables: technical findings → Discoveries, handoffs → Cross-Feature Notes
- [ ] Kept entries concise (1-2 sentences max)
- [ ] Reported counts: harvested, skipped, appended
- [ ] **No commit made.** Rows are live; user owns git.
