---
name: sops-secrets
description: Domain expertise for SOPS-encrypted secrets in this repo — reading service logins, rotating credentials, syncing the KeePass mirror, and diagnosing SOPS itself. Use whenever the user asks for an admin username/password (e.g. "what's the login for grafana"), wants to rotate a credential, edit a secret, or troubleshoot anything under secrets/. Hard rule: never run sops locally — always shell to ac-devops, which is the only host with the age key.
---

# SOPS Secrets Skill

Operator domain knowledge for `secrets/*.enc.yml` in this repo.

## When this skill applies

- The user asks for the login (URL / username / password / API token) for any
  service in this stack — **even if the word "SOPS" never appears**. Examples:
  "what's the password for grafana", "give me portainer credentials",
  "how do I log into ntfy".
- The user wants to **change** a service password, rotate a credential, or
  generate a fresh one.
- The user wants to **list** what services have credentials stored, or **find**
  where a particular login lives.
- Anything is misbehaving with SOPS itself — `sops -d` failing, KeePass mirror
  out of sync, age key questions.

If the question is about how Ansible **consumes** secrets in playbooks (not the
storage/rotation side), defer to the broader `ac-opbta-ops` skill — it owns
ISSUE-004 (`vars_files` vs `community.sops.load_vars`) and the playbook-side
contract.

## The one rule you must never break

> **Never run `sops` on the workstation. Always run it on ac-devops via SSH.**

The age key (`~/.config/sops/age/keys.txt`) is on `ac-devops` only. See
`references/age-key-hosts.md` for the authoritative inventory and reasoning.

Concrete failure modes when this rule is broken:

| Wrong move | What happens |
|------------|--------------|
| `bash scripts/get-secret.sh portainer` from Windows | Exit 4 — "age key not found". Wasted round trip; you then ssh anyway. |
| `sops -d secrets/foo.enc.yml` from Windows | Same — `failed to MAC` or "no key could decrypt". |
| Adding a `command -v sops` local fallback to a script | Some operator's stale local key half-works on some files and silently corrupts on others. |
| Decrypting on a Proxmox/Docker host inside a playbook | ISSUE-022 — `sops` binary not present; need `delegate_to: localhost`. |

If a script in this skill ever tries `sops` locally and the user has to wait
for the timeout, that's a bug in the skill — fix the script, not the workflow.

## Slash commands

All commands are thin wrappers that:

1. Parse `$ARGUMENTS` (use `AskUserQuestion` for missing values).
2. Invoke a committed, idempotent script under `scripts/sops/`.
3. The script SSHes to `ac-devops` and does the SOPS work there.
4. Report the result back to the user.

### Read-only

- **`/get-service-auth <service>`** — Print URL, username, password (or token)
  for a service. Looks up `references/services-auth-catalog.yml`. Output is
  three short lines, suitable for copy/paste. See
  `.claude/commands/get-service-auth.md`.

- **`/list-service-auth [filter]`** — Enumerate every service in the catalog
  with its source SOPS file and key paths. Read-only inventory. Optional
  filter substring narrows the list. See `.claude/commands/list-service-auth.md`.

- **`/sops-status`** — Diagnostic. Probes ac-devops for SSH reach, age key,
  sops binary, parser tooling, KeePass mirror. Reports per-step pass/fail with
  remediation. See `.claude/commands/sops-status.md`.

### Mutating

- **`/update-auth <service> [--username <u>] [--password <p>]`** — Set the
  username and/or password for a service. SSHes to ac-devops, runs `sops --set`
  (atomic — no plaintext on disk), commits to the current branch, pushes,
  syncs KeePass, and **auto-applies** the consuming playbook (per
  `references/secret-to-playbook-map.md`). See
  `.claude/commands/update-auth.md`.

- **`/rotate-service-password <service>`** — Generate a strong password
  (`openssl rand -hex 24`), then call `/update-auth` machinery. Same flow as
  `/update-auth` minus the password prompt. See
  `.claude/commands/rotate-service-password.md`.

- **`/sync-keepass`** — Re-mirror SOPS → KeePass on demand (thin wrapper around
  `scripts/sync-secrets-to-keepass.sh`). Useful after a manual `sops` edit on
  ac-devops. See `.claude/commands/sync-keepass.md`.

## What the skill is *not* for

- **Creating** a brand-new SOPS file (`secrets/<new>.enc.yml`) — one-off; do it
  by hand per `secrets/README.md §"Creating a New Secret File"`.
- **Rotating the age key** itself — separate runbook.
- **Bulk decrypting** a whole file into the chat — refused on principle. The
  read scripts only ever extract one key at a time.
- **Storing new types of credentials** — when adding a new service, edit
  `references/services-auth-catalog.yml` first, then everything else flows.

## Repository layout it touches

```
secrets/
  *.enc.yml                    SOPS-encrypted (commit safely; see secrets/README.md)
scripts/sops/
  _lib.sh                      Shared: ssh wrapper, ac-devops lock, parser shim
  get-auth.sh                  Backs /get-service-auth
  list-services.sh             Backs /list-service-auth
  set-secret.sh                Backs /update-auth
  rotate-password.sh           Backs /rotate-service-password
  status.sh                    Backs /sops-status
  backup-age-key-to-keepass.sh Last-line backup of the age key into the
                               KeePass root group (entry "sops-age-key").
                               Idempotent. See references/age-key-hosts.md.
.claude/commands/
  get-service-auth.md          Slash command shells
  list-service-auth.md
  update-auth.md
  rotate-service-password.md
  sync-keepass.md
  sops-status.md
.claude/skills/sops-secrets/
  SKILL.md                     This file
  references/
    age-key-hosts.md           Where the age key lives + why ac-devops only
    services-auth-catalog.yml  Service → SOPS file → key paths (machine-readable)
    secret-to-playbook-map.md  Secret → Ansible playbook for auto-apply
    sops-workflows.md          Read / update / generate / probe — copy-paste recipes
    parser-tooling.md          Why python3 (not yq) is the parser shim
```

## Relationship to the existing `/get-secret` command

`/get-secret <app> <key>` (under `.claude/commands/get-secret.md`) is the
older, lower-level interface — give it a SOPS file basename and a key, get the
value. It's **kept as-is** for raw SOPS access and for things outside the
service catalog (ad PSKs, Wireguard preshared keys, the qBittorrent conf
payload, etc.).

`/get-service-auth` is the higher-level, opinionated alternative for the
common case ("I just need the admin login for X"). Most session interactions
should reach for `/get-service-auth` first; fall through to `/get-secret` when
the data you want isn't admin auth (e.g. an SSID PSK, a webhook URL, an
internal API token between services).

The new skill's `_lib.sh` will eventually subsume `scripts/get-secret.sh`'s
logic, but the existing script remains so that `sync-secrets-to-keepass.sh`
and any external tooling that grew dependencies on its CLI shape don't break.
