---
name: sync-tracker
description: >
  Optional project-manager tracker mirroring. Starts with GitHub issues through gh, keeps local
  markdown authoritative, and makes repeated sync runs idempotent.
---

# Sync Tracker

Mirror local project-manager plans and task state to an external tracker. This is optional; local
markdown remains the source of truth.

## Preconditions

1. Confirm the repo has project-manager scaffolding.
2. Run `gh auth status`. If it fails, stop and report that GitHub sync is unavailable.
3. Run `references/scripts/pm-validate.ps1` if present. If validation fails, stop before syncing.
4. Never overwrite local markdown from remote issue state without explicit user approval.

## Local Fields

Use these optional frontmatter fields on plan and task files:

- `external_issue`: numeric GitHub issue id, blank until created
- `external_url`: GitHub issue URL, blank until created

## Idempotent Behavior

- If a local plan or task has `external_issue`, update that issue instead of creating a new one.
- If no external id exists, search open and closed issues for labels and title before creating:
  `project-manager`, `feature:<slug>`, `cap:<CAP-ID>`, and the local task id.
- Create labels if missing: `project-manager`, `feature:<slug>`, `status:<status>`,
  `priority:<priority>`, and `blocked` when applicable.
- Post a status comment only when the rendered local status changed since the last sync comment.
- Do not sync draft specs unless the user explicitly asks.

## GitHub Issue Shape

Issue title:

`[pm] <feature-slug> p<phase> t<task>: <task summary>`

Issue body:

- Source markdown path
- Feature slug and CAP-IDs
- Plan phase/task number
- Current local status
- Links to local artifacts if available
- Statement that local markdown is authoritative

## Output

Report:

- Created issues
- Updated issues
- Already-current issues
- Local items skipped and why
- Any local files that need `external_issue` / `external_url` updates

If frontmatter needs external ids added, make the smallest local edit after issue creation and then
rerun validation.
