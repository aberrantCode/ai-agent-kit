# Secret -> Ansible playbook map

`/update-auth` and `/rotate-service-password` auto-apply the playbook that
actually consumes a secret after writing the new value with `sops --set`.
`scripts/sops/set-secret.sh` and `scripts/sops/rotate-password.sh` read this
table to decide what to run; both skip the auto-apply step and just report
"no mapped playbook" when a `sops_file` has no row below (safer than guessing).

## Schema

| `sops_file` (relative to repo root) | Playbook to re-run | Notes |
|---|---|---|
| `secrets/<file>.enc.yml` | `playbooks/<name>.yml` | Any `--limit`/tag scoping the playbook needs, so the auto-apply doesn't fan out further than the one service. |

## Populating this table

This table is deliberately empty of real rows in the skill-archive copy — the
actual secret file ↔ playbook pairings are specific to the services deployed
in *this* repo's `inventory/services.yml` and change as services are added or
retired via `/add-service` / `/retire-service` (owned by the `ac-opbta-ops`
skill). Add a row here whenever a new `secrets/*.enc.yml` file is wired into a
playbook, so `/update-auth` can auto-apply instead of leaving the operator to
remember and re-run it by hand.

If a secret legitimately has no consuming playbook (e.g. it's read ad hoc by
a script, not by Ansible), do not add a row — `/update-auth` for that service
will just stop after the `sops --set` + KeePass sync and tell the operator
there's nothing to auto-apply.
