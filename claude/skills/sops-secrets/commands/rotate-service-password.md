---
description: Generate a strong password and rotate a service's SOPS-backed credential, then run the same apply flow as /update-auth.
---

**For agents:** prefer the Secrets-Broker MCP (`secret_rotate`) — see
`SKILL.md` "Agent path." This command is the operator's interactive path.

Parse `$ARGUMENTS` as `<service>`. If missing, ask with `AskUserQuestion`.

1. Confirm `<service>` exists in `references/services-auth-catalog.yml`.
2. Run `scripts/sops/rotate-password.sh <service>`. The script:
   - generates a new value with `openssl rand -hex 24`,
   - calls the same `sops --set` / commit / push / KeePass-sync / auto-apply
     machinery as `scripts/sops/set-secret.sh` (see `/update-auth`) with that
     generated value as the password,
   - never prints the old value, and only prints the new value once, at the
     end, for the operator to copy.
3. Report the new password once, plus the same commit/auto-apply summary as
   `/update-auth`.

This is `/update-auth` minus the "what should the password be" prompt — same
underlying flow.
