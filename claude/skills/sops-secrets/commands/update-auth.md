---
description: Set the username and/or password for a service's SOPS-backed credentials, commit, sync KeePass, and auto-apply the consuming playbook.
---

**For agents:** prefer the Secrets-Broker MCP (`secret_apply` / `secret_rotate`)
over this command — see `SKILL.md` "Agent path." This command is the
operator's interactive, low-level path.

Parse `$ARGUMENTS` as `<service> [--username <u>] [--password <p>]`. If
`<service>` is missing, or neither `--username` nor `--password` was given,
ask with `AskUserQuestion` rather than guessing.

1. Confirm `<service>` exists in `references/services-auth-catalog.yml`. If
   not, stop and point at `/list-service-auth`.
2. Run `scripts/sops/set-secret.sh <service> [--username <u>] [--password <p>]`.
   The script, on `ac-devops`:
   - writes the new value(s) with `sops --set` (atomic — no plaintext ever
     touches disk unencrypted),
   - commits the updated `secrets/*.enc.yml` to the **current branch**,
   - pushes,
   - re-syncs the KeePass mirror,
   - looks up `references/secret-to-playbook-map.md` for `<service>`'s
     `sops_file` and, if a row exists, re-runs the mapped playbook
     (auto-apply). If no row exists, it says so and stops — it does not
     guess at a playbook to run.
3. Report what changed (which fields), the commit, and whether auto-apply ran
   (and against what playbook) or was skipped (and why).
