# PM Lifecycle Redesign — Implementation Progress

**Source of truth:** [`2026-07-16-pm-lifecycle-redesign.review.md`](2026-07-16-pm-lifecycle-redesign.review.md) §6 build order.
**Driver:** autonomous `/loop` orchestrator — one build-order step per iteration.
**Rule:** each step is its own feature branch → PR → merge (merge commit) into `dev`. `validate.ps1` must exit 0 before every PR.

Read this file FIRST each iteration to find the next `todo` step (resumable).

---

## Locked decisions (apply across all steps)

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **Command names are `pm-`-prefixed:** `/pm-capture`, `/pm-groom`, `/pm-task`, `/pm-retro` | The bare forms (`/capture`, `/groom`, `/retro` = bare verbs; `/task` = bare noun) violate the charter's **Generic-Verb Rule** (`docs/reorg/command-namespace-registry.md`). Spec §3 flags this open question; spec §2.4 already uses `/pm-task` as the example. Loop brief instructs `pm-` prefix on collision. |
| D2 | **Base `task-file-template.md` gains only `+assignee` in Step 1.** Chore-only frozen-authz fields (`backlog_ref`, `scope_confirmed`, `authz_snapshot`, `manifest_sha`) live on the **chore task variant** and are finalized in Step 4 (guard enforcement). | Keeps Step 1 "pure scaffolding, no behavior" per §6.1; authz fields are meaningless without the guard that reads them. |
| D3 | **New store templates live under `references/init-project/`** (`backlog.md.template`, `backlog-archive.md.template`, later `scope-manifest.md.template`). | `init-project` scaffolds them (Step 5); co-locating with the other init-project templates matches the existing convention. |
| D4 | **Chore task variant is a separate template** `references/chore-task-file-template.md`. | §2.5 / §3 call it a distinct "chore task-file variant"; a separate file keeps the base template clean and lets the guard key on `feature: chore-*`. |
| D5 | **The spec's "`validate.ps1` BL-id gate" is implemented in `references/scripts/pm-validate.ps1`** (the consuming-repo validator), NOT the archive's own `scripts/validate.ps1`. | The archive has no `docs/backlog.md` (only templates); a gate in the archive validator would be inert. `pm-validate.ps1` is the validator scaffolded into consuming repos, where `backlog.md` actually lives. Both `sync-status` (prose STOP) and `pm-validate.ps1` (script, exit 1) enforce the invariant per §2.2. |
| D6 | **BL-id gate matches on numeric-exact string ids, not normalized width** (`BL-05` ≠ `BL-005`). | `/capture` mints ids from `max(BL-*)` so width is consistent by construction; normalizing risks surprising behavior. Recorded as a known residual (surfaced by the adversarial pass), not a defect. |
| D7 | **Step 3 ships `/pm-groom`'s materialize-as-chore-task path, but the frozen `authz_snapshot` + machine guard are deferred to Step 4.** | §2.5: "the express lane is inert until a manifest exists." `scope-manifest.md` + `guard-pm-flow.ps1` chore-validation land in Step 4 per the build order; until then groom writes what authz fields it can and notes the lane is unenforced. Keeps groom spec-faithful without a forward dependency that doesn't yet exist. |
| D8 | **Disposition-ledger additions are batched into Step 6** (alongside the reconciliation-skill trim), not logged per-step. | Spec §3 pairs "the trim + additions" as one ledger entry; `project-manager` is already an `extend-in-place` row covering internal sub-skill additions. The binding command-namespace registry IS updated per-step (the load-bearing artifact for command collisions). |
| D9 | **Created the missing `references/init-project/STATUS.md.template`** with §4 seeded as a `pm:generated:backlog` fence. | `init-project` already referenced this template (its copy step was dangling — the file never existed); §2.4 independently needs STATUS §4 seeded generated. Creating it resolves both at once. Safe: `init-project` never overwrites an existing `STATUS.md`, so no consuming repo is disturbed. |

---

## Build-order steps

| # | Step | Status | PR | Notes |
|---|------|--------|-----|-------|
| 1 | **Store + templates** — `backlog.md`/`backlog-archive.md` templates, chore task variant, `+assignee` on task template (pure scaffolding) | done | #77 | 4 files: 2 backlog templates + chore task variant + `+assignee`. Chore `## Completion` verified byte-identical to base. No command/skill added → no registry/ledger change due. |
| 2 | **`sync-status` §4 generation** — backward-compatible fence flip (falls back to curated when no `backlog.md`) + `BL-*` uniqueness gate in `sync-status`/`validate.ps1` | done | #78 | §4 flips to `pm:generated:backlog` when backlog.md present, else curated fallback. BL-id gate added to **`pm-validate.ps1`** (D5) not archive validate.ps1. Adversarial pass caught an indented-row false-negative → hardened `^\s*\|`. |
| 3 | **`capture` + `groom` sub-skills + commands** — intake + triage, atomic `backlog.lock` allocation. Register `/pm-capture` + `/pm-groom`, conform to charter | done | #79 | 4 files + registry. capture: atomic BL alloc across live+archive under backlog.lock; groom: 4 outcomes + spec-authority re-assert. D7 recorded (authz freeze → step 4). Ledger additions batched to step 6 per spec "trim+additions" pairing. CATALOG parity intact (boolean flags). |
| 4 | **`task` express + guard enforcement + `update-tasks` reconciliation** — `scope-manifest.md` (+template) + full `guard-pm-flow.ps1` chore-validation (backlog_ref + chore-class + scope-manifest intersection + frozen `authz_snapshot`/`manifest_sha` + same-commit self-authorization block). Register `/pm-task` | done | #80 | Guard (355 lines) + scope-manifest template + `/pm-task` + authz fields + update-tasks reconciliation. Adversarial pass: 16 vectors, no bypass; cell-indexing verified correct. Removed a stray `scripts/guard-pm-flow.ps1` test artifact. 613-line PR (guard+task atomic per §6.4). |
| 5 | **`init-project` / `reinit` scaffolding + adoption lift** — atomic rows-before-rename fence flip | done | #81 | init-project scaffolds backlog/archive/scope-manifest + STATUS §4 generated. Created missing `STATUS.md.template` (D9 — resolved a dangling ref). reinit Step 5.5 adoption lift: atomic rows-before-rename, abort-on-shortfall, fail-closed on malformed fence. Fixed `/groom`→`/pm-groom`, "five"→"four ## sections". |
| 6 | **`retro` + `what-next` backlog-awareness + reconciliation-skill trim** — loop-closers. Register `/pm-retro`, log trim in disposition-ledger | todo | — | — |
| 7 | **Parity + docs last** — `project-manager/SKILL.md`, `tasks/README.md`, `codex/` + `gemini/` mirror updates, CATALOG/README parity | todo | — | — |

Status legend: `todo` · `in-progress` · `done`

---

## Iteration log

- **Iter 1 (2026-07-16):** Created tracker. Recorded decisions D1–D4. Shipped Step 1 (PR #77): backlog store + archive templates, chore task variant, `+assignee`. validate.ps1 green. Governance: no command/skill added, so no namespace-registry or disposition-ledger entry due (first such entries land at Step 3 per §6).
- **Iter 2 (2026-07-16):** Shipped Step 2 (PR #78): sync-status §4 generation (generated/curated dual-mode fence, homeless-issue rollup, assignee annotation) + BL-id uniqueness gate in `pm-validate.ps1`. Recorded D5 (gate lives in consuming-repo validator) + D6 (string-exact id match). Adversarial-verify (haiku) found an indented-row false-negative; hardened the regex to `^\s*\|` and regression-tested. validate.ps1 green. No command/skill/trim → no registry/ledger entry due.
- **Iter 3 (2026-07-16):** Shipped Step 3 (PR #79): `capture` + `groom` sub-skills + `/pm-capture` + `/pm-groom` command wrappers. Registered all four PM commands in the namespace registry (D1 rename decisions). Recorded D7 (authz freeze deferred to Step 4) + D8 (ledger additions batched to Step 6). Integrator fixes: capture empty-backlog → BL-001; groom Option C plan-row corrected to real schema. validate.ps1 green (CATALOG parity intact — boolean manifest flags unchanged).
- **Iter 4 (2026-07-16):** Shipped Step 4 (PR #80): the chore express lane + machine guard. Sonnet authored the guard-pm-flow.ps1 chore-validation (frozen authz_snapshot + manifest_sha + scope-manifest intersection + same-commit self-authorization block, segment-wise glob matching) + scope-manifest template; haiku authored `/pm-task`, the chore-template authz fields, and update-tasks reconciliation. Adversarial-verify (haiku, 16 vectors) found no product_scope bypass; I verified the row self-auth cell-indexing (cell[2]=Type, cell[5]=Status) is correct. Caught + removed a stray `scripts/guard-pm-flow.ps1` subagent test artifact (1055→613 lines, under 800). validate.ps1 green.
- **Iter 5 (2026-07-16):** Shipped Step 5 (PR #81): init-project scaffolds backlog.md/backlog-archive.md/scope-manifest.md + a real STATUS.md.template with §4 generated; reinit Step 5.5 adoption lift (atomic rows-before-rename, abort-on-shortfall, fail-closed on malformed fence). Recorded D9 (created the dangling STATUS.md.template). Integrator fixes: `/groom`→`/pm-groom`, "five"→"four ## sections". No new command → registry/CATALOG parity intact. validate.ps1 green.
