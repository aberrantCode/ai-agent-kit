---
feature: "chore-docs"
phase: 1
task: 1
backlog_ref: "BL-001"
covers: []
role: "documentation-maintainer"
agent: "Codex"
status: in-progress
created: "2026-10-21"
claimed_by: "/root"
claimed_at: "2026-10-21T20:16:03.953692+00:00"
lease_expires_at: "2026-10-22T04:16:03.953692+00:00"
parallel: false
conflicts_with: []
files_allowed: ["**/*.md", "diagrams/*.html"]
files_shared: []
depends_on_tasks: []
scope_confirmed: false
authz_snapshot:
  bl_type: "chore"
  bl_status: "promoted"
  manifest_sha: "c39e0b3aff7c01c4fc7e8a17788d3b0274d61347699f2fb4258ff8c9384a5d17"
---

# Chore Task — `chore-docs-BL-001`

Status: in-progress
Owner: /root

## Backlog item

| BL-001 | chore | docs | p2 | promoted | Recursively audit README-linked documentation and correct verified documentation defects | chore-docs-BL-001 |


User authorization: audit the root README and recursively linked repository documentation,
apply documentation edits directly, and summarize changes in a table in an isolated worktree.
This is documentation maintenance; no product behavior or dependency changes are authorized.

## Related completed work

None for this chore.

## Action plan

1. Traverse local Markdown/HTML links from README, expanding linked directories; supplement
   with a tracked-document inventory to catch documentation outside the reachable graph.
2. Check link destinations, heading anchors, and operational guidance against repository files.
3. Correct verified defects in maintained documentation and skill bodies. Preserve feature
   scope, plans, historical reports, generated catalogs, and executable behavior.
4. Rerun link checks and the local validation gate; record results and a change table.

## Files you must not touch

- Feature specs, implementation plans, and historical report contents.
- Generated manifest/catalog content except through their generators if required.
- Runtime code, external profiles, or the main checkout's uncommitted work.
- Scope manifest or this task's authorization snapshot.

## Constraints

No new dependencies. No skill restructuring or mirror-policy changes. Documentation-only
corrections do not add runtime behavior and are verified by destination/consistency checks.

## Completion instructions

Append a final `## Completion` block with Status, Summary, Artifacts, Tests, Notes, and Handoff
in the format in `docs/tasks/template.md`.

## Completion

Status: success
Summary: Audited README-linked documentation recursively, supplemented it with a repository-wide document link scan, and corrected verified documentation defects.
Artifacts:
  - CLAUDE.md
  - CONTRIBUTING.md
  - README.md
  - claude/README.md
  - claude/skills/chrome-extension-builder/references/wxt-config.md
  - claude/skills/skills-manager/SKILL.md
  - claude/skills/sops-secrets/SKILL.md
  - claude/skills/statusline/SKILL.md
  - codex/README.md
  - codex/skills/github/SKILL.md
  - codex/skills/skills-manager/SKILL.md
  - diagrams/install-paths.html
  - docs/README.md
  - docs/backlog.md
  - docs/reorg/charter.md
  - docs/workflow/runners.md
  - gemini/README.md
  - gemini/skills/chrome-extension-builder/references/wxt-config.md
  - gemini/skills/skills-manager/SKILL.md
  - scripts/README.md
  - shared/guardrails/README.md
  - docs/backlog-archive.md
  - docs/tasks/archive/chore-docs-BL-001.md
Tests:
  added: 0
  changed: 0
  passing: true
Notes:
  - Documentation-only changes; no new dependencies, frontmatter changes, skill restructuring, feature-spec changes, or plan edits.
  - Local target and heading checks scan all tracked Markdown/HTML plus the new task record, not only the README-reachable subset. Fenced/inline code examples and external URLs are excluded.
  - Two ../../security/advisories/new links in repo-init SECURITY.md templates are intentional generated-repository GitHub routes, not local archive paths; preserved explicitly.
  - validate.ps1 passed before and after edits with 0 errors, 21 existing warnings, and 71 informational findings; generated catalog/changelog checks passed.
  - git diff --check passed. Existing mirror differences remain outside these documentation corrections.
  - Historical reports and dated snapshots remain historical; external websites, deployed profiles, and API/CLI behavior outside this repository were not validated.
  - Source checkout's pre-existing bootstrap changes were left untouched. Work is uncommitted in docs/recursive-readme-audit, based on source HEAD 6dd3f53.
Handoff:
  - Review the documentation diff in the isolated worktree. No commit, push, or PR was requested.
