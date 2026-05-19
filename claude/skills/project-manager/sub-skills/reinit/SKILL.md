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

## Step 3 - Normalize Feature Specs

For each `.md` file in `docs/features/` except `README.md` and `template.md`:

1. Read the file in full.
2. Check required frontmatter fields:
   `feature`, `slug`, `status`, `priority`, `area`, `depends_on`, `owner`, `version`,
   `last_updated`, `related`.
3. Check required sections:
   `## Metadata`, `## Executive Overview`, `## Problem Statement`, `## Use Cases`,
   `## Capabilities`, `## Acceptance Criteria`, `## Out of Scope`, `## Edge Cases`,
   `## Known Issues & Limitations`, `## Open Questions`, `## Change History`.
4. If the file conforms, report `ok` and do not rewrite it.
5. If it does not conform, rewrite it using `docs/features/template.md`.

Normalization rules:

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

Print a summary table:

| File | Result | Notes |
|------|--------|-------|
| auth.md | ok | already conforming |
| billing.md | normalized | added frontmatter, moved legacy notes |

Also report archived plan/task files and any specs that still need `/analyze-features` before they
can be approved.

## Step 5 - Launch

Run the `/continue-tasks` workflow from its bootstrap step. The launched loop must still enforce:

- Only `status: approved` specs can produce plans or tasks
- Dependencies must be complete before downstream work
- Completion requires a final `## Completion` block with parseable `Status:`
- Code-changing work requires verification before final completion
