---
name: sync-status
description: Regenerate the generated sections of docs/STATUS.md (progress table + outstanding-work list) from the canonical specs/plans/tasks/issues, preserving the curated sections. The single-source-of-truth writer for the outstanding-work tracker.
---

# Sync Status

Regenerate `docs/STATUS.md` — the single entry point for "what is outstanding, and
what should happen next?". This skill is the **writer**; `/review-tasks` is the
read-only reporter that computes the same view without persisting it.

**Write scope: `docs/STATUS.md` only.** Never modify specs, plans, task files, or
issues — those are the canonical sources this view is derived from. `docs/STATUS.md`
is a *view*, not a source; the only sections it owns canonically are the curated ones
(see below).

## The file's contract

`docs/STATUS.md` has four content sections wrapped in HTML-comment fences:

| Section | Fence | Ownership |
|---|---|---|
| §1 Next action & run state | `pm:curated:runtime` | **CURATED** — preserve verbatim |
| §2 Progress by feature | `pm:generated:progress` | **GENERATED** — rewrite |
| §3 Outstanding work | `pm:generated:outstanding` | **GENERATED** — rewrite |
| §4 Unowned / cross-cutting backlog | `pm:generated:backlog` or `pm:curated:backlog` | **GENERATED** (when `docs/backlog.md` exists) or **CURATED** (when absent) — see below |

**Ownership of §4 depends on adoption:**
- If `docs/backlog.md` is present, §4 uses fence `pm:generated:backlog` and is **regenerated** from open backlog rows + homeless open issues.
- If `docs/backlog.md` is absent, §4 falls back to fence `pm:curated:backlog` and is **preserved verbatim** (backward-compatible, as today).
- An optional `pm:curated:notes` fence, if present, is always preserved byte-for-byte regardless of mode.

**Rewrite only the content between the two `pm:generated:*` fences. Never touch the
content between `pm:curated:*` fences** — those hold the orchestrator's next-action
(§1), and in fallback mode, human-curated unowned items (§4). Losing them is data loss.

If `docs/STATUS.md` does not exist, scaffold it: copy the section skeleton (all five
`##` headings + both fence pairs), leave §1 with a single "no active run" line and §4
empty, then generate §2/§3.

## Inputs (read-only)

- `docs/features/*.md` — frontmatter `status`, `priority`, `slug`, `depends_on` (exclude `README.md`, `template.md`)
- `docs/plans/*.md` — frontmatter `status` + phase headings + task-row `Status` values (exclude `README.md`, `archive/`)
- `docs/tasks/active/*.md` — in-flight work orders (for the "in-progress" marker, `assignee:` field if present)
- `docs/issues/*.md` — frontmatter/first-line `Status:`; an issue is open unless it says accepted/closed/resolved
- `docs/backlog.md` — optional intake store; when present, triggers generated §4 (may be absent for backward-compatibility)
- `docs/backlog-archive.md` — archive of completed backlog items; used for BL-id uniqueness validation across live + archive
- `docs/STATUS.md` — the current file, to preserve its curated fences

If `references/scripts/pm-status.ps1` exists, prefer it for the §2 counts; otherwise
do the markdown scan below.

## Step 1 — Generate §2 Progress by feature

One row per feature (join spec ↔ plan by slug). Columns:

`| Feature | Spec (status) | Plan (status) | Phases done / total | Open tasks | Next task |`

- **Phases done / total**: a phase is "done" when all its task rows are `done`. Count `### Phase` headings for the total.
- **Open tasks**: count plan task rows whose `Status` is `todo`, `in-progress`, `blocked`, or `deferred`. Include deferred rows inside `done` plans (report them as "(deferred)" / "(tech-debt)").
- **Next task**: the lowest-numbered `todo` row whose earlier-phase tasks and feature dependencies are complete.
- Sort: in-progress plans first (by open-task count, descending), then `done` plans with residual rows, then `implemented`/reference-only features.
- End with a one-line rollup: N features in active development (M open tasks); K reference-only.

Spec `status` is **scope maturity**, not runtime — do not editorialise it into "shipped".

## Step 2 — Generate §3 Outstanding work

Group by feature; under each, one bullet per open plan row: `**P<n>T<m>** — <task text>. *(AC refs)*`. Link the feature heading to its plan.

- Include the analysis-plan Deferred rows and any tech-debt rows living inside `done` plans.
- When a plan row or its active task carries an `assignee:`, annotate the item (e.g. `— @handle`) so §3 shows who owns in-flight work.
- Add a final `### Open issues` subsection: one bullet per `docs/issues/*.md` whose status is open, linking the file. An issue's canonical home is its own file — surface it, don't restate it.
- Do **not** invent items: everything in §3 must trace to a real plan row or issue. Items with no plan/issue home belong in the generated §4 — never fabricate a §3 entry for them.

## Step 3 — Generate §4 Unowned / cross-cutting backlog (when `docs/backlog.md` is present)

**Prerequisite check — BL-id uniqueness (fail-closed).** Before generating §4, scan both `docs/backlog.md` (if present) and `docs/backlog-archive.md` for all `BL-*` IDs. If any ID appears more than once across the two files, **STOP and report the duplicate rather than generating §4**. Do not attempt to reconcile or guess — this is a fail-closed stop, mirroring the discipline for malformed fences.

**Backward-compatibility fallback.** If `docs/backlog.md` does not exist, skip this entire step and leave any existing `pm:curated:backlog` fence and optional `pm:curated:notes` fence byte-for-byte unchanged. The file will remain in "curated mode" for §4, as today.

**If `docs/backlog.md` is present, generate §4 as follows:**

- **Roll up open backlog rows**: scan `docs/backlog.md` for rows whose `Status` column is `open` (untriaged intake). Exclude `triaged`, `promoted`, `done`, and `wontfix` rows — those belong in the pipeline or are archived. Render as a table or bullet list (match the project's format in §2/§3) showing at minimum: ID, Type, Area, Priority, Item description.
- **Roll up homeless open issues**: cross-reference `docs/issues/*.md` for files marked open. An issue is **homeless** if **both** conditions hold: (1) it is not referenced by any plan task row in §3, AND (2) it carries no `promoted_to:` field / backlog Link pointing back to a `BL-NNN` row. If an issue is already owned by a plan (appears in §3) or has been groomed into a backlog row, do **not** restate it in §4 — keep each item in exactly one place.
- Combine open backlog rows and homeless open issues in a single cohesive view.

## Step 4 — Write the file

- Replace only the text between each `pm:generated:*:start` / `:end` fence with the freshly built §2, §3, and (if applicable) §4.
  - When generating §4 (backlog.md present): replace only the content inside `pm:generated:backlog:start` / `:end`.
  - When in fallback mode (backlog.md absent): leave `pm:curated:backlog` fence content byte-for-byte unchanged.
  - If `pm:curated:notes` is present, leave it byte-for-byte unchanged regardless of mode.
- Leave all `pm:curated:*` blocks byte-for-byte unchanged.
- Bump the frontmatter `last_updated:` to today.
- Do not stage or commit — the caller (or `/continue-tasks` / `/update-tasks`) owns the git step.

## Step 5 — Report

Print a short diff summary: features in active development, total open tasks, any newly-surfaced open issue, and whether the curated fences were preserved. Include §4 mode (generated vs. curated fallback) and any BL-id uniqueness issues detected. If a curated fence was missing or malformed, STOP and report it rather than guessing — do not overwrite curated content. If a BL-id duplicate was found, report it and abort generation; do not write the file.

## Related

- `/review-tasks` — read-only snapshot (same computation, no write)
- `/continue-tasks`, `/update-tasks` — call this generation as their final "refresh the tracker" step
- The tracker's design + single-source-of-truth rule live in `docs/STATUS.md`'s header and the project's `CLAUDE.md`.
