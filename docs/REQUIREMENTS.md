# AI Agent Kit — Product Requirements

> **Source of truth for product intent (the PRD).** User-owned — agents never modify this file.
> `/init-features` reads it to seed feature specs. If product direction changes, deprecate features
> (`status: deprecated`) and add new ones rather than rewriting history here.

---

## Governance & precedence

This PRD **reconciles with, and does not supersede,** the binding reorganization governance:
`docs/reorg/charter.md` (`status: binding`) and `docs/reorg/disposition-ledger.md`. Where this PRD
and the charter disagree, **the charter wins**, and where erik's 2026-07-10 human resolutions
(charter §8) and anything else disagree, the resolutions win. Requirements below are written to be
**binary and gate-checkable**: each is either enforced by a named gate (`scripts/validate.ps1`,
`scripts/audit.ps1`, branch protection) or explicitly marked as reported-only.

## Overview

AI Agent Kit is the canonical archive for terminal AI-coding-agent extensions — skills, agent
instructions, and slash commands — used across many projects by a power user of Claude Code, Codex
CLI, and Gemini CLI. Extensions had been scattered across per-project and per-profile locations with
silent drift. The kit consolidates them into one authoritative, versioned store and adds the
lifecycle tooling to sync from source locations, install into projects, update installed copies,
import project changes back, push to the global profile, and audit the whole set for health.

## Why now

Without a single authority there was no parity guarantee, no automated health check, and
inventory/counts drifted silently between sessions. Consolidating into one archive with a **derived,
byte-checked inventory** (`CATALOG.md`) and lifecycle commands makes the extensions maintainable and
safe to redistribute.

## Goals

- One authoritative archive for all skills, agent instructions, and slash commands, with **disk +
  frontmatter + `manifest.json`** as the authority.
- Lifecycle tooling covering discover / sync / install / update / import / push / search, each with
  a defined contract (inputs, outputs, idempotency, conflict behavior, dry-run, failure modes).
- Cross-CLI coverage governed by charter §5 (Codex on-demand, Gemini frozen), with staleness flagged.
- A generated `CATALOG.md` kept byte-fresh by the gate, plus **blocking** README/CATALOG parity.
- Feature-branch → PR → `dev` → `main` git flow, enforced by branch protection + a validation gate.

## Non-goals

- **Not a runtime or agent host.** The kit ships knowledge modules; it does not execute agents or
  provide an LLM runtime of its own.
- **No per-project skill forks.** Installed copies track the archive (via `installed-from`
  frontmatter); divergence flows back through `/import-skill`, not maintained separately.
- **No cross-CLI transpiler and no blanket tri-runtime parity mandate.** Per charter §5 the
  transpiler is cut; Codex/Gemini coverage is deliberately partial (see Cross-CLI mirror policy).
- **No permanent in-tree deprecated-skill tombstones.** Superseded skills are deleted — git history
  is the archive of record (charter §2.3). The durable record is `docs/deprecation-ledger.md`, a
  running list, not in-tree stub skills.

## Functional requirements

### Skill lifecycle tooling
Commands: `/find-skills`, `/sync-skill`, `/install-skill`, `/update-skill`, `/import-skill`,
`/push-skill`, `/search-skill`.

**Contract requirement (applies to every lifecycle command; each command's feature spec MUST
define these, and acceptance tests assert them):**
- **Inputs & target root** — required/optional args and the exact root it reads or writes
  (archive `claude/skills/`, a project's `.claude/skills/<name>/`, or the global profile
  `~/.claude/skills/<name>/`).
- **Outputs** — files created/modified and the human-readable summary emitted.
- **Idempotency** — re-running with the same inputs makes no further change.
- **Conflict / overwrite behavior** — never overwrite silently; diff-and-confirm, or write
  `<file>.new` for manual merge.
- **Dry-run** — a `-WhatIf`/preview mode that reports the plan without mutating state.
- **Diff format** — how differences are presented before a mutating action.
- **Failure modes & exit codes** — validation failure vs execution failure, distinctly.
- **`installed-from` stamping** — installed copies carry `installed-from: ai-agent-kit` and are
  skipped by all scans.

### Cross-CLI mirror policy (per charter §5 — binding)
- **The cross-CLI transpiler is cut.** No requirement that a skill exist for all three runtimes.
- **Codex mirrors are created on demand** — only when a skill is actually used from Codex.
- **Gemini is frozen at 5 skills.**
- `/audit-skills` reports the Claude↔Codex gap **informationally — never as a failure** (`[info]`).
- Every mirror carries a **source-version stamp**; `skill-parity-guard` flags a mirror as stale when
  its stamp lags the Claude source. Staleness is surfaced, and fix mode **proposes but never
  executes** deletions (charter §6).

### Catalog & health integrity
- **Authority is disk + frontmatter + `manifest.json`**, not `CATALOG.md`. `CATALOG.md` is a
  **generated, derived artifact**. Agents never resolve drift by editing `CATALOG.md` by hand.
- **CATALOG freshness is a blocking gate.** `validate.ps1` regenerates `CATALOG.md` from the
  manifest and byte-compares; any difference is an `[error]` (`catalog-staleness`) that fails the
  gate. Counts are never hand-restated anywhere (rule G5).
- **README parity is blocking** (`[error]`): every archived skill has a README row, and every row
  points to a real file.
- **Diagram coverage is a blocking gate (new scope).** Every skill bundle must have a `diagram.html`.
  This requires promoting `audit.ps1`'s missing-diagram finding from `[info]` to `[error]`, preceded
  by a one-time `/backfill-diagrams` sweep to 100% so the promotion does not retroactively fail
  existing PRs. Until that promotion ships, diagram gaps remain reported-only; the promotion is a
  tracked requirement, not the current state.
- **Frontmatter validity + name/dir match** are blocking (`[error]`).
- **Profile-shadowing** (a loose `~/.claude/skills/<name>` shadowing a bundle sub-skill) is
  reported as `[warn]`, never `[error]` — it is a local-profile condition (import before delete).
- **Deprecation ledger** — `docs/deprecation-ledger.md`, owned by `skills-manager`. Schema, one row
  per removed skill: **name | 1–2 sentence description | reason for deprecation | date | PR**.
  **Validation rule:** every PR that deletes or renames a skill appends its row in the same PR
  (folds into charter §6 parity follow-through). Distinct from `docs/reorg/disposition-ledger.md`
  (reorg *planning*: one row per directory, planned disposition) — a deletion executed under the
  reorg flips the disposition-ledger row to `done` **and** appends a deprecation-ledger row.

### Git & release automation
Commands: `/ship`, `/release`, `/release-init`, `/merge`, `/prune`.
- Ship working changes through a feature-branch PR into `dev` (`/ship`); **preflight**: `/ship` runs
  `scripts/validate.ps1` first and aborts on non-zero exit.
- Cut versioned `dev`→`main` releases with changelog + tag (`/release`, `/release-init`).
- Merge PRs/branches/worktrees into `dev` (`/merge`); prune stale branches/worktrees (`/prune`).
- **Enforcement (in scope — a local gate alone is bypassable):**
  - **Branch protection on `dev` and `main`** is the authoritative control — require a PR, forbid
    direct pushes and direct merges, require the merge to originate from a PR. Provisioned via the
    Repo-Configuration Standard (`/init-repo`).
  - **Pre-push hook** (`scripts/install-hooks.ps1`, opt-in) runs the gate before push locally.
  - **Command preflight** — `/ship` and `/release` refuse to proceed when the gate fails.

## Non-negotiable constraints

- Authority is disk + frontmatter + `manifest.json`; `CATALOG.md` is derived and kept byte-fresh by
  the gate (never hand-edited to resolve drift).
- Counts are never restated by hand anywhere (rule G5).
- Installed copies carry `installed-from` frontmatter and are skipped during scans.
- Every archived skill has a README row, and every row points to a real file (blocking).
- All changes flow source → archive through a feature branch → PR → `dev` (never direct to
  `dev`/`main`), enforced by branch protection; `/import-skill` is the only reverse direction.
- `scripts/validate.ps1` must pass before any PR is opened.
- Deleted/superseded skills are removed from the tree; `docs/deprecation-ledger.md` is the durable
  record and gains a row in the same deletion PR.
- The charter (`docs/reorg/charter.md`) and erik's §8 resolutions are binding and override this PRD
  on conflict.

## Success metrics

- **CATALOG staleness = 0** — `validate.ps1` catalog byte-check passes on every PR into `dev`.
- **README + CATALOG parity: 100%, gate-blocking** — zero `[error]` parity findings in `audit.ps1`.
- **Diagram coverage: 100%, and gate-blocking after the promotion** — no bundle without a
  `diagram.html`; missing-diagram is an `[error]` once promoted.
- **Zero direct commits to `dev`/`main`** — branch protection rejects non-PR pushes/merges.
- **Deprecation ledger completeness** — every skill removal in the git history since adoption has a
  matching `docs/deprecation-ledger.md` row.

---

_Written: 2026-07-27_
