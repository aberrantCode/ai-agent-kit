# bridge.md — locate AC_OPBTA, worktree, ac-devops lock, apply pattern

How the `opbta-service` dispatcher crosses from *any* source repo into `AC_OPBTA`
and runs that repo's own lifecycle commands. This is glue only — the lifecycle
logic lives in `AC_OPBTA`'s command files (see `lifecycle-map.md`).

## 1. Resolve source-repo context

Establish which service the caller means, in this order (see `routing.md` for the
full target-resolution matrix):

1. **Explicit arg** — `/opbta-update pihole` → slug `pihole`.
2. **`.opbta-service` breadcrumb** — a one-line file at the source repo root
   holding the slug only (zero metadata leakage). Example: `tax_research/.opbta-service`
   contains the single token `taxes`.
3. **Service picker** — no arg and no breadcrumb → prompt (see `service-picker.md`).

## 2. Locate AC_OPBTA

- **Default checkout:** `C:\development\AC_OPBTA`.
- **Fallback:** git discovery — if the default path is absent, search the
  workstation's `development` roots for a checkout whose remote is the `AC_OPBTA`
  repo, or ask the operator.
- Operate against the **main checkout** only to read; all mutation happens in a
  worktree (next step). The operator edits the main checkout concurrently —
  sharing it causes stale-branch reverts and PRs that bundle two sessions' work
  (`AC_OPBTA/.claude/rules/agent-concurrency.md`).

## 3. Work in a worktree (mutating ops only)

Every mutating lifecycle op (`create` / `update` / `retire` / mutating `manage`)
runs from a git worktree created by AC_OPBTA's own helper:

```bash
cd /c/development/AC_OPBTA
bash scripts/agent-worktree-setup.sh <type>/<op>-<slug>   # e.g. chore/update-pihole
cd .worktrees/<short>
```

Read-only ops (`inspect`, `list`, `update --check-only`) touch no files and need
**no** worktree.

## 4. Acquire the ac-devops coordination lock

Applying a change mutates shared state on `ac-devops` (`ubuntu@192.168.30.15`,
the only host with the SOPS age key and the Ansible venv). AC_OPBTA's phase
helpers own the lock — do not reimplement it:

```bash
source scripts/phases/common.sh
source scripts/phases/ac-devops-lock.sh
_ansible_isolate_ssh_mux                      # isolate ssh ControlMaster per run
branch=$(git rev-parse --abbrev-ref HEAD)
ac_devops_lock_acquire "opbta-<op>-<slug>" "$branch" || exit 1
trap ac_devops_lock_release EXIT
```

Lock file: `/home/ubuntu/.ac-devops-apply.lock` (JSON, 1800s TTL, release scoped
to `agent_id`). Read-only probes do **not** take the lock.

## 5. Apply pattern (two-pass idempotency + smoke test)

The lifecycle command AC_OPBTA defines (`add/update/retire-service.md`) carries
the authoritative apply steps. The invariant the dispatcher enforces regardless
of which command runs:

- **Run the scaffolded deploy script** — never invoke `ansible-playbook` by hand
  (that bypasses the smoke-test gate; it is how termix/PR #628 shipped a 404).
- **Two passes.** Pass 1 applies; **pass 2 must report `changed=0`.** A pass 2
  with `changed=[1-9]` means template non-determinism (classically a `now()` in
  a Jinja template) — STOP, do not claim success.
- **Smoke test is the only acceptance signal.** Use AC_OPBTA's
  `scripts/phases/smoke-test-fqdn.sh` three-perspective probe (workstation DNS /
  public DoH / direct-to-Traefik). A 404/502 means the deploy FAILED — never
  "deployed with a blocker."
- **Open a PR, never auto-merge** (see `routing.md` autonomy rules).

## Key invariants (from the `ac-opbta-ops` skill — the REQUIRED BACKGROUND)

| Invariant | Value |
|---|---|
| Control node (env-changing Ansible) | `ssh ubuntu@192.168.30.15` → `~/repos/AC_OPBTA` |
| SOPS age key (only host that has it) | `ubuntu@192.168.30.15:~/.config/sops/age/keys.txt` |
| Metadata SoT | `AC_OPBTA/inventory/services.yml` |
| Git workflow | feature branch → PR → `dev`; never push `dev`/`main` directly |
| Scripts, not commands | every action lands in a committed idempotent `scripts/*.sh` |

**HARD INVARIANT (dispatcher-wide): never push an image to an external/public
registry.** Registry-less services are built off-host and shipped
`docker save | ssh | docker load` (see `manifest-schema.md` → `source:` block).
