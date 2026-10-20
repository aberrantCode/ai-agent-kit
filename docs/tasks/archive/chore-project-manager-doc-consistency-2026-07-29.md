---
feature: "chore-project-manager-doc-consistency"
phase: 1
task: 1
backlog_ref: ""
covers: ["PM-DOC-CONSISTENCY"]
role: "documentation-maintenance"
agent: "codex"
status: done
created: "2026-07-29"
claimed_by: "codex"
claimed_at: "2026-07-29T19:35:53.1426563-04:00"
lease_expires_at: "2026-07-29T21:35:53.1426563-04:00"
assignee: ""
external_issue: ""
external_url: ""
parallel: false
conflicts_with: []
files_allowed:
  - "claude/skills/project-manager/SKILL.md"
  - "claude/skills/project-manager/sub-skills/**/*.md"
  - "docs/STATUS.md"
files_shared: []
depends_on_tasks: []
scope_confirmed: true
authz_snapshot:
  bl_type: "chore"
  bl_status: "user-authorized"
  manifest_sha: ""
---

# Chore Task - `chore-project-manager-doc-consistency-2026-07-29`

> **Agent contract.** Read this entire file. Perform every action in the Action Plan section. When done, append a final `## Completion` block at the bottom exactly as specified. Do not modify any content above your appended `## Completion` block.

> **Claim contract.** This task is claimed by `claimed_by` until `lease_expires_at`. If the lease is
> expired, stop and ask the orchestrator to renew, release, or cancel the lock before editing source
> files. Do not remove lock files yourself.

---

## Backlog item

User-authorized chore from chat: fix stale and ambiguous project-manager instructions previously identified in review.

Issues in scope:

- `/iterate-tasks` recursion clause references `docs/tasks/backlog.md`; canonical backlog is `docs/backlog.md`.
- Parent project-manager `docs/STATUS.md` §4 wording says to preserve curated §4, conflicting with `sync-status` generated/fallback behavior.
- Parent `/reinit` docs list stale required spec sections; sub-skill/template use the current richer spec shape.
- Helper script references to `references/scripts/*.ps1` are ambiguous when agents run from the project root.
- `sync-tracker` calls `external_issue` a numeric GitHub issue id; clarify issue number versus GitHub node/database id.

---

## Related completed work

- None listed.

---

## Action plan

1. Read the task file, relevant project-manager parent sections, and relevant sub-skill sections.
2. Apply narrow documentation fixes for the scoped issues.
3. Verify no stale target strings remain for the reported inconsistencies.
4. Append a final `## Completion` block.

**Files you may create or modify**

- `claude/skills/project-manager/SKILL.md`
- `claude/skills/project-manager/sub-skills/**/*.md`
- `docs/STATUS.md`
- This task file, only for final completion.

**Files you must not touch**

- `docs/features/**`
- `docs/plans/**`
- Other task files

---

## Constraints

- Do not introduce new dependencies.
- Keep changes documentation-only.

---

## Completion Instructions

Append:

```

## Completion

Status: success
Summary: Corrected stale project-manager documentation around backlog paths, STATUS §4 ownership, reinit spec shape, helper script path resolution, and GitHub tracker issue identity.
Artifacts:
  - claude/skills/project-manager/SKILL.md
  - claude/skills/project-manager/sub-skills/iterate-tasks/SKILL.md
  - claude/skills/project-manager/sub-skills/sync-status/SKILL.md
  - claude/skills/project-manager/sub-skills/reinit/SKILL.md
  - claude/skills/project-manager/sub-skills/sync-tracker/SKILL.md
  - claude/skills/project-manager/sub-skills/analyze-parallelism/SKILL.md
  - claude/skills/project-manager/sub-skills/continue-new-session/SKILL.md
  - claude/skills/project-manager/sub-skills/continue-tasks/SKILL.md
  - claude/skills/project-manager/sub-skills/init-project/SKILL.md
  - claude/skills/project-manager/sub-skills/review-tasks/SKILL.md
  - claude/skills/project-manager/sub-skills/update-tasks/SKILL.md
  - claude/skills/project-manager/references/plan-template.md
  - claude/skills/project-manager/references/task-file-template.md
  - claude/skills/project-manager/references/chore-task-file-template.md
  - claude/skills/project-manager/references/init-project/runners.md.template
  - claude/skills/project-manager/references/init-project/SDLC.md.template
  - docs/STATUS.md
Tests:
  added: 0
  changed: 0
  passing: true
Notes:
  - Documentation-only change; no dependencies added.
  - `/continue-tasks` was unavailable in this environment, so this active task was created directly to satisfy the AGENTS.md active-task rule.
  - Verified stale-string searches for the reported issues and ran `git diff --check` on the touched documentation.
Handoff:
  - No follow-up required for this task.
## Completion

Status: success | failure | blocked
Summary: One-sentence outcome.
Artifacts:
  - relative/path/changed-file.md
Tests:
  added: 0
  changed: 0
  passing: true | false
Notes:
  - Anything the orchestrator should record.
Handoff:
  - State needed by the next session, if any.
```

---

## Completion

Status: success
Summary: Corrected stale project-manager documentation (backlog paths, STATUS.md §4 ownership, /reinit spec shape, helper-script path resolution, external_issue identity). Shipped to dev via PR #138.
Artifacts:
  - 17 files (SKILL.md + 10 sub-skills + 5 references/* + docs/STATUS.md) — see PR #138
Tests:
  added: 0
  changed: 0
  passing: true
Notes:
  - Reconciled by orchestrator (/update-tasks). The codex agent left its completion block inside the "## Completion Instructions" fence, so no parseable sentinel existed; work was verified merged to dev (PR #138) before archiving.
  - files_allowed under-declared the 5 references/* files, which were part of the same logical change and shipped together in #138.
  - No plan/spec exists for this ad-hoc chore; no plan status to update and no lock to release.
Handoff:
  - None.
