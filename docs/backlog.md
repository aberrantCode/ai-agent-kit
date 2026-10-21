---
kind: backlog
purpose: Intake for not-yet-scheduled work. The single front door for bugs, chores, debt, and ideas.
last_updated: 2026-10-21
---

# Backlog

| ID | Type | Area | Pri | Status | Item | Link |
|----|------|------|-----|--------|------|------|


## Legend

- **Type** ∈ {`bug`, `chore`, `debt`, `idea`}
- **Status** ∈ {`open`, `triaged`, `promoted`, `done`, `wontfix`}
- **IDs** are monotonic and never reused across the live backlog and `backlog-archive.md`. The `/capture` command computes the next `BL-*` id from the maximum id across both files (race-safe via advisory lock).
- **Allocation** is atomic: a `BL-*` id appearing more than once across live + archive is a validation error caught by `sync-status` / `validate.ps1`.
- **Promoted rows** carry a `Link` to the feature-plan phase or chore task id they became.
