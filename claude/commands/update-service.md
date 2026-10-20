---
description: Update an existing OPBTA service on svc.opbta.com — bump/reconcile image, config, ports, env, or exposure. Resolves the target from the current repo's .opbta-service breadcrumb (else a service picker), plans once for approval, then runs autonomously to an opened PR.
---

Apply the `opbta-service` skill and execute its **update** operation.

The current working directory is the source-repo context. Resolve the target service via the
skill's order: an explicit slug in the message → the repo's `.opbta-service` breadcrumb →
the service picker. If the resolved slug does not yet exist, the skill reroutes to **create**.

An optional message may name the target service slug and/or what to change (image bump, port,
env var, re-expose, rename/move/resize); otherwise infer it from the repo context and confirm
at the plan gate.

Honor the skill's autonomy model: ONE plan-gate approval via `AskUserQuestion`, then autonomous
through worktree + ac-devops lock + two-pass idempotency + smoke test to an OPENED PR — never
auto-merge. Enforce the hard invariant: never push an image to an external/public registry.
