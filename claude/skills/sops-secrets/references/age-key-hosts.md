# Age key host inventory

Authoritative answer to "where does the SOPS age key live, and why."

## Inventory

| Host | Has the age key? | Why |
|---|---|---|
| `ac-devops` (`ubuntu@192.168.30.15`) | **Yes** — `~/.config/sops/age/keys.txt` | Canonical control node for this repo. Every `sops`-touching operation (decrypt, `--set`, re-key) runs here. |
| Workstation (Windows, wherever Claude Code / Codex / Gemini is running) | No | By design. Keeping the key off the workstation means a compromised dev machine, a leaked `.bash_history`, or a stray `git add` can't leak the key. |
| Any Proxmox/Docker host (`ac-svr1`, `ac-svr2`, `ac-docker1`, …) | No | These run the *decrypted* output of a playbook (via `community.sops.load_vars`), never `sops` itself. ISSUE-022: the `sops` binary isn't even installed there — playbooks that need to decrypt must `delegate_to: localhost` (meaning `ac-devops`, the Ansible control node), not the target host. |
| CI runners | No | This repo's validation gate is local-first (`scripts/validate.ps1`); no CI pipeline holds a copy of the key. |

## Reasoning

A single key, on a single host, with every consumer SSHing in to use it, is a
deliberate reduction of attack surface over "every operator has a copy." It
also makes rotation tractable — see `secrets/README.md` for the (separate,
by-hand) age-key-rotation runbook.

## Backup

`backup-age-key-to-keepass.sh` is the last line of defense if `ac-devops` is
lost: it mirrors the key into the KeePass root group under the entry name
`sops-age-key`. It is idempotent — safe to re-run after every key rotation or
on a schedule — and never prints the key to stdout; it pipes directly from the
remote file into the KeePass CLI import.

Restoring from that backup still means provisioning a *new* `ac-devops`-
equivalent host and placing the key at the same path — this inventory does
not change as a result of a restore; it's still "exactly one host."
