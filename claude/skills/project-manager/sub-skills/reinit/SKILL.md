---
name: reinit
description: Archive legacy plans and tasks, normalize feature specs to the current project-manager template, then launch the approved-spec orchestration loop
---

# Reinit

Use when a repository has existing project-manager artifacts that may be stale, malformed, or
partially manual. Reinit preserves all existing content, normalizes feature specs, and then hands off
to `/continue-tasks`.

## Step 1 - Archive Existing Plans

Move every non-template, non-archive file in `docs/plans/` to `docs/plans/archive/`.

- Create `docs/plans/archive/` if missing.
- Do not delete files.
- If a destination filename already exists, prefix the moved file with today's date
  (`YYYY-MM-DD-`) and, if needed, a numeric suffix.
- Leave `docs/plans/template.md` in place.

## Step 2 - Archive Existing Tasks

Move these files to `docs/tasks/archive/`:

- Every `docs/tasks/active/*.md`
- Any loose `docs/tasks/*.md` except `template.md`

Preserve completion sentinels exactly as written, including malformed or blocked ones. If collisions
occur, use the same date-prefix rule as plans.

## Step 3 - Audit Feature Specs (Report by Default)

Reinit is recovery tooling. Mass-rewriting specs in place is surprising and hard to undo,
so this step audits and reports first, and only rewrites with explicit user consent.

For each `.md` file in `docs/features/` except `README.md` and `template.md`:

1. Read the file in full.
2. Check required frontmatter fields:
   `feature`, `slug`, `status`, `priority`, `area`, `depends_on`, `owner`, `version`,
   `last_updated`, `related`.
3. Check required sections:
   `## Metadata`, `## Executive Overview`, `## Problem Statement`, `## Use Cases`,
   `## Capabilities`, `## Acceptance Criteria`, `## Out of Scope`, `## Edge Cases`,
   `## Known Issues & Limitations`, `## Open Questions`, `## Change History`.
4. Classify the file as `ok` (fully conforming) or `non-conforming`. Record the specific gaps
   (missing frontmatter fields, missing sections) for the report.

Do **not** rewrite anything yet. After auditing all specs, print the audit table:

| File | Result | Missing frontmatter | Missing sections |
|------|--------|---------------------|------------------|
| auth.md | ok | — | — |
| billing.md | non-conforming | `priority`, `owner` | `## Use Cases`, `## Edge Cases` |

If every spec is `ok`, continue to Step 4.

If one or more specs are `non-conforming`, use `AskUserQuestion` to choose how to proceed.
Default (first / recommended) option must be `report-only`:

- **report-only** — leave all specs untouched and continue to Step 4. The user will fix them
  manually. Downstream `/continue-tasks` will simply skip non-`approved` specs, so this is safe.
- **rewrite-selected** — present the list of non-conforming files via `AskUserQuestion`
  (`multiSelect: true`) and normalize only the chosen ones using the rules below.
- **rewrite-all** — normalize every non-conforming spec using the rules below.

Only files explicitly selected by the user are rewritten. `ok` files are never rewritten.

Normalization rules (apply only to user-selected rewrites):

- Never discard content. Every sentence, table, list, code block, and edge-case note from the
  original must appear in the rewritten file.
- Map existing content to the nearest matching section.
- Put content that does not fit in a `## Notes` section at the bottom.
- Infer missing frontmatter conservatively:
  - `slug`: filename without `.md`
  - `status`: existing explicit status if present, otherwise `draft`
  - `priority`: existing explicit priority if present, otherwise `p2`
  - `area`: infer from feature name or use `general`
  - `depends_on`: dependency references found in text, otherwise `[]`
  - `owner`: existing owner/author if present, otherwise `unknown`
  - `version`: existing version if present, otherwise `1.0`
  - `last_updated`: today's date
  - `related`: existing issue/PR links if present, otherwise `[]`
- Preserve user-controlled spec status. Do not promote a draft to approved.
- Keep capabilities as checkbox bullets with CAP-IDs where possible. If a capability lacks a CAP-ID,
  preserve it and flag it for `/analyze-features`.
- Keep acceptance criteria as Given/When/Then where possible.

## Step 4 - Report

Print a final summary table that reflects the actual disposition of each spec:

| File | Result | Notes |
|------|--------|-------|
| auth.md | ok | already conforming |
| billing.md | normalized | user-selected rewrite; added frontmatter, moved legacy notes |
| legacy.md | reported only | non-conforming; user opted not to rewrite |

Also report archived plan/task files and any specs that still need `/analyze-features` before they
can be approved.

## Step 5 - Refresh Runner Discovery

The Verification Gate consults `docs/workflow/runners.md` to confirm a code-changing task's `Tests: passing: true` claim. Repository layout drifts (a new `backend/` subtree, a renamed `services/api/`, etc.), so reinit must reconfirm:

1. Read repo signals (`README.md`, `CLAUDE.md`, `AGENTS.md`, workspace files like `pnpm-workspace.yaml` / `turbo.json` / `go.work`).
2. Run `references/scripts/pm-test-runners.ps1 -DiscoverOnly` against the repo root.
3. Diff the discovered candidates against the existing rows in `docs/workflow/runners.md`. Categorize each candidate as:
   - **Already confirmed** — present in the file with `Confirmed: yes`, evidence still on disk. Leave alone.
   - **New candidate** — discovered but not in the file. Surface via `AskUserQuestion`.
   - **Stale confirmed** — present with `Confirmed: yes` but evidence path no longer exists. Surface via `AskUserQuestion` so the user can confirm removal.
4. Use `AskUserQuestion` to resolve new and stale rows. Default to keeping confirmed rows untouched unless the user explicitly opts to remove them.
5. Persist the resolved table back to `docs/workflow/runners.md`, updating `last_updated` and setting `discovered_by: reinit`.

If `docs/workflow/runners.md` does not exist yet (the repo was init'd before this phase existed), copy the template from `references/init-project/runners.md.template` first and then run steps 1-5 as if it were a fresh discovery.

## Step 6 - Launch

Run the `/continue-tasks` workflow from its bootstrap step. The launched loop must still enforce:

- Only `status: approved` specs can produce plans or tasks
- Dependencies must be complete before downstream work
- Completion requires a final `## Completion` block with parseable `Status:`
- Code-changing work requires verification before final completion
