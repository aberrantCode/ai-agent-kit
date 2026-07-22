---
name: opbta-service
category: Infrastructure & Ops
description: Use when deploying, updating, retiring, inspecting, managing, or listing an internal service on svc.opbta.com (OPBTA) from any repo, not only AC_OPBTA. Covers deploy a service, add a container, stand up X on svc.opbta.com, day-2 ops, rotate a secret, re-expose a service, rename/move/resize a service, service catalog / list services, cross-repo OPBTA service lifecycle.
---

# opbta-service

**REQUIRED BACKGROUND:** the `ac-opbta-ops` skill

Thin dispatcher. Resolves source-repo context (cwd, git remote, `.opbta-service`
breadcrumb), locates `AC_OPBTA` (default `C:\development\AC_OPBTA`, else git
discovery), then reads and FOLLOWS that repo's own `add-service` /
`update-service` / `retire-service` command files and `scripts/phases/*`
helpers as the source of truth. No lifecycle logic is duplicated here.

Metadata SoT: `AC_OPBTA/inventory/services.yml`. Source repos carry only a
`.opbta-service` breadcrumb (slug only) — zero metadata leakage.

Six commands:
- `/opbta-create` — new deployment end-to-end (reroutes to update if slug exists)
- `/opbta-update` — bump/reconcile an existing service (reroutes to create if slug absent)
- `/opbta-retire` — remove a service end-to-end
- `/opbta-inspect` — deep read on one service
- `/opbta-manage` — day-2 ops: restart/stop/start, re-expose, rotate secret, rename/move/resize
- `/opbta-list` — catalog-wide read, health/drift summary

Target resolution order: explicit arg → `.opbta-service` breadcrumb → service picker.

Autonomy: ONE plan-gate approval (AskUserQuestion), then autonomous through
worktree + ac-devops lock + two-pass idempotency + smoke test, to an OPENED
PR — never auto-merge.

**HARD INVARIANT: never push an image to an external/public registry.**

## Quick Reference

| Concern | File |
|---|---|
| Locate AC_OPBTA, worktree, ac-devops lock, apply pattern | `references/bridge.md` |
| `services.yml` schema + new `source:` block | `references/manifest-schema.md` |
| Auto-route matrix + plan-gate rules | `references/routing.md` |
| Verb → repo command/script mapping | `references/lifecycle-map.md` |
| Service picker (Spectre / Out-GridView / AskUserQuestion) | `references/service-picker.md` |

## Diagram

[View diagram](diagram.html)
