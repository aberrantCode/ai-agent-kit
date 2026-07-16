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

---

## Build-order steps

| # | Step | Status | PR | Notes |
|---|------|--------|-----|-------|
| 1 | **Store + templates** — `backlog.md`/`backlog-archive.md` templates, chore task variant, `+assignee` on task template (pure scaffolding) | done | #77 | 4 files: 2 backlog templates + chore task variant + `+assignee`. Chore `## Completion` verified byte-identical to base. No command/skill added → no registry/ledger change due. |
| 2 | **`sync-status` §4 generation** — backward-compatible fence flip (falls back to curated when no `backlog.md`) + `BL-*` uniqueness gate in `sync-status`/`validate.ps1` | todo | — | — |
| 3 | **`capture` + `groom` sub-skills + commands** — intake + triage, atomic `backlog.lock` allocation. Register `/pm-capture` + `/pm-groom`, conform to charter | todo | — | — |
| 4 | **`task` express + guard enforcement + `update-tasks` reconciliation** — `scope-manifest.md` (+template) + full `guard-pm-flow.ps1` chore-validation (backlog_ref + chore-class + scope-manifest intersection + frozen `authz_snapshot`/`manifest_sha` + same-commit self-authorization block). Register `/pm-task` | todo | — | — |
| 5 | **`init-project` / `reinit` scaffolding + adoption lift** — atomic rows-before-rename fence flip | todo | — | — |
| 6 | **`retro` + `what-next` backlog-awareness + reconciliation-skill trim** — loop-closers. Register `/pm-retro`, log trim in disposition-ledger | todo | — | — |
| 7 | **Parity + docs last** — `project-manager/SKILL.md`, `tasks/README.md`, `codex/` + `gemini/` mirror updates, CATALOG/README parity | todo | — | — |

Status legend: `todo` · `in-progress` · `done`

---

## Iteration log

- **Iter 1 (2026-07-16):** Created tracker. Recorded decisions D1–D4. Shipped Step 1 (PR #77): backlog store + archive templates, chore task variant, `+assignee`. validate.ps1 green. Governance: no command/skill added, so no namespace-registry or disposition-ledger entry due (first such entries land at Step 3 per §6).
