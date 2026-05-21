---
name: ac-opbta-ops
description: Repository-specific operator knowledge for AC_OPBTA (Ansible, Semaphore, SOPS, Proxmox, Docker, SSH, Tailscale, OpenVPN, WireGuard, Unbound, Pi-hole, Wazuh, OPNsense, Traefik, Prometheus/Grafana/Loki, ntopng, ntfy, Uptime Kuma, Cloudflare). Use whenever the user asks about this home-network repo's tooling, wants to deploy a new service, change firewall rules, read a SOPS-encrypted secret, diagnose a VLAN or Pi-hole issue, or troubleshoot any playbook/role in here — even if the tool isn't named explicitly (e.g. "add a rule so the IoT VLAN can reach Wyzebridge", "spin up a container for X", "what's the admin password for Y").
---

# AC_OPBTA Ops Skill

This skill is the index into operator knowledge for the `AC_OPBTA` repo. It does **not**
duplicate runbooks — it points at them and holds only the cross-cutting invariants.

## When this skill applies

- The user mentions any tool in the stack below *and* the work is operational
  (deploy, change, diagnose, read) rather than purely theoretical.
- The user invokes `/new-deployment`, `/new-firewall-rule`, or `/get-secret`.
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
- **Semaphore** — web UI for scheduled / on-demand playbook runs at `devops.opbta.com`.
  Secrets in `secrets/semaphore.enc.yml`. See `scripts/phases/10-semaphore-deploy.sh`.
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

## Slash commands

This skill exposes a set of thin commands. The mutating ones scaffold artifacts in the repo
*and* apply them end-to-end via `ac-devops`. The read-only commands run a committed
helper script and report.

**Mutating (scaffold → PR → apply):**

- `/new-deployment` — see `.claude/commands/new-deployment.md`
- `/retire-service` — see `.claude/commands/retire-service.md`. Inverse of
  `/new-deployment`: removes the catalog entry, role wiring, compose fragment,
  Cloudflare + Unbound DNS, Traefik route, and (optionally) the OIDC client +
  SOPS secrets + dashboard tile. Backs every removed file up under
  `docs/audits/<date>-retired-<name>/` before deleting; acquires the ac-devops
  coordination lock before applying. Trigger: a deprecated service is the
  third one we've removed by hand (commit `f8e0d95` removed wyzebridge /
  searxng / ollama; the Semaphore retirement made two).
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

## References (load on demand)

- `references/knowledge-map.md` — full tool → authoritative-doc lookup table.
- `references/deployment-targets.md` — docker / LXC / VM decision matrix + scaffold templates.
- `references/firewall-rule-shape.md` — `ansibleguy.opnsense.rule` field cheatsheet and known
  workarounds for ISSUE-001 / ISSUE-008.
- `references/secrets-map.md` — app-name → `secrets/*.enc.yml` → known keys.

Read these only when the current task requires them. Most work is a one-shot lookup
against the tool index above plus a pointer to a runbook.
