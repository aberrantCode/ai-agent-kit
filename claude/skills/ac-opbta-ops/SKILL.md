---
name: ac-opbta-ops
category: Tooling & DevOps
description: Repository-specific operator knowledge for AC_OPBTA (Ansible, Semaphore, SOPS, Proxmox, Docker, SSH, Tailscale, OpenVPN, WireGuard, Unbound, Pi-hole, Wazuh, OPNsense, Traefik, Prometheus/Grafana/Loki, ntopng, ntfy, Uptime Kuma, Cloudflare, XPipe). Use whenever the user asks about this home-network repo's tooling, wants to deploy a new service, change firewall rules, read a SOPS-encrypted secret, diagnose a VLAN or Pi-hole issue, manage XPipe connections / identities on the workstation, or troubleshoot any playbook/role in here — even if the tool isn't named explicitly (e.g. "add a rule so the IoT VLAN can reach Wyzebridge", "spin up a container for X", "what's the admin password for Y").
---

# AC_OPBTA Ops Skill

This skill is the index into operator knowledge for the `AC_OPBTA` repo. It does **not**
duplicate runbooks — it points at them and holds only the cross-cutting invariants.

## When this skill applies

- The user mentions any tool in the stack below *and* the work is operational
  (deploy, change, diagnose, read) rather than purely theoretical.
- The user invokes `/add-service`, `/new-firewall-rule`, or `/get-secret`.
- The user asks "how do I…" about anything in `playbooks/`, `roles/`, `scripts/`,
  or `secrets/`.

If the task is pure code authoring in an unrelated part of the tree (e.g. editing
`docs/llms/chatgpt_instructions.md`), don't use this skill.

## Invariants (memorise these — they are repo-wide)

| Invariant | Value |
|---|---|
| Control node (where env-changing Ansible runs) | `ssh ubuntu@192.168.30.15` → `~/repos/AC_OPBTA` |
| Windows local runner (bootstrap, syntax-check, dry-run only) | `powershell -ExecutionPolicy Bypass -File .\scripts\ansible-playbook.ps1 …` |
| SOPS age key (canonical, **only host that has it**) | `ubuntu@192.168.30.15:~/.config/sops/age/keys.txt` |
| SOPS env var for CLI (set on the host where you run `sops`) | `export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt` |
| Secret loading in playbooks | `community.sops.load_vars` with `name: X_creds` (NOT `vars_files:`) |
| `ac-firewall` Ansible connection | `ansible_connection: local`, `ansible_become: false` |
| Ansible venv on ac-devops | `/home/ubuntu/.local/share/pipx/venvs/ansible/bin/` |
| Git workflow | feature branch → PR → `dev`; release PR `dev` → `main`. **Never** push directly to `dev` or `main`. |
| Scripts, not commands | Every action goes into a committed `scripts/*.sh`; idempotent; `set -euo pipefail` |

## VLAN ↔ OPNsense `opt*` interface map

The `ansibleguy.opnsense.rule` module requires `opt*` identifiers, NOT UI descriptions
(CLAUDE.md ISSUE-008). Role defaults expose these as `opnsense_if_*` vars — use the var,
not the literal `optN`.

| VLAN | CIDR | OPNsense if | Role var |
|---|---|---|---|
| 10 Management | `192.168.10.0/24` | `opt2` | `opnsense_if_mgmt` |
| 20 Trusted | `192.168.20.0/24` | `opt3` | `opnsense_if_trusted` |
| 30 Servers | `192.168.30.0/24` | `opt4` | `opnsense_if_servers` |
| 40 IoT | `192.168.40.0/24` | `opt5` | `opnsense_if_iot` |
| 50 Guest | `192.168.50.0/24` | `opt6` | `opnsense_if_guest` |
| 60 Untrusted | `192.168.60.0/24` | `opt7` | `opnsense_if_untrusted` |
| 70 VPN clients | `192.168.70.0/24` | `opt8` | `opnsense_if_vpn` |
| 99 Quarantine | `192.168.99.0/24` | `opt9` | `opnsense_if_quarantine` |

## Tool index (one blurb + pointer each)

Each entry: **what it does here · where it lives · authoritative doc · top gotcha (if any)**.

### Configuration management

- **Ansible** — declarative config for every non-Windows host. Playbooks in `playbooks/`,
  roles in `roles/`. Runs from `ac-devops`. See `docs/runbooks/config-mgmt--ansible-control-node.md`.
  *Gotcha:* `community.general.yaml` callback was removed in ansible-core 2.20 — stick
  with `result_format = yaml` (CLAUDE.md ISSUE-006).
- **Semaphore** — retired 2026-05-27. The repo's "scripts not commands" culture
  + Claude Code-driven SSH runs replaced the UI. Closure narrative in
  `docs/tasks/archive/backlog.md` ("Retire Semaphore — closed 2026-05-27").
  ADR-006 update notes the retirement; the Ansible + SOPS + age portion of
  ADR-006 stands.
- **SOPS + age** — encrypts `secrets/*.enc.yml` before commit. See `secrets/README.md`.
  For credential reads/writes (admin logins, password rotation, KeePass mirror,
  SOPS health probes), use the dedicated **`sops-secrets` skill** at
  `.claude/skills/sops-secrets/SKILL.md` — it owns the full set of
  `/get-service-auth`, `/update-auth`, `/rotate-service-password`,
  `/list-service-auth`, `/sync-keepass`, `/sops-status` commands and pins
  every operation to ac-devops (the only host with the age key).
  *Gotcha 1:* `vars_files:` does NOT decrypt SOPS — use `community.sops.load_vars`
  (CLAUDE.md ISSUE-004). *Gotcha 2:* Never run `sops` from the workstation —
  the age key isn't there. Always shell to ac-devops; the sops-secrets scripts
  do this automatically.

### Network / firewall

- **OPNsense** — firewall on `ac-firewall` (192.168.10.1). Managed via REST API from ac-devops
  using the `ansibleguy.opnsense` collection (v1.2.16). Playbook: `playbooks/firewall.yml`,
  role: `roles/opnsense/`. See `docs/runbooks/proxmox-cluster-and-opnsense-firewall.md`.
  *Gotchas:* `ansible_become: false` required (ISSUE-013); `api_port` not `port`
  (ISSUE-007); `'NoneType' object is not iterable` workaround (ISSUE-001).
- **Pi-hole + Unbound** — collated on `ac-unbound` (192.168.30.5). Role: `roles/pihole/` +
  `roles/unbound/`. Playbook: `playbooks/dns.yml`. See `docs/decisions/ADR-003-dns-architecture.md`.
  *Note:* group name in inventory is `pihole` but the host is `ac-unbound` (project-memory).
- **ntopng** — NetFlow/IPFIX collector. Role `roles/ntopng/`, runs on `ac-docker1`. OPNsense
  exports via `roles/opnsense/tasks/netflow.yml`.
  *Status:* ntopng foundations shipped in PR #348 and the role + dashboard remain
  in production, but the original nProbe-paired vision was abandoned (300s demo
  cap without a paid license) — per-host traffic visibility pivoted to Suricata
  eve.json → Loki + goflow2 NetFlow → Promtail. See project memory
  `project_ntopng_traffic_visibility.md`. New per-host traffic queries should
  reach for Suricata / goflow2 first; ntopng remains valid for live-flow
  dashboards and protocol pie charts.

### Hypervisor

- **Proxmox VE 9** — 2-node cluster (`ac-svr1` + `ac-svr2`) with `ac-qdevice` for quorum.
  VM provisioning: `scripts/provision-vm.sh` and `scripts/phases/04b-create-linux-vms.sh`.
  See `docs/runbooks/hypervisor--vm-provision.md` and `docs/decisions/ADR-011-proxmox-vm-provisioning.md`.
- **Docker** — observability stack runs as compose fragments on `ac-docker1` (192.168.30.17).
  Generic role: `roles/docker_compose_stack/`; per-service roles add fragments. See
  `docs/decisions/ADR-012-monitoring-deployment-model.md`.
- **SSH** — `ansible` user with `~/.ssh/id_ed25519` key on all Linux hosts. `ubuntu` user
  on `ac-devops`. Never use password auth in playbooks.

### Remote access

- **WireGuard** — primary VPN, UDP 13231. Role: `roles/wireguard/`. Playbook: `playbooks/vpn.yml`.
  See `docs/decisions/ADR-005-vpn-strategy.md`.
- **OpenVPN** — TCP/443 fallback for networks that block UDP. Role: `roles/openvpn/`.
  Same playbook. *Note:* `roles/opnsense/tasks/openvpn.yml` is still a stub per backlog.
- **Tailscale** — mesh for admin access. Role: `roles/tailscale/`. Enrollment via auth key
  from `secrets/tailscale.enc.yml` (use `secrets/tailscale.example.yml` as template).

### Observability

- **Wazuh** — SIEM on `ac-wazuh` (192.168.30.66). Playbook: `playbooks/wazuh.yml`, agents
  deployed via `playbooks/wazuh-agents.yml`. Secrets in `secrets/wazuh.enc.yml`.
  See `docs/decisions/ADR-004-log-aggregation.md`, `docs/runbooks/security--wazuh-post-deploy.md`.
- **Prometheus + Grafana + Loki + Promtail + Alertmanager** — on `ac-docker1`, one compose
  fragment each under `roles/prometheus/`, `roles/grafana/`, etc. Playbook:
  `playbooks/observability.yml`. See `docs/decisions/ADR-012-monitoring-deployment-model.md`.
- **ntfy** — push alerts. Role: `roles/ntfy/`. See `docs/decisions/ADR-007-alerting-pipeline.md`.
- **Uptime Kuma, Blackbox, cadvisor, node_exporter** — each has a role under `roles/`;
  all part of the observability stack.

### Ingress / DNS

- **Traefik + tls_acme** — reverse proxy on `ac-docker1`. Public services terminate TLS
  here with Let's Encrypt via Cloudflare DNS-01. Roles: `roles/traefik/`, `roles/tls_acme/`.
  Secrets: `secrets/tls.example.yml` → `secrets/tls.enc.yml`, `secrets/cloudflare.enc.yml`.
  See `docs/decisions/ADR-010-reverse-proxy-strategy.md`.
- **Cloudflare** — public DNS for `opbta.com`. API token in `secrets/cloudflare.enc.yml`.
- **Windows DNS** — AD-integrated DNS on `ac-dc1` / `ac-dc2`. Role: `roles/windows_dns/`.
  Internal names resolve via split-brain forwarders on Unbound.

### Media

- **Emby** — media server, containerised on the **ac-nas Synology** (DSM Container
  Manager), `http://192.168.30.11:8096`, `emby.svc.opbta.com` / public
  `emby.opbta.com`. Catalog: `inventory/services.yml` → `emby`. For ANY Emby
  question — logins, "can't log in", missing thumbnail / chapter / trickplay
  preview images, transcoding, scheduled tasks, library settings, updating the
  server — use the dedicated **`emby` skill** at `.claude/skills/emby/SKILL.md`.
  It owns the access model (API + ac-nas filesystem; `core` has **no** docker/root),
  the credential-drift footgun (`scripts/set-emby-sops-password.sh` after any UI
  password change), the chapter-image toggle + 4.9 storage change, and
  `scripts/debug/diag-emby-trickplay-generation.sh`.
  *Gotcha:* a `401` from the API = SOPS↔live password drift, not a dead server.

### Workstation tooling

- **XPipe** — connection hub on operator workstations. Used to launch SSH / RDP /
  Proxmox / Docker sessions against the fleet from a single GUI. Inventory group:
  `xpipe_workstations` in `inventory/hosts.yml`. Repo-managed surface:
  - `roles/xpipe_api/` + `playbooks/xpipe_api.yml` — renders the XPipe HTTP API
    handshake, categories, and discovery shape (`ansible_connection: local` on
    the workstation, no SSH out).
  - `scripts/apply-xpipe-connections.sh` / `scripts/verify-xpipe-connections.sh` —
    bulk-add hosts (Proxmox, LXC, Docker stacks) into the local XPipe vault from
    inventory.
  - `scripts/apply-xpipe-proxmox.sh` / `scripts/verify-xpipe-proxmox.sh` — the
    Proxmox parents that XPipe uses to enumerate LXCs/VMs via the API.
  - **Vault state lives in** `%USERPROFILE%\.xpipe\storage\` (Windows). The
    workstation has its own git remote at `https://github.com/aberrantCode/xpipe-vault.git`
    so identity + connection state survives reinstalls.
  - **Local API auth:** handshake against `http://127.0.0.1:21721/handshake` with
    the contents of `%LOCALAPPDATA%\Temp\xpipe\beacon-auth` (auth type `Local`);
    use the returned `sessionToken` as `Authorization: Bearer …` for subsequent
    calls.
  - **Identity gotcha:** `SyncedIdentityStore.password` decrypts and then re-parses
    as JSON. When encrypting a credential via `/secret/encrypt`, send the
    JSON-quoted form of the password (e.g. `"TEmp12!@"` not `TEmp12!@`), or the
    server rejects the resulting identity with an "Unrecognized token" 400.
  - **SSH/RDP store identity reference:** `{"type":"ref","ref":{"storeId":"<uuid>"}}`
    points at an existing synced identity; `{"type":"inPlace","identityStore":{...}}`
    embeds credentials inline (see `IdentityValue.java` in xpipe-io/xpipe).
  - **Workstation post-provisioning automation** (kept under `scripts/`, ASCII-only `.ps1`
    per `.claude/rules/scripts.md`): 
    - `scripts/xpipe-import-erik-domain-identity.ps1` — imports `ad.opbta.com\erik`
      from SOPS into XPipe vault, auto-discovers all Windows hosts from inventory,
      creates SSH and RDP connections for each. Idempotent; reads from
      `inventory/hosts.yml` dynamically.
    - `scripts/sync-xpipe-windows-hosts.sh` — wrapper that verifies XPipe is running
      and calls the PS script. Intended for post-provisioning automation hooks.
    - `playbooks/xpipe-workstation-sync.yml` — Ansible playbook that runs on
      localhost and invokes the sync script. Can be called as part of the
      provisioning flow or manually after adding Windows hosts to inventory.
  - **Integration**: When a new Windows host is added to `inventory/hosts.yml` in
    the `windows_servers` group, run `bash scripts/sync-xpipe-windows-hosts.sh` to
    automatically create SSH + RDP connections in the vault. This should be
    automated as part of the `/add-host` command flow.

## Slash commands

This skill exposes a set of thin commands. The mutating ones scaffold artifacts in the repo
*and* apply them end-to-end via `ac-devops`. The read-only commands run a committed
helper script and report.

**Mutating (scaffold → PR → apply):**

- `/add-service` — see `.claude/commands/add-service.md`
- `/retire-service` — see `.claude/commands/retire-service.md`. Inverse of
  `/add-service`: removes the catalog entry, role wiring, compose fragment,
  Cloudflare + Unbound DNS, Traefik route, and (optionally) the OIDC client +
  SOPS secrets + dashboard tile. Backs every removed file up under
  `docs/audits/<date>-retired-<name>/` before deleting; acquires the ac-devops
  coordination lock before applying. Trigger: a deprecated service is the
  third one we've removed by hand (commit `f8e0d95` removed wyzebridge and
  ollama, plus searxng — which has since been redeployed under Authentik
  forward-auth; the Semaphore retirement made two).
- `/new-firewall-rule` — see `.claude/commands/new-firewall-rule.md`
- `/rotate-secret` — see `.claude/commands/rotate-secret.md`. Same shape as
  `/get-secret`, but writes: rotate a single key in any `secrets/*.enc.yml`
  (generated 48-hex value or `--value <v>`), commit + push to the current
  feature branch, sync KeePass. For non-auth secrets (PSKs, webhook URLs,
  internal API tokens). Refuses keys owned by the auth catalog and refuses
  to create new keys — those go through `/update-auth` /
  `/rotate-service-password` or a manual `sops` edit on ac-devops
  respectively. No auto-apply (the consuming role is generally ambiguous
  for arbitrary keys).
- `/add-host` — see `.claude/commands/add-host.md`. End-to-end VM/LXC
  provisioning: `AskUserQuestion` interview (type, VLAN, OS tag, CPU/RAM/disk,
  IP, inventory groups, monitor/logs flags), generates a per-guest `.env`,
  runs `scripts/provision-{vm,lxc}.sh` on the right Proxmox node, patches
  `inventory/{hosts,devices,services,proxmox-os-tags}.yml`, runs an
  `ansible -m ping` bootstrap, opens a PR. Refuses on hostname / IP / VMID
  / VLAN / OS-tag collisions; uses the ac-devops coordination lock and the
  workstation lock.

**Read-only (run committed helper, no PR):**

- `/get-secret` — see `.claude/commands/get-secret.md`. Lower-level: extracts a
  single key from any `secrets/*.enc.yml`. Use this for non-auth secrets (PSKs,
  webhook URLs, internal API tokens between services). Pair with
  `/rotate-secret` for the write side.
- `/get-service-auth` — see `.claude/commands/get-service-auth.md`. Higher-level:
  given a service name (e.g. `grafana`, `portainer`), returns the URL + admin
  username + admin password as three printable lines. Catalog-driven via
  `.claude/skills/sops-secrets/references/services-auth-catalog.yml`.
- `/list-service-auth [filter]` — see `.claude/commands/list-service-auth.md`.
  Enumerates every service in the auth catalog with its source file + key paths.
- `/sops-status` — see `.claude/commands/sops-status.md`. Diagnoses the SOPS
  pipeline (SSH reach, age key, sops binary, parser tooling, KeePass mirror).
- `/check-hosts [scope]` — see `.claude/commands/check-hosts.md`. Probes
  REACH / AUTH / SERVICE for every host in scope (group from `inventory/hosts.yml`,
  single host, or `all`). Auto-routes through ac-devops when run from a host without
  ansible on PATH.

**Mutating credentials (sops-secrets skill — see `.claude/skills/sops-secrets/SKILL.md`):**

- `/update-auth` — set username and/or password for a service. Edits via
  `sops --set` on ac-devops, commits to current branch, syncs KeePass,
  auto-runs the consuming playbook.
- `/rotate-service-password` — same but generates a strong password first
  (`openssl rand -hex 24`).
- `/sync-keepass` — re-mirror SOPS → KeePass on demand.

The mutating commands: (1) use `AskUserQuestion` to fill missing parameters, (2) write a committed
script under `scripts/` that does the real work, (3) open a PR to `dev`, (4) apply the
change from `ac-devops`, (5) report status.

**Slash commands do not bypass review.** Each one is a convenience wrapper
around the canonical Ansible / PR / apply flow; the mutating commands still
open a PR to `dev` and the read-only commands still just run a committed
script. Anything that looks like "this slash command skips review" is a bug
in either the command or this skill — file it, don't work around it.

## Helper-script registry

Reusable libraries under `scripts/phases/` that other scripts source. New
scripts MUST use these helpers instead of re-implementing the same shape —
each one closes a specific footgun and is mandated by a path-specific rule
in `.claude/rules/`. Phase-numbered files (`01-…`, `02-…`, the `07*-…`
monitoring family, `08-pihole.sh`, etc.) are end-to-end deploy scripts and
are not indexed here — they are not designed to be sourced.

| Helper | Path | Purpose | Canonical rule |
|---|---|---|---|
| `common.sh` | `scripts/phases/common.sh` | Shared bash library every phase script sources. Provides Windows-aware `WIN_SSH` / `WIN_SCP` resolution, `--key` / `--config` arg parsing (`_common_parse_args`), the output helpers below, and `_ansible_isolate_ssh_mux` (see sub-bullets). | `.claude/rules/scripts.md` § Helpers |
| ├─ `log()` / `ok()` / `fail()` / `die()` / `section()` | functions in `common.sh` | Standard output decoration — informational line, green ✓, red ✗, exit-non-zero, visual section header. Don't reinvent. | `.claude/rules/scripts.md` § Helpers |
| └─ `_ansible_isolate_ssh_mux` | function in `common.sh` | Exports a unique `ANSIBLE_SSH_CONTROL_PATH_DIR` per-run so concurrent ansible calls don't queue behind a wedged ssh-mux socket on ac-devops. Installs an EXIT trap to clean up. | `.claude/rules/ac-devops-coordination.md` § ssh ControlMaster contention |
| `gen-password.sh` | `scripts/phases/gen-password.sh` | Source-only library. `gen_password [BYTES]` returns clean `openssl rand -hex` output — never produces trailing `\n` or URL-unsafe chars. Closes ISSUE-098 (HortusFox-deploy footgun where `tr`/`head -c` chains let newlines into bcrypted passwords). | `.claude/rules/scripts.md` § Hard rules — "Use `openssl rand -hex N` for passwords" |
| `ac-devops-lock.sh` | `scripts/phases/ac-devops-lock.sh` | Coordination lock for scripts that mutate ac-devops shared state. `ac_devops_lock_acquire OP BRANCH [TTL]` / `ac_devops_lock_release` / `ac_devops_lock_status`. Lock file `/home/ubuntu/.ac-devops-apply.lock`, JSON, 1800s TTL, release scoped to `agent_id`. | `.claude/rules/ac-devops-coordination.md` |
| `workstation-lock.sh` | `scripts/phases/workstation-lock.sh` | Workstation-side analogue of `ac-devops-lock.sh`. Lock file `$HOME/.ac-opbta-workstation-agent.lock`. Use when a mutating script can't be isolated by a worktree (e.g. shared `~/.ansible/cp/`, `secrets/` rotation). | `.claude/rules/agent-concurrency.md` § Workstation lock |
| `ac-devops-repo-reset.sh` | `scripts/phases/ac-devops-repo-reset.sh` | Recovery helper: when ac-devops' repo is wedged on a stale branch or has untracked files that would collide with a clean checkout, archives WIP to `/home/ubuntu/ac-devops-wip-backup-<UTC>.tar.gz` then `git reset --hard origin/dev`. Acquires the lock; destructive ops gated on successful tar. | `.claude/rules/ac-devops-coordination.md` § Recovery |
| `smoke-test-fqdn.sh` | `scripts/phases/smoke-test-fqdn.sh` | `smoke_test_fqdn FQDN TRAEFIK_IP STATUS...` — probes a freshly-shipped FQDN from three perspectives (workstation DNS / public DoH / direct-to-Traefik) so a deploy can't pass while real clients get NXDOMAIN. Auto-skips the public perspective for internal-only `.svc.opbta.com` names. Also carries the **deprecated** `smoke_test_dashboard_contains` shim (delegates to `verify_dashboard_tile`). | `.claude/rules/scripts.md` § Helpers |
| `verify-dashboard-tile.sh` | `scripts/phases/verify-dashboard-tile.sh` | `verify_dashboard_tile SERVICE_KEY` — verify a service actually renders as a tile on the catalog. Replaces 17 copy-pasted inline `curl \| grep` checks that could never pass once the catalog went behind Authentik (2026-06-26). Reads the rendered HTML via the dashboard's macvlan IP (auth-bypassing), matches the FQDN (not the slug — bare slugs false-positive), and **validates its own probe** before trusting a 0 result. rc: 0 present · 1 repo-side (no/hidden catalog row) · 2 render-side (real missing tile) · 3 probe-side (check itself broken — NOT a tile verdict). | `.claude/rules/scripts.md` § Helpers |

**Required call pattern for a mutating phase script** (the union of the
canonical patterns from the rules above):

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/ac-devops-lock.sh"
_common_parse_args "$@"
_ansible_isolate_ssh_mux        # if the script drives ansible-playbook

branch=$(git -C "$SCRIPT_DIR/../.." rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
ac_devops_lock_acquire "my-phase-script-name" "$branch" || exit 1
trap ac_devops_lock_release EXIT
```

Read-only probes (`check_ssh`, status queries, non-mutating greps) do NOT
acquire the lock.

## References (load on demand)

- `references/knowledge-map.md` — full tool → authoritative-doc lookup table.
- `references/deployment-targets.md` — docker / LXC / VM decision matrix + scaffold templates.
- `references/firewall-rule-shape.md` — `ansibleguy.opnsense.rule` field cheatsheet and known
  workarounds for ISSUE-001 / ISSUE-008.
- `references/secrets-map.md` — app-name → `secrets/*.enc.yml` → known keys.

Read these only when the current task requires them. Most work is a one-shot lookup
against the tool index above plus a pointer to a runbook.

## Diagram

[View diagram](diagram.html)
