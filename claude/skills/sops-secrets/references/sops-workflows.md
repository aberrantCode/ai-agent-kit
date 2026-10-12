# SOPS workflows — copy-paste recipes

All of these run **on `ac-devops`** (`ssh ubuntu@192.168.30.15`), never on the
workstation — see "The one rule you must never break" in `SKILL.md`. Every
recipe below assumes you're already SSHed in and `cd ~/repos/AC_OPBTA` (or
the equivalent checkout of the repo that holds `secrets/`).

## Read a single key

```bash
sops --decrypt --extract '["grafana"]["admin_password"]' secrets/grafana.enc.yml
```

`--extract` avoids dumping the whole file to a terminal that might be logged —
this is what `scripts/sops/get-auth.sh` wraps.

## Update a single key (no plaintext on disk)

```bash
sops --set '["grafana"]["admin_password"] "NEW-VALUE-HERE"' secrets/grafana.enc.yml
```

`sops --set` re-encrypts in place; there is no intermediate decrypted file on
disk at any point. This is what `scripts/sops/set-secret.sh` wraps, followed
by `git add/commit/push` on the current branch and a KeePass re-sync.

## Generate a new strong value

```bash
openssl rand -hex 24
```

Standard password-generation primitive across this repo (see
`ac-opbta-ops`'s `gen-password.sh` helper for the Ansible-side equivalent).
`scripts/sops/rotate-password.sh` pipes this straight into the `sops --set`
recipe above — the plaintext never touches a variable that gets echoed or
logged.

## Probe SOPS health

```bash
test -f ~/.config/sops/age/keys.txt && echo "age key: present" || echo "age key: MISSING"
command -v sops >/dev/null && sops --version || echo "sops binary: MISSING"
python3 --version   # the parser shim — see parser-tooling.md
```

This is the checklist `scripts/sops/status.sh` runs for `/sops-status`: SSH
reach (already true if you're reading this over the connection), age key
presence, `sops` binary presence, parser-shim availability, and KeePass
mirror reachability.

## Bulk-decrypt — refused on principle

There is deliberately no recipe here for dumping an entire `*.enc.yml` file's
plaintext to stdout/chat. See `SKILL.md` "What the skill is *not* for" —
extract one key at a time.
