# docs/tasks/

This directory holds work orders — task files that drive implementation.

**Structure:**
- `active/` — In-flight tasks (one per work stream)
- `archive/` — Completed tasks
- `locks/` — Claim/lease records (advisory coordination)
- `logs/` — Append-only task timeline and handoff notes

---

## Where Ad-Hoc Work Goes

Bugs, chores, and tech-debt do NOT need a feature spec. Capture them with `/pm-capture` (or the
express `/pm-task` shortcut) and they materialize as chore task files in `active/`.

**Example workflows:**

1. **Quick chore** — `/pm-task "fix: flaky test in auth_test.py"` → backlog item → triaged → task file
2. **Bug from GitHub** — `/pm-groom issue/123` → decide chore vs. feature → materialize if chore
3. **Tech-debt** — `/pm-capture "refactor: consolidate duplicate error handlers"` → backlog → promote as chore

Anything that changes **product scope or behavior** must go through the feature lane:
`/pm-groom` (as feature) → `/add-feature` (acquire a spec) → `/continue-tasks` (plan + implement).

---

## The Enforced Chore-Lane Contract

Chore tasks (`feature: chore-*`) are **NOT honor-system**. `scripts/guard-pm-flow.ps1` enforces the
contract at commit time:

**Requirements for a chore commit to pass the guard:**

1. **Backlog reference exists** — the task's `backlog_ref` row must exist in `docs/backlog.md`
2. **Frozen authorization snapshot** — the task must have `authz_snapshot` with:
   - `bl_type` ∈ {`bug`, `chore`, `debt`}
   - `bl_status` ∈ {`triaged`, `promoted`}
3. **Scope-manifest SHA match** — the live `docs/workflow/scope-manifest.md` SHA256 must match the
   frozen `manifest_sha` in the task (manifest changes require re-authorization)
4. **File boundary enforcement** — every staged file must be:
   - Inside `files_allowed` (the task's frozen reviewed scope) — and `files_allowed` must not intersect `product_scope`
   - Marked `chore_safe` in the manifest OR unclassified
   - NOT hitting `product_scope` (hard fail if it does; re-route to `/pm-groom → /add-feature`)
5. **Self-edit block** — the commit may NOT edit:
   - Its own `scope-manifest.md`
   - Its own backlog row's `type` or `status` (prevents same-commit self-authorization)

**If a chore commit fails the guard:**
- **Scope hit** — You touched a `product_scope` file. Route this work through `/pm-groom → /add-feature`.
- **Stale manifest** — Someone updated `scope-manifest.md`. Re-run `/pm-groom` on the task to re-snapshot.
- **Missing backlog** — The backlog row was deleted or the reference is wrong. Verify `docs/backlog.md`.

**Hard prerequisite:** `docs/workflow/scope-manifest.md` must exist. If it is missing, the chore lane is
inert and all commits will fail. Run `/init-project` or `/reinit` to scaffold it.
