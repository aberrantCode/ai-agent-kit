# lifecycle-map.md — verb → AC_OPBTA command / script mapping

The dispatcher owns **no** lifecycle logic. Each `/opbta-*` command resolves to
AC_OPBTA's own command file (or helper script) and FOLLOWS it as the source of
truth. Paths are relative to the located `AC_OPBTA` checkout (see `bridge.md`).

## Mutating ops (scaffold → PR → apply)

| Dispatcher command | AC_OPBTA source of truth | Shape |
|---|---|---|
| `/opbta-create` | `.claude/commands/add-service.md` | Verify upstream image + IP availability, clone a known-good reference role, wire DNS + reverse-proxy, open a PR, apply from ac-devops with two-pass idempotency + smoke test. Reroutes to update if slug exists. |
| `/opbta-update` | `.claude/commands/update-service.md` | Resolve the current pin, check for a newer release, read the upstream changelog for breaking changes, bump the pin (tag+digest in lockstep), re-apply two-pass, smoke-test, open a PR. In place only — never changes IP/FQDN/auth/network. Reroutes to create if slug absent. |
| `/opbta-retire` | `.claude/commands/retire-service.md` | Inverse of create: remove catalog entry, role dir, compose fragment, Cloudflare + Unbound DNS, Traefik route, optional OIDC client + SOPS secrets + dashboard tile. Backs up removed files under `docs/audits/<date>-retired-<name>/` first. Opens a PR; applies with the lock held. |

Each of these AC_OPBTA command files itself loads
`AC_OPBTA/.claude/references/deployment-targets.md` for the docker/LXC/VM
scaffold + apply pattern per target type. Let the command file drive — do not
pre-empt its steps.

## Pin-style detection (update path)

`/opbta-update` branches on how the service pins its image (AC_OPBTA
`update-service.md` Step 3). Know which, because the bump edits a different file:

| Pin style | Where the pin lives | Version source |
|---|---|---|
| 3a — central registry (observability family) | `roles/_monitoring_images/vars/main.yml` → `monitoring_images.<name>` (`repo`/`tag`/`digest`) | registry tag list |
| 3b — per-role pin | `roles/<name>/defaults/main.yml` (`<name>_image_repo`/`_tag`/`_digest` triple) | registry tag list |
| 3c — LXC/VM (no image) | n/a — snapshot then run the service's own updater (like Pi-hole) | service's own version source |
| 3d — docker, registry-less (`source:` block) | `roles/<name>/defaults/main.yml` → `<name>_image` **and** `scripts/deploy-<name>.sh` → `IMAGE`, in lockstep | upstream GitHub **release tag** |

See `manifest-schema.md` for the `source:` block that marks a 3d service.

## Read-only / day-2 ops

| Dispatcher command | Backing | Shape |
|---|---|---|
| `/opbta-inspect` | `inventory/services.yml` + live probes | Deep read on one service — catalog row, live reachability (three-perspective smoke probe), version pin, auth/DNS/Traefik shape. No mutation, no lock, no PR. |
| `/opbta-manage` | per-action helper scripts + ac-devops | Day-2 ops: restart/stop/start, re-expose, rotate a secret, rename/move/resize. Mutating actions take the lock + open a PR; benign queries don't. Secret rotation delegates to the `sops-secrets` skill (`/rotate-service-password`, `/update-auth`). |
| `/opbta-list` | `inventory/services.yml` | Catalog-wide read: enumerate every service with health/drift summary. No mutation. |

## Shared AC_OPBTA phase helpers (source, don't reimplement)

Under `AC_OPBTA/scripts/phases/` — sourced by the apply path (see `bridge.md`):

| Helper | Purpose |
|---|---|
| `common.sh` | Shared bash lib: `log`/`ok`/`fail`/`die`/`section`, arg parsing, `_ansible_isolate_ssh_mux`. |
| `ac-devops-lock.sh` | `ac_devops_lock_acquire` / `_release` / `_status` — coordination lock on ac-devops shared state. |
| `ensure-ac-devops-on-dev.sh` | Refuse-if-dirty + hard-reset ac-devops to origin/dev; checkout feature branch to pick up not-yet-merged catalog rows; trap-safe return to dev. |
| `smoke-test-fqdn.sh` | `smoke_test_fqdn FQDN TRAEFIK_IP STATUS...` — three-perspective reachability probe (workstation DNS / public DoH / direct-to-Traefik). The only acceptance signal. |
| `verify-dashboard-tile.sh` | `verify_dashboard_tile SERVICE_KEY` — confirm the service renders as a catalog tile. |
| `gen-password.sh` | `gen_password [BYTES]` — clean `openssl rand -hex`, no trailing newline / URL-unsafe chars. |

Phase-numbered scripts (`08-pihole.sh`, the `07*` monitoring family, etc.) are
end-to-end deploy scripts, not sourceable libraries — invoke, don't source.
