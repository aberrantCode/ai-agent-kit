# routing.md — auto-route matrix + plan-gate rules

How the dispatcher picks the right op from the command invoked and the catalog
state, and the autonomy contract once it does.

## Target resolution order

For any op that names (or implies) a service:

1. **Explicit arg** — `/opbta-update pihole` → slug `pihole`.
2. **`.opbta-service` breadcrumb** — slug-only file at the source repo root.
3. **Service picker** — neither present → prompt (see `service-picker.md`).

## Auto-route matrix

The create/update pair is **self-correcting on catalog presence** — the operator
can't pick the wrong verb. "Present" = a key exists under `services:` in
`inventory/services.yml`.

| Command invoked | Slug in catalog? | Action |
|---|---|---|
| `/opbta-create <slug>` | **no** | Proceed with create (scaffold end-to-end). |
| `/opbta-create <slug>` | **yes** | **Reroute to `/opbta-update`** — the service exists; creating would collide. Announce the reroute. |
| `/opbta-update <slug>` | **yes** | Proceed with update (bump/reconcile in place). |
| `/opbta-update <slug>` | **no** | **Reroute to `/opbta-create`** — nothing to update. Announce the reroute. |
| `/opbta-retire <slug>` | **no** | STOP — refuse; a service not in the catalog has no inverse to remove. List valid keys. |
| `/opbta-retire <slug>` | **yes** | Proceed with retire. |
| `/opbta-inspect <slug>` | **no** | STOP — nothing to inspect; list valid keys. |
| `/opbta-inspect <slug>` | **yes** | Proceed (read-only). |
| `/opbta-manage <slug> <action>` | **yes** | Proceed with the day-2 action. |
| `/opbta-manage <slug> <action>` | **no** | STOP — list valid keys. |
| `/opbta-list` | n/a | Catalog-wide read; no slug needed. |

Rerouting is a convenience, not a bypass: the rerouted op runs its own full
flow (worktree, lock, plan-gate, two-pass, smoke test, PR).

## Plan-gate rules (the autonomy contract)

**ONE plan-gate approval, then autonomous to an opened PR — never auto-merge.**

1. **Resolve + plan silently.** Read the catalog, resolve the version/delta/scope,
   and build the operator-facing plan. For `update`, this includes reading the
   upstream changelog and classifying breaking changes (AC_OPBTA
   `update-service.md` Step 5 — the load-bearing step).
2. **Single `AskUserQuestion` plan-gate.** Present the plan and get ONE approval
   before any file mutation. Batch all decisions into that one gate — don't drip
   serial questions. (Mutating ops only; read-only ops skip the gate.)
3. **Then run autonomously** through: worktree → ac-devops lock → apply →
   two-pass idempotency → smoke test → **opened PR**. No further prompts unless
   a STOP condition fires.
4. **Stop at the opened PR.** The dispatcher never merges. Merge is the operator's
   call via the normal `dev` PR flow.

### STOP conditions that override autonomy (surface, don't paper over)

- Slug not in catalog on a verb that requires it (per matrix above).
- `update`: no newer version → report "already current at `<tag>`", touch nothing.
- `update`: changelog flags a breaking/major change and `--allow-major` absent →
  STOP after presenting impact; require explicit operator decision.
- Any apply: pass 2 reports `changed=[1-9]` → STOP, do not claim success.
- Smoke test returns 404/502/unexpected status → STOP, deploy FAILED; roll back
  the pin (docker) or restore the snapshot (LXC/VM); report BROKEN, never
  "deployed with a blocker."

### `--check-only` (update)

Reports the version delta + changelog summary and STOPs before any mutation.
No worktree, no lock, no PR. The safe default for "is there an update for X?".
