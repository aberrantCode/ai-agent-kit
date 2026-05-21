# `docs/what-next.md` Schema

The cache file combines machine-readable YAML frontmatter (used by the skill on every run) with
human-readable markdown notes (so a developer can open the file and understand the state at a
glance).

## Full example

```markdown
---
generated: 2026-04-21
updated: 2026-04-21
pm_framework: backlog-md            # one of: project-manager, project-manager-partial,
                                    #         project-manager-seed, backlog-md, tasks-md,
                                    #         plan-md, todo-md, github-issues,
                                    #         changelog-driven, none
task_store: backlog.md              # primary file the skill reads/writes
archive_store: backlog-archive.md

stacks:                             # detected from anchor files
  - name: typescript
    marker: package.json
  - name: rust
    marker: Cargo.toml

monorepo: false                     # true if workspace markers found

areas:                              # confirmed area map (prefix -> folder)
  AUTH: src/auth
  UI: src/ui
  API: src/api
  DB: src/db

priority_weights:                   # optional; missing keys fall back to defaults
  blocks_others: 40
  security: 35

current_task: null                  # set to an ID when a task is in-progress; null otherwise

fingerprints:                       # SHA-256 of tracked files (see references/fingerprint.md)
  backlog.md: 3a7e1f...
  package.json: c29b84...
  Cargo.toml: 9f0d12...
  README.md: 81ee44...
---

# What Next — Project Snapshot

## Overview

Short prose summary: what this project is, what stack it uses, who/what the user is focused on.
Regenerated on each `/what-next update` run from the analysis findings.

## Current State

- **Pending tasks**: 12
- **In progress**: 1 (AUTH-004 — Refactor login middleware)
- **Recently completed**: 3 in the last 7 days

## Top Pending (snapshot)

Computed at generation time; re-sorted on every run. This list is informational only — the
live ranking is computed fresh.

1. AUTH-004 — Refactor login middleware (score 90)
2. DOC-002 — Update README with install steps (score 7)
3. UI-011 — Fix button alignment on mobile (score 5)

## Notes

Free-form space for the user (or the skill) to record context: recent decisions, things to
remember next session, stakeholder constraints.
```

## Required frontmatter fields

| Field            | Type           | Notes                                                      |
|------------------|----------------|------------------------------------------------------------|
| `generated`      | ISO date       | When the cache was first created                           |
| `updated`        | ISO date       | When the cache was last refreshed                          |
| `pm_framework`   | string enum    | See top of this file for allowed values                    |
| `task_store`     | string / null  | Path to the primary file; null if no task store exists yet |
| `archive_store`  | string / null  | Path to the archive file                                   |
| `stacks`         | list           | Each with `name` and `marker`                              |
| `areas`          | map            | `PREFIX -> folder path` (may be empty for `none`/`GEN`)    |
| `fingerprints`   | map            | `relative path -> sha256 hex`                              |

## Optional fields

| Field               | Notes                                                                 |
|---------------------|-----------------------------------------------------------------------|
| `monorepo`          | Boolean (default false)                                               |
| `priority_weights`  | Override block (see `priority-weights.md`)                            |
| `current_task`      | ID of the active task; cleared on completion                          |
| `external_trackers` | List of external systems detected but not fetched (e.g., GitHub, Jira)|
| `notes`             | Free-form string for project-specific context                         |

## Where this file lives

**Project's `docs/` folder**, i.e., `docs/what-next.md` relative to the repo root. Create the
`docs/` directory if it doesn't already exist. Do NOT write to the filesystem root (`/docs`).

## Lifecycle

- Created on first run of `/what-next` when no cache exists.
- Read on every subsequent run before any other I/O.
- Refreshed when fingerprints mismatch, or unconditionally on `/what-next update`.
- Never deleted by the skill — the user can delete it to force a full re-analysis.
