---
description: Enumerate every service in the SOPS auth catalog with its source file and key paths (read-only).
---

Parse `$ARGUMENTS` as an optional `[filter]` substring. No prompt needed if
absent — it just means "list everything."

1. Run `scripts/sops/list-services.sh [filter]`. This is read-only: it only
   lists catalog *structure* (service name, `sops_file`, key paths) from
   `references/services-auth-catalog.yml` — it does not decrypt or print any
   secret value.
2. If `filter` was given, only show services whose name contains it
   (case-insensitive substring match).
3. Report as a table: service name, SOPS file, username key, password key.

This command never SSHes to `ac-devops` for a decrypt — the catalog itself is
not secret, only the values it points at are.
