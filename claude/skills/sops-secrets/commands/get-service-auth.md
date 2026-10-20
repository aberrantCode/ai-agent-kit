---
description: Print URL, username, and password (or token) for a service from the SOPS-backed auth catalog.
---

Parse `$ARGUMENTS` as `<service>`. If missing, ask for it with `AskUserQuestion`.

1. Look up `<service>` in `references/services-auth-catalog.yml` (this skill's
   service → SOPS file → key paths catalog). If it isn't listed, tell the user
   and point them at `/list-service-auth` to see what is, and at
   `/get-secret` for ad hoc non-catalog secrets.
2. Run `scripts/sops/get-auth.sh <service>`. The script SSHes to `ac-devops`
   and extracts the URL, username, and password/token for `<service>` —
   never run `sops` locally (see `SKILL.md` "The one rule you must never
   break").
3. Report exactly three lines back to the user, suitable for copy/paste:

   ```
   URL:      <url>
   Username: <username>
   Password: <password or token>
   ```

Do not echo the full decrypted SOPS file or any key other than the one this
service needs.
