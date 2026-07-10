---
description: Scan the current repository for logo assets and report each one's on-brand status against the AC design-system checklist — read-only, ends with a table and optional next-step choices.
---

Apply the `ac-logo` skill and execute its **find** operation.

Scan the current repo for logo/brand assets, evaluate them against the Brand checklist in
`AC_DESIGN_ROOT/docs/logo-design-system.md` (env var, fallback `C:\development\ac_design`),
and report path, theme, verdict, failing checklist items, and variant-set completeness.

If anything fails the checklist, offer next steps (reskin / regenerate / leave) via
`AskUserQuestion` — never as a free-text question.
