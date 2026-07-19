---
description: Copy the current repo's logo set into the AC_DESIGN gallery (artifacts/logos/) under a kebab-case name — confirms via AskUserQuestion before overwriting anything that already exists there.
---

Apply the `ac-logo` skill and execute its **archive** operation.

Identify the repo's logo set (full 8-file set when present), derive the kebab-case gallery
name, and copy to `AC_DESIGN_ROOT/artifacts/logos/` (env var, fallback
`C:\development\ac_design`). If any destination file exists, confirm overwrite / skip /
abort via `AskUserQuestion` — never overwrite silently.
