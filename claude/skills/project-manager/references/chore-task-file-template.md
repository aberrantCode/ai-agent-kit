---
feature: "chore-{{area}}"
phase: {{N}}
task: {{M}}
backlog_ref: "BL-{{NNN}}"
covers: ["XX-CAP-NN"]
role: "{{role}}"
agent: "{{agent-type}}"
status: in-progress      # set by orchestrator at spawn time
created: "{{TODAY}}"
claimed_by: "{{agent-or-user}}"
claimed_at: "{{TIMESTAMP}}"
lease_expires_at: "{{TIMESTAMP}}"
assignee: ""
external_issue: ""
external_url: ""
parallel: false
conflicts_with: []
files_allowed: []
files_shared: []
depends_on_tasks: []
scope_confirmed: false
authz_snapshot:
  bl_type: "{{type}}"        # bug|chore|debt — frozen copy of backlog row type at promotion
  bl_status: "promoted"      # triaged|promoted — frozen copy of backlog row status at promotion
  manifest_sha: "{{sha256}}" # sha256 of docs/workflow/scope-manifest.md at promotion (compute via Get-FileHash)
---

# Chore Task — `chore-{{area}}-BL-{{NNN}}`

> **Agent contract.** Read this entire file. Perform every action in the Action Plan section. When done, append a final `## Completion` block at the bottom exactly as specified. Do not modify any content above your appended `## Completion` block.

> **Claim contract.** This task is claimed by `claimed_by` until `lease_expires_at`. If the lease is
> expired, stop and ask the orchestrator to renew, release, or cancel the lock before editing source
> files. Do not remove lock files yourself.

---

## Backlog item

Pulled from `docs/backlog.md` — the orchestrator inlines the backlog row so this task is self-contained.

> | BL-{{NNN}} | {{type}} | {{area}} | {{pri}} | {{status}} | {{item}} | {{link}} |

**Authorization snapshot.** The `authz_snapshot` frontmatter fields (`bl_type`, `bl_status`, `manifest_sha`) are frozen at promotion and must not be hand-edited. The build-time guard validates them against the live backlog row and scope-manifest. Any mismatch indicates stale authorization and requires re-grooming.

---

## Related completed work

The orchestrator lists previously archived task files in this chore that may inform the current task. Read them only if you need context.

- `docs/tasks/archive/chore-{{area}}-BL-{{prev}}.md` — summary line

---

## Action plan

1. ...
2. ...
3. ...

**Files you may create or modify**

- ...

**Files you must not touch**

- `docs/features/**` — specs are authority; if a change is needed, surface it in the completion notes, do not edit
- `docs/plans/**` — orchestrator-owned
- `docs/workflow/scope-manifest.md` and this task's `backlog_ref` row's authorization fields — a chore commit may not edit its own authorization
- Other task files

**Parallel execution metadata**

- `parallel` remains `false` unless `/analyze-parallelism` has produced an approved batch plan.
- `files_allowed` are exclusive ownership globs for this task.
- `files_shared` require a single owning task and explicit merge coordination.
- `conflicts_with` and `depends_on_tasks` use local task ids such as `chore-{{area}}-BL-{{NNN}}`.

---

## Constraints

- Tests-first. Write a failing test before implementation when adding behavior.
- Do not introduce new dependencies without listing them in `Notes` below.
- Do not silently expand scope. If a required change falls outside this chore's `covers:` list, stop and surface it in `Notes`.

---

## Completion Instructions

> **The agent appends the block below at the bottom of the file under a new final `## Completion` heading. The orchestrator only treats the task as complete when the final `## Completion` heading has a parseable `Status:` field after it. Use the exact field names.**

```
## Completion

Status: success | failure | blocked
Summary: One-sentence outcome.
Artifacts:
  - relative/path/changed-file.ts
  - relative/path/test-file.spec.ts
Tests:
  added: N
  changed: N
  passing: true | false
Notes:
  - Anything the orchestrator should record in the plan notes column.
  - Surface any spec divergence here; do not edit the spec.
Handoff:
  - State needed by the next session, if any.
Error: (only present when Status is failure)
  Root cause: ...
  What was tried: ...
  Suggested corrective task: ...
Blocked: (only present when Status is blocked)
  Reason: ...
  Decision needed: ...
```
