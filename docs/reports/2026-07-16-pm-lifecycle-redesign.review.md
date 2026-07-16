# Project-Manager Lifecycle Redesign

**Author:** Claude (Opus 4.8) · **Date:** 2026-07-16 · **Status:** proposal (react-before-code) · **Rev 4** — machine-enforced scope boundary: a `scope-manifest.md` lets the guard *objectively* reject scope-changing work on the chore lane (2nd adversarial pass rejected the deferred `scope_confirmed`-only approach). Rev 3 added guard chore-validation, atomic BL-id allocation, `what-next` triaged-only. Rev 2 added the plan-review corrections.
**Scope:** the `project-manager` skill bundle + its interplay with `what-next`, `sync-status`, `github`, and the reconciliation skills — **all changes land in `ai-agent-kit` only**. Behaviour was validated against a live consuming repo for realism, but this proposal touches no consuming repo.

> **Decisions locked in from the scoping round:** dedicated `docs/backlog.md` as the canonical intake (my recommendation), a **hybrid chore track** where `/capture` triages each item into either the feature lane (spec+plan) or a lighter chore lane (backlog→task), and this rendered proposal *before* any skill edits.

---

## 1. Current lifecycle and where it breaks

### 1.1 The pipeline as designed

```
INITIAL_PROMPT ─▶ features/ ─▶ plans/ ─▶ tasks/active/ ─▶ agent ─▶ verify gate ─▶ tasks/archive/
   (intent)       (scope)     (breakdown)  (work order)   (typed)   (review/test)   (history)
                     │            │             │                                       │
                     └────────────┴─────────────┴──────────────▶ STATUS.md (§2/§3 view) ◀┘
```

Strictly one-directional, enforced in four layers: `AGENTS.md`/`CLAUDE.md` guidance → `guard-pm-flow.ps1` pre-commit hook → Claude Code `PreToolUse` hook → PR template. **Refine → Plan → Execute → Verify → Close → Report is genuinely strong.**

### 1.2 Artifact ownership (who creates / modifies / reads)

| Artifact | Created by | Modified by | Read by |
|---|---|---|---|
| `INITIAL_PROMPT.md` | `/init-project` / user | **user only** | `init-features`, `continue-tasks` |
| `features/*.md` | `/init-features`, `/add-feature` | user, or agent **with confirmation** | `continue-tasks`, `sync-status`, `review-tasks`, `what-next` |
| `plans/*.md` | `/continue-tasks` | `continue-tasks`/`update-tasks` (status), `reinit` | orchestrator, `sync-status`, `review-tasks`, `what-next` |
| `tasks/active/*.md` | **`/continue-tasks`, `/iterate-tasks` only** | worker agent (appends `## Completion`) | orchestrator, guard hook |
| `tasks/archive/*.md` | `update-tasks`/`continue-tasks` (move) | — | `continue-tasks` (context) |
| `STATUS.md` §2/§3 | `/init-project` skeleton | **`sync-status`** (generated) | everyone |
| `STATUS.md` §1/§4 | `/init-project` skeleton | **hand-curated** | everyone, `continue-new-session` |
| `workflow/FOCUS.md` | `/init-project` stub | — | `continue-new-session` (fallback) | *retired → STATUS §1* |
| `issues/*.md` | agents/humans, error-recovery | — | `sync-status` (§3) | *de-facto bug/review tracker* |
| `what-next.md` / `backlog.md` | `what-next` | `what-next` | `what-next` | **only in NON-PM repos** |

**The single door:** nothing except `/continue-tasks` (and its wrapper `/iterate-tasks`) ever writes a task file.

### 1.3 Gaps vs. standard PM functions

| Function | State | Detail |
|---|---|---|
| **Capture / intake** | ❌ Missing | No command writes a new backlog item. Ideas/bugs/chores land ad-hoc in STATUS §4 (hand-edited) or `issues/` (no convention). |
| **Triage / grooming** | ❌ Missing | Nothing promotes a §4 item or an issue into the pipeline. §4 *says* "when one graduates, delete it here" — but no actor performs the graduation. |
| **Prioritize** | ⚠️ Partial | `priority` + `what-next` weights rank plan tasks only, never backlog. |
| Refine / Plan / Execute / Verify / Close / Report | ✅ Strong | — |
| **Assign** | ⚠️ Partial | role→agent map + lease; no human/worktree assignee, no PR↔task link. |
| **Retro / learning** | ⚠️ Partial | `continue-tasks` already appends ad-hoc durable notes to `workflow/INDEX.md` (`sub-skills/continue-tasks/SKILL.md:189–190, 222`) — but there is no *systematic, deduped* close-out harvest, so the ledger is incidental rather than intentional. |

### 1.4 The two named pain points, precisely located

1. **"Where do ad-hoc backlog tasks reside?"** — Today: STATUS §4 (PM repos) *or* `backlog.md` (non-PM repos). Two mechanisms, no bridge, and §4 is manually edited. There is a *holding pen* but **no front door and no exit door** into the pipeline.

2. **"docs/tasks isn't honored; how do tasks materialize in consuming repos?"** — Task files materialize **only** inside the orchestration loop. Any direct edit, `/ship`, or one-off fix **never creates a task file**, so the guard's only recourse is a logged bypass and STATUS goes blind. The root cause: **everything must be a "feature."** There is no lightweight lane for a bug or chore, so people bypass — and the bypass *is* the real ad-hoc workflow.

---

## 2. Proposed design

Add the three missing stages (**capture → triage → promote**) as first-class, minimal commands, and introduce a **chore lane** so not everything must be a feature. Both lanes converge on the *same* task-file format, guard, verification gate, archive, and STATUS view.

### 2.1 Two lanes, one execution engine

```
                          ┌─ scope change? YES ─▶ FEATURE lane
   idea / bug / chore ─▶ /capture ─(triage)       features/ ─▶ plans/ ─┐
                          │                                            ├─▶ tasks/active/ ─▶ agent ─▶ verify ─▶ archive
                          └─ scope change? NO ──▶ CHORE lane          │        (identical work-order machinery)
                                                  backlog.md ─▶ /groom ┘
```

- **FEATURE lane** (unchanged): `spec → plan → task`. For anything that changes product scope or behavior.
- **CHORE lane** (new): `backlog-item → task`, skipping spec and plan. For bugs, chores, tech-debt, mechanical changes. Reuses the task template, guard, gate, archive, and STATUS.

### 2.2 New canonical store: `docs/backlog.md`

Flat, ID'd, short. Completed items move to `docs/backlog-archive.md` (mirrors `what-next`'s archive rule) so the live file stays scannable.

```markdown
---
kind: backlog
purpose: Intake for not-yet-scheduled work. The single front door for bugs, chores, debt, and ideas.
last_updated: 2026-07-16
---
# Backlog

| ID | Type | Area | Pri | Status | Item | Link |
|----|------|------|-----|--------|------|------|
| BL-007 | bug | discovery | p1 | open | Avatar 404s on poll refresh | |
| BL-008 | chore | infra | p2 | triaged | Bump yt-dlp, re-pin lockfile | |
| BL-009 | debt | ui | p3 | promoted | Re-skin PCB ornament tokens | → discovery-ui-plan P8 |
```

- `type ∈ {bug, chore, debt, idea}` · `status ∈ {open, triaged, promoted, done, wontfix}`
- IDs monotonic, **never reused**. To hold that invariant, `/capture` computes the next id from `max(BL-*)` across **both** `backlog.md` *and* `backlog-archive.md` — scanning only the live file would recycle archived ids.
- **Allocation is atomic (race-safe).** `/capture` acquires an advisory lock (`docs/backlog.lock`, reusing the existing `docs/tasks/locks/` lease pattern) for the read-max → append cycle, so two concurrent captures cannot mint the same id. As a fail-closed backstop independent of the lock, `sync-status`/`validate.ps1` reject the file when any `BL-*` id appears more than once across live + archive. Sequential monotonic ids are kept deliberately — human legibility is a design goal — so the race is solved with a lock + uniqueness check rather than by switching to opaque random ids.
- `promoted` rows carry a `Link` to their feature-plan phase or chore task id.

### 2.3 STATUS §4 flips curated → generated

`sync-status` gains a fourth generated block, `pm:generated:backlog`, that rolls up **open backlog rows + "homeless" open issues**. This is the same generated/curated mechanism already used for §2/§3, extended one section down.

> **Definition — a "homeless" issue** is an `open` file in `docs/issues/` that is **not** referenced by any plan task row and carries **no** `promoted_to:` / backlog `Link` back-reference. An issue that a plan already owns (or that has been groomed into a backlog row) is *not* homeless and is not restated in §4 — this keeps every item in exactly one place. `/groom` is what clears homelessness, by promoting the issue into a plan task or a `BL` row.

- **Kills the two-source-of-truth problem** the `two-surface-observability-reconciliation` skill exists to referee. §4 becomes derived, not a parallel hand-maintained truth.
- One small curated escape hatch (`pm:curated:notes`) can remain for genuinely free-form operator notes — optional; default is fully generated.

### 2.4 New / changed commands

| Command | Kind | Behavior |
|---|---|---|
| **`/capture "<text>"`** | new sub-skill | Front door. If text absent, elicit via `AskUserQuestion`. **Every item lands as a `BL-NNN` row in `backlog.md`** with an inferred `type` (bug/chore/debt/idea) — this is the single intake, so even genuinely new capability *ideas* are captured as `type: idea` rows rather than jumping straight to a spec. Triage of *which lane* happens at grooming, not capture. Append-only, never commits. |
| **`/groom [BL-NNN \| issue]`** | new sub-skill | Triage/promotion — the moment the feature-vs-chore lane is decided. Asks *"does this change product scope/behavior?"* and offers per-item: **promote-to-feature** (seed `/add-feature` from the row — the path an `idea` row takes; mark row `promoted`, record `promoted_to`), **materialize-as-chore-task** (write one `tasks/active/chore-<area>-BL-NNN.md`, mark `promoted`), **merge-into-plan** (append a task row to a feature phase), or **close** (`done`/`wontfix`). |
| **`/task "<desc>"`** | new sub-skill | Express path = `/capture` + `/groom` (materialize-as-chore-task) in one shot, for the "I just need to fix this now" case. **This is the construct that makes `docs/tasks` get honored** — it turns the pre-commit guard from a thing to bypass into a thing with a one-command legitimate answer. Chore lane only; anything scope-changing is redirected to `/capture` + `/groom → feature`. **Spec-authority guard:** because the feature-vs-chore call is a human judgement, both `/task` and `/groom`'s materialize path must re-assert the spec-authority rule — if the chore turns out to touch product behaviour, surface it and stop rather than let a mis-triaged chore silently bypass spec review. |
| `/sync-status` | changed | Generate §4 from `backlog.md` + homeless open issues. |
| `/update-tasks` | changed | On a chore task's completion, also flip its `BL-NNN` row to `done` and move it to `backlog-archive.md`. |
| `/init-project` | changed | Scaffold `backlog.md`, `backlog-archive.md`, a `backlog` template row, and seed STATUS §4 as a generated fence. |
| `what-next` | changed | In PM repos, read `backlog.md` so `backlog.md` becomes THE backlog in both worlds (removing the "two backlogs" divergence). **But rank only *executable* work as next tasks** — plan `todo`s, materialized chore tasks, and already-`promoted` rows. Untriaged `open`/`triaged`/`idea` rows are surfaced in a **separate "needs grooming → `/groom`"** bucket, never mixed into the top-3 executable ranking. This preserves the invariant that the feature-vs-chore lane is decided at `/groom`, not smuggled in through a recommendation. |

### 2.5 Chore task-file variant + machine-enforced scope boundary

Reuses `task-file-template.md` with three differences: `feature: chore-<area>`, a **Backlog item** excerpt block in place of the spec/plan excerpt, and a `backlog_ref: BL-NNN` frontmatter field linking the task to its backlog row. Same `## Completion` sentinel, same **verification gate** (a bugfix still needs a test), same archive path.

**The chore lane is enforced by `guard-pm-flow.ps1`, not by convention or operator honesty.** (Adversarial-review Findings 1, iterated across two passes.) An earlier draft made `covers: [CHORE-<area>]` a pseudo-CAP that passed on mere presence — a rubber stamp — and a later draft still let a human `scope_confirmed: true` wave through scope-changing work. Both are rejected. For any staged commit whose active task has `feature: chore-*`, the guard **fails closed unless all** hold:

1. **Backlog link.** `backlog_ref: BL-NNN` is present **and** that row exists in `backlog.md`/`backlog-archive.md`.
2. **Chore-class row.** The referenced row's `type` is `bug`/`chore`/`debt` and `status` is `triaged`/`promoted` — an `idea` row (feature-lane) can never back a chore task.
3. **Scope boundary — machine-checked against a manifest.** A new `docs/workflow/scope-manifest.md` declares two glob lists: `product_scope` (behaviour-bearing code) and `chore_safe` (docs, scripts, CI, config). The guard classifies every staged file:
   - matches `product_scope` → **hard FAIL** — scope-changing work cannot ride the chore lane; route it through `/groom → feature` (spec + plan). `scope_confirmed` **cannot** override this.
   - matches `chore_safe` → allowed.
   - matches neither (unclassified) → allowed **only** if `scope_confirmed: true` — an explicit, logged operator acknowledgment for the gray zone.

   The manifest is a **hard prerequisite**: if `scope-manifest.md` is absent, the guard fails closed for every chore task (the express lane is inert until a manifest exists).

This puts the spec-authority invariant under machine enforcement on the exact path most likely to be used under pressure (`/task`) — the review's central objection. `init-project` scaffolds a conservative default manifest (source/API/UI dirs → `product_scope`; `docs/**`, `scripts/**`, `.github/**` → `chore_safe`); `reinit` ensures it exists. The `CHORE-<area>` marker and this whole contract are documented in the guard header + `tasks/README.md` — as an *enforced* contract, not an honor-system one.

```markdown
# docs/workflow/scope-manifest.md
product_scope: [ "src/**", "api/**", "components/**", "app/**", "packages/*/src/**" ]
chore_safe:    [ "docs/**", "scripts/**", ".github/**", "*.md", "*.config.*" ]
# guard: chore task touching product_scope (and not chore_safe) → FAIL → route to feature lane
```

### 2.6 Assignment (in scope this round)

Add optional `assignee:` (human or agent handle) to task frontmatter, alongside the existing lease fields. On the execution side, link PRs back to task ids via the existing `github:worktree-task-lifecycle` skill — the task id goes in the PR body and the `## Next-session` block, so `/update-tasks` can reconcile a merged PR to its task and `sync-status` can show *who* owns in-flight work. Closes the partial **Assign** gap without inventing a new store: `assignee` is just another task-frontmatter field, and the PR↔task link reuses machinery `github` already has.

### 2.7 `/retro` — systematize the learning loop (in scope this round)

**Correction (from the review pass):** `workflow/INDEX.md` is *not* unwritten. `continue-tasks` already appends durable discoveries and cross-feature decisions to it inline (`sub-skills/continue-tasks/SKILL.md:189–190, 222`). So `/retro` is **not** "the first writer" — it is a *systematic supplement* to those incidental appends. At feature/plan close-out it harvests the `Notes`/`Handoff` fields from that feature's archived task files plus any resolved issues and appends a dated digest.

Because a second writer now exists, `/retro` needs a **dedup contract**: each entry gets a stable key (`{date} + {task-id}` or issue id), and `/retro` is idempotent against rows `continue-tasks` already wrote — no double-logging. Read-mostly otherwise: it never touches specs/plans/tasks, only the learning ledger. This upgrades **Retro** from incidental to intentional.

---

## 3. New & changed artifacts at a glance

**New:** `docs/backlog.md` + `docs/backlog-archive.md` (+ templates), `docs/workflow/scope-manifest.md` (+ template), chore task-file variant, sub-skills `capture` + `groom` + `task` + `retro`, companion commands for each.

**Changed:** `sync-status/SKILL.md` (§4 generated from backlog + homeless issues; +`assignee` in §2/§3; **+`BL-*` uniqueness check across live+archive**), `project-manager/SKILL.md` (pipeline diagram + chore lane + directory conventions + command table), `init-project/SKILL.md` + templates (scaffold backlog files + `scope-manifest.md` default + §4 generated fence), **`guard-pm-flow.ps1.template` (new chore-task validation path: `backlog_ref` resolves + row is chore-class + scope-manifest intersection check — `product_scope` hit fails closed, unclassified needs `scope_confirmed`; missing manifest fails closed)**, `reinit/SKILL.md` (lift a curated §4 into backlog rows on adoption), `update-tasks/SKILL.md` (flip `BL` row to `done`; reconcile merged PR↔task), `tasks/README.md` template (document *where ad-hoc work goes* + the enforced pseudo-CAP contract), `task-file-template.md` (+`assignee`, +`backlog_ref`, +`scope_confirmed`), `what-next/SKILL.md` (read backlog.md, **rank only triaged/executable work; untriaged rows route to `/groom`**), `validate.ps1` (BL-id uniqueness gate).

**Trimmed:** `two-surface-observability-reconciliation` drops its "framework vs. backlog" half (obsoleted by generated §4) and keeps only its genuine split-observability/metrics use case. `REMAINING_WORK.md`/`FOCUS.md` are already retired stubs — no change.

**Cross-runtime parity (added after review):** `codex/skills/project-manager/SKILL.md` and `gemini/skills/project-manager/SKILL.md` are **monolithic** mirrors of the whole lifecycle — they must be updated to describe the chore lane + intake, or `/audit-skills` will flag the parity drift. These do not carry the sub-skill/command tree, so the update is a single-file lifecycle-description edit each, not a full port.

**Reorg governance (added after review):** the four new commands (`/capture`, `/groom`, `/task`, `/retro`) must be registered in `docs/reorg/command-namespace-registry.md`, the change must conform to `docs/reorg/charter.md`, and the trim + additions must be logged in `docs/reorg/disposition-ledger.md` — CLAUDE.md makes this mandatory for every skill PR while the master-skills reorg is in progress. **Open naming question:** `/task`, `/capture`, `/groom` are generic enough to collide in the shared namespace — decide at registration time whether to keep them or namespace them (e.g. `/pm-task`).

**Propagation:** all edits land in the `ai-agent-kit` archive; consuming repos pick them up via `/update-skill` (or `/push-skill` to the global profile) on their own schedule. No consuming repo is touched by this work.

---

## 4. Adoption in a consuming repo (repo-agnostic, run by the skill)

Adoption is performed **by the skill itself** — `/init-project` on greenfield, or a `/reinit` pass on a repo that already has a hand-curated STATUS §4 — never by hand-editing a specific repo. The steps are the same everywhere:

1. **Scaffold** `docs/backlog.md` + `docs/backlog-archive.md` from templates (`/init-project` gains these files; idempotent — skipped if present).
2. **Lift existing §4 items into rows.** For a repo whose STATUS §4 was previously hand-curated, `/reinit` reads the current curated block and emits one `BL-NNN` row per item, inferring `type` (bug/chore/debt/idea) and `area` from the text. Items that clearly change product scope are flagged for the **feature lane** and offered to `/groom → /add-feature` rather than becoming chore rows.
3. **Flip the fence — atomically, rows-before-rename.** This is the single highest-consequence step: `sync-status`'s own contract treats a missing/malformed curated fence as *data loss* and says to STOP rather than guess. So the order is strict — **write and verify every `BL` row in `backlog.md` first, then** rename `pm:curated:backlog` → `pm:generated:backlog`. If the lift cannot fully account for a curated item, abort the flip and leave §4 curated. The old curated text remains in git history regardless; nothing is deleted.
4. **Regenerate.** Run `/sync-status`; §4 now renders from `backlog.md` + homeless open issues.
5. **Triage residue.** Open issues that are really "future work, no plan home" are surfaced by `/groom` for promotion or close.

**Reversibility:** every step is additive or a fence-rename; no source or history is destroyed. A repo can opt out by leaving `backlog.md` absent — `sync-status` falls back to preserving a curated §4 exactly as today, so the change is backward-compatible for repos that never adopt the intake lane.

---

## 5. Resolved decisions

All scoping decisions are locked; this section is the record.

| # | Decision | Resolution |
|---|---|---|
| 1 | Backlog home | **Dedicated `docs/backlog.md`**; STATUS §4 flips curated → generated |
| 2 | Feature vs. chore | **Hybrid** — `/capture` intakes, `/groom` decides the lane per item |
| 3 | Idea-type items | **Capture as `BL idea`**, then `/groom` promotes to a draft spec (one front door) |
| 4 | `/task` express | **Included** — one-command chore-task materialization (the guard-honoring path) |
| 5 | Assignment | **In scope** — `assignee:` field + PR↔task link via `github:worktree-task-lifecycle` |
| 6 | `/retro` | **In scope** — harvest task Notes/Handoff into `workflow/INDEX.md` at close-out |
| 7 | Reconciliation skill | **Trim** the PM-half of `two-surface-observability-reconciliation` now |
| 8 | Rollout | **`ai-agent-kit` only**; consuming repos adopt via `/update-skill` on their own schedule |

### Corrections applied from the plan-review pass

| Finding | Fix folded in |
|---|---|
| `/retro` premise false — INDEX.md already has a writer | §2.7 reframed as a *systematic supplement* + dedup contract; §1.3 gap downgraded to Partial |
| codex/ & gemini/ mirrors would drift | §3 adds a cross-runtime parity edit for both monolithic mirrors |
| Reorg governance unaddressed | §3 adds command-registry + charter + disposition-ledger steps; §6 adds a build step |
| Fence-flip data-loss risk (R1) | §4 step 3 made atomic: rows-before-rename, abort-on-shortfall |
| BL-id reuse risk (R3) | §2.2 scans `backlog.md` + `backlog-archive.md` for max id |
| "Homeless issue" undefined | §2.3 adds a precise definition |
| Mis-triaged chore bypasses spec authority (R4) | §2.4 adds a spec-authority re-assert to `/task` and `/groom` |
| Pseudo-CAP is an invisible contract (R6) | §2.5 requires documenting it in the guard header + `tasks/README` |

### Corrections applied from the Codex adversarial review

| Finding | Severity | Disposition |
|---|---|---|
| Pseudo-CAP chore tasks are a documented spec bypass | high | **Incorporated (Rev 3)** — guard enforces `backlog_ref` + chore-class row + `scope_confirmed`, fail-closed (§2.5). |
| Chore guard still permits scope-changing work (2nd pass — rejected the deferral) | high | **Incorporated (Rev 4)** — added `docs/workflow/scope-manifest.md`; guard hard-fails a chore task whose staged files hit `product_scope`, `scope_confirmed` cannot override, missing manifest fails closed (§2.5). The scope boundary is now machine-enforced, not deferred. |
| BL-id allocation unsafe under concurrent capture | high | **Incorporated (Rev 3)** — advisory `backlog.lock` around read-max→append + fail-closed duplicate rejection in `sync-status`/`validate.ps1` (§2.2). Kept human-readable ids by design. |
| `what-next` can surface untriaged backlog as executable | medium | **Incorporated (Rev 3)** — `what-next` ranks only executable work; untriaged rows go to a "needs grooming → `/groom`" bucket (§2.4). |

### Residual notes (not blockers)

- `/retro` dedup keys on `{date}+{task-id}`; acceptable because `INDEX.md` is a human-read ledger, not machine-consumed.
- Command-name generality (`/task`, `/capture`, `/groom`) is resolved at namespace-registry time, not in code.
- The `scope-manifest.md` glob lists are themselves editable by an operator — the residual trust is now "who may edit the manifest," a far smaller and more auditable surface than "who may set `scope_confirmed`." Manifest edits are ordinary tracked diffs, reviewable in the PR.

---

## 6. Suggested build order (once approved)

Small, independently-shippable PRs into `dev`, each under the repo's size limit:

1. **Store + templates** — `backlog.md`/`backlog-archive.md` templates, chore task variant, `+assignee` on task template. (No behavior yet; pure scaffolding.)
2. **`sync-status` §4 generation** — the backward-compatible fence flip (falls back to curated when no `backlog.md`), plus the `BL-*` uniqueness gate in `sync-status`/`validate.ps1`.
3. **`capture` + `groom` sub-skills + commands** — the intake + triage constructs, with the atomic `backlog.lock` allocation. **Register `/capture` + `/groom` in `docs/reorg/command-namespace-registry.md` and conform to the charter in the same PR** (resolve the generic-name question here).
4. **`task` express + guard enforcement + `update-tasks` reconciliation** — the guard-honoring fast path and `BL`-row closeout. **Land `docs/workflow/scope-manifest.md` (+ template) and the full `guard-pm-flow.ps1` chore-validation path — `backlog_ref` + chore-class row + scope-manifest intersection — *in this PR, before or with `/task`*,** so the scope boundary is machine-enforced the moment the express lane exists (never shipped ahead of its guard). Register `/task`; write `scope_confirmed` only after the spec-authority re-assert, and only for unclassified files.
5. **`init-project` / `reinit` scaffolding + adoption lift** — §4 of this doc, including the atomic rows-before-rename fence flip.
6. **`retro` + `what-next` backlog-awareness + reconciliation-skill trim** — the loop-closers. Register `/retro`; log the trim in `docs/reorg/disposition-ledger.md`.
7. **Parity + docs last** — `project-manager/SKILL.md`, `tasks/README.md` (incl. the pseudo-CAP note), **`codex/` + `gemini/` project-manager mirror updates**, and CATALOG/README parity — so every surface describes shipped reality.

Each step passes `pwsh ./scripts/validate.ps1` before its PR (the local gate in `CLAUDE.md`). Steps that add a command or trim a skill must also pass a `/audit-skills` check for README/CATALOG/Codex/Gemini parity before merge.
