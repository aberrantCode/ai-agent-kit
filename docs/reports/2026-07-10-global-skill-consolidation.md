---
title: Global Skill Consolidation — Analysis & Migration Report
date: 2026-07-10
status: ready-for-implementation
sources: 11 Phase A analysis reports (scratchpad/phaseA/01-11)
---

# Global Skill Consolidation Report

## 1. Executive Summary

Rationalization Phase 1 (PR #51) merged `design-taste-frontend` + `frontend-design` →
**frontend-design**, `security-review` + `security` → **security**, and
`create-feature-spec` + `add-feature` → **add-feature**, refactored
`finishing-a-development-branch` to delegate integration to the `github` bundle's `ship`
operation, and deleted the superseded skills from the archive. Separately, the old standalone
git skills (`ship-to-dev`, `release-to-main`, `git-cleanup`, `publish-github`,
`commit-hygiene`) were previously consolidated into the `github` parent skill
(sub-skills/commands: `ship`, `merge`, `release`, `commit`, `prune`, `publish`,
`release-init`).

Policy (final): skills must be **reused identically** across all projects. Canonical bundles
live in the ai-agent-kit archive, get pushed to the global profile
(`~/.claude/skills`, `C:\Users\erik.OPBTA\.claude\skills`), and repo-local installed copies are
**deleted outright** — no repo keeps a private fork of a shared skill.

11 Phase A reports surveyed every installed copy across the global profile and 6 repos
(AC_OPBTA, ac-repo-radar, chrome_toolbar, neurorep_v3, scan_organization, WinAppProfiles).
Finding, repeated in nearly every report: **most repo-local copies (and the global profile's
own `security` copy) are 5+ months stale, and resolve to an equally stale global copy once
deleted.** Deleting a repo-local copy before the global profile is refreshed is a regression,
not a cleanup — the repo silently falls back to the same outdated content instead of gaining
the archive's current version.

**The ordering constraint that emerged from analysis, and the organizing principle of this
report:**

> The global profile MUST be updated (via `/push-skill`) BEFORE any repo-local deletion.
> Deleting first — or deleting and pushing in arbitrary order — leaves a window where repos
> resolve to a stale (or absent) global copy, which is worse than the stale local copy they
> started with.

Concretely: `frontend-design`, `add-feature`, and `finishing-a-development-branch` are
**currently absent from the global profile entirely** — pushing them is not optional
cleanup, it is a prerequisite for every repo's deletion step to be safe. `security` exists
globally but is byte-identical to the stale 577-line copies found in scan_organization,
neurorep_v3, and WinAppProfiles — pushing it is equally required. `github` exists globally
but is 2 days stale (missing the `release-init` operation added 2026-07-10 in the archive).

This report consolidates the 11 Phase A reports into one plan: what to push globally, what to
delete where, what CLAUDE.md/AGENTS.md edits are needed per repo, a full reference-migration
table, deduplicated risks, open decisions for the human, and a numbered implementation order
(global profile first, then one repo per iteration, simplest → most complex).

---

## 2. Global-Profile Push List

Target: `C:\Users\erik.OPBTA\.claude\skills\` (global profile — **not a git repo**; direct
file edits, no PR).

| Skill | Current global state | Archive state | Action |
|---|---|---|---|
| `frontend-design` | **Absent** | Full bundle (SKILL.md + diagram.html), 2026-07-10 | `/push-skill frontend-design` |
| `add-feature` | **Absent** | Full bundle (SKILL.md + diagram.html), 2026-07-10 | `/push-skill add-feature` |
| `finishing-a-development-branch` | **Absent** | SKILL.md + diagram.html, refactored 2026-07-10 to delegate to github `ship` | `/push-skill finishing-a-development-branch` |
| `security` | Present, **stale** (14,089 B / 577 lines, dated 2026-02-04) — byte-identical to the repo-local stale copies | 24,526 B / 983 lines + diagram.html, 2026-07-10 | `/push-skill security` (overwrite) |
| `github` | Present, **stale** (SKILL.md + diagram.html dated 2026-07-08; `commands/` present at top level but no `sub-skills/`) — missing `release-init` operation entirely | SKILL.md + diagram.html + `sub-skills/{commit,merge,prune,publish,release,release-init,ship}/` + `commands/{...,release-init.md}`, dated 2026-07-10 | `/push-skill github` (overwrite; confirmed via diff — global SKILL.md lacks the `release-init` trigger phrases and the `/release-init` row/section present in archive) |

**Global copies to DELETE** (superseded, confirmed stale/legacy):

| Skill | Status | Note |
|---|---|---|
| `design-taste-frontend` | Superseded by `frontend-design` (all substantive content — engineering rules — preserved in frontend-design Part II; only branding/title lost) | Delete **after** `frontend-design` push lands, not before |
| `commit-hygiene` | Stale (dated 2026-02-04), predates the `github` bundle consolidation; content covered by `/commit` + `~/.claude/rules/git-workflow.md` | **Open decision** — flagged, not auto-deleted (see §7) |

**Correctly absent already** (no action needed): `ship-to-dev`, `release-to-main`,
`git-cleanup`, `publish-github`, `security-review`, `create-feature-spec`.

---

## 3. Per-Repo Change List

### Global profile (`C:\Users\erik.OPBTA\.claude`)
- Not a git repo — direct edits, no branch/PR.
- Push: `frontend-design`, `add-feature`, `finishing-a-development-branch`, `security`,
  `github` (see §2 table).
- Delete: `design-taste-frontend` (after frontend-design push); `commit-hygiene` (open
  decision, see §7).
- Edit `~/.claude/CLAUDE.md`: add "Git Workflow Consolidation" section mapping old git skills
  → github bundle ops (see §4 canonical block).
- Edit `~/.claude/rules/git-workflow.md`: lead Release Flow section with `/release`
  (github skill); lead feature-branch workflow with `/ship`; keep manual steps as fallback
  reference.
- Optional: new `~/.claude/rules/design-ui.md` documenting `frontend-design` as canonical
  successor of `design-taste-frontend` (trigger scope: web components, pages, artifacts,
  posters, applications).

### 1. chrome_toolbar (`C:\development\chrome_toolbar`)
- Delete local copy: `.claude/skills/security/` (577-line stale copy, no customization,
  no companion commands).
- CLAUDE.md (118 lines) edits:
  1. Update security-skill reference — remove local path (`.claude/skills/security/SKILL.md`),
     use name-based reference with archive's richer trigger description.
  2. Add canonical "Skill Management" block (§4).
  3. Add canonical "Development Branch Conventions" block (§4) — `type/short-description` off
     `dev`; `/ship` to dev; `/release` for dev→main.
  4. Add "Feature Development Workflow" — `/add-feature` → project-manager scaffolding, **but
     note this repo uses `_project_specs/` instead of `docs/`** for PM artifacts — adapt any
     boilerplate path references accordingly.
  5. Optional: reference `security-aware-persistence-design` skill (repo persists user-supplied
     data via extension+API+database — relevant but not currently referenced).
- AGENTS.md: **missing — create** with agent/trigger table (project-manager: `/add-feature`,
  `/continue-tasks`, `/review-tasks`; `code-review`; `security-reviewer`; github bundle:
  `/ship`, `/merge`, `/release`, `/release-init`; `tdd`; `simplify`).
- No file:line legacy references found (0 hits for old git skills or github-bundle commands
  beyond incidental GitHub URLs in test fixtures).

### 2. scan_organization (`C:\development\scan_organization`)
- Delete local copy: `.claude/skills/security/` (577-line stale copy, identical pattern to
  chrome_toolbar, no customization).
- CLAUDE.md (674 lines) edits:
  1. Skills section (lines 5–13): update security bullet — remove local path reference, use
     archive description with activation triggers.
  2. Add canonical github-skill reference block (§4): `/ship`, `/merge`, `/release`, `/commit`,
     `/prune`, `/publish`, `/release-init`.
  3. New "Development Workflow" section: feature branches `type/short-description` off dev;
     `/add-feature` for scaffolding; `/ship` to dev; `/release` dev→main.
  4. Add canonical "Skill Management" block (§4).
  5. Optional: align "Pull Request Requirements" (~line 245) with `/ship` targeting dev.
- AGENTS.md: missing — optional (no PM agent roles currently formalized here beyond generic
  workflow docs; lower priority than chrome_toolbar's).
- No legacy git-skill references found beyond an incidental `logs/timing.jsonl` mention; all
  "release/security/publish" hits in `.github/workflows/*.yml`, `.pre-commit-config.yaml`,
  `scripts/security-check.ps1` are CI/script names, not skill invocations — no edits needed
  there.

### 3. WinAppProfiles (`C:\development\WinAppProfiles`)
- Delete local copies: `.claude/skills/security/` (14,163 B stale, `installed-from: llm_skills`,
  broken `## Diagram` link with no diagram.html) **and** `.claude/skills/commit-hygiene/`
  (`installed-from: llm_skills` — superseded by github bundle, confirm alongside the global
  commit-hygiene open decision).
- File edit: `Directory.Build.props:8` — XML comment references `/release-to-main` → change to
  `/release`.
- CLAUDE.md (241 lines) edits:
  1. Add "Skill Usage & Development Workflow" section: `/add-feature` (PM scaffolding), branch
     convention `type/short-description` off dev, `/commit`, `/ship` (PR → dev), `/merge`,
     `/release` (dev→main), `/release-init` (one-time provisioning — see open decision §7).
  2. Add security-skill trigger section (when to activate; pre-release checklist).
- AGENTS.md (38 lines, exists) edits: revise "Commit & Pull Request Guidelines" (lines 28–32)
  — currently describes a generic `feature/* -> dev -> main` flow; replace with github-bundle
  command flow (`/commit`, `/ship`, `/merge`, `/release`) + conventional commits + PR
  requirements + release flow (canonical block, §4).
- Repo-specific note: **.NET/C# Windows desktop repo** — security skill's npm/pip-oriented
  tooling doesn't directly apply; flag for security-reviewer agent to use .NET-aware patterns
  (parameterized queries via Dapper, etc.) — do not block on this, just note it.
- No `.github/workflows` yet — `/release-init` has not been run (see open decision §7).

### 4. ac-repo-radar (`C:\development\ac-repo-radar`)
- Delete local copy: `.claude/skills/add-feature/` (7,661 B, `installed-from: llm_skills`,
  single-mode CAP-ID workflow, no PM deferral logic).
- Companion command `.claude/commands/add-feature.md` (thin wrapper: "Invoke the
  `project-manager:add-feature` skill and follow it exactly") — **keeps working unchanged**
  after deletion; no edit needed (still resolves correctly once global add-feature exists).
- File edit: `docs/INITIAL_PROMPT.md:123` — `/publish-github` skill reference → `github:publish`
  sub-command (or `/publish`).
- CLAUDE.md (296 lines) edits:
  1. §8 Git workflow (lines 187–230): lead with github-skill commands (`/ship` PR to dev,
     `/merge` to land, `/release` dev→main, `/commit`, `/prune`, `/publish`) then keep the
     existing strict PR-only rules as detail.
  2. §10 Agent boundaries: add — "`/add-feature` always defers to `project-manager:add-feature`
     when PM scaffolding is detected; never invoke standalone add-feature workflows in this
     repo."
  3. §12 Useful references: link AGENTS.md.
- AGENTS.md: **missing — create** with: Git & Release Workflow (`/ship`, `/merge`, `/release`,
  `/commit`, `/prune`, `/publish`; never legacy skills), Feature Specification (always
  `/add-feature` → PM deferral; never create feature files manually), Skill Updates
  (`/update-skill`; no repo-local forks; global-profile resolution), legacy-reference cleanup
  note pointing at the INITIAL_PROMPT.md fix above.
- Open item: `docs/features/template.md` uses CAP-ID format but the 14 existing feature specs
  do not — template/format alignment is an open decision (§7), not part of this migration's
  scope.
- Missing `docs/workflow/SDLC.md` means the archive's PM-deferral condition isn't fully met
  even after deletion — archive add-feature falls back to its own two-mode behavior, which is
  strictly better than the deleted local copy's single CAP-ID-only mode. Creating the stub is
  an open decision (§7), not required for this migration to be safe.

### 5. AC_OPBTA (`C:\development\AC_OPBTA`)
- Delete local copy: `.claude/skills/add-feature/` (7,661 B, `installed-from: llm_skills`,
  2026-05-16, no companion command exists — already removed per project-manager dedup
  2026-07-06).
- CLAUDE.md edits:
  1. Line 29: `"The ship-to-dev skill encodes the canonical PR workflow..."` →
     `"The github skill (sub-command /ship) encodes the canonical PR workflow to dev..."`.
  2. Add a "Skill resolution and PM framework" section after "How to find anything in this
     repo": document that PM sub-commands (`/init-project`, `/init-features`, `/add-feature`,
     `/reinit`, ...) are **incompatible with this repo's §10 frontmatter schema pending
     BUCKET-2 migration**; feature specs continue to be created per
     `docs/plans/tooling--task-management-process-unification.md §10` until that migration
     lands; skills resolve from the global profile only (`/update-skill`, no private forks).
- AGENTS.md (present, minimal — graphify only): add a "Skill Resolution and Consolidation"
  section — canonical bundles live in the ai-agent-kit archive → pushed to `~/.claude/skills`;
  repo-local copies deleted; old git skills (`ship-to-dev`, `release-to-main`, `git-cleanup`,
  `publish-github`, `commit-hygiene`) → github bundle (`/ship`, `/merge`, `/release`,
  `/commit`, `/prune`, `/publish`, `/release-init`).
- **BUCKET-2 frontmatter-contract caveat (critical, this repo only):** `add-feature`'s
  archive Conversational Mode writes date-prefixed slug specs with a different frontmatter
  shape than this repo's §10 contract (`feature:`, `slug:`, `status:`, `area:`, dates,
  `author:`). `scripts/check-docs-taxonomy.py` will **reject** specs produced by either the
  old local skill or the new archive skill under this repo's current contract. Deleting the
  stale local copy is still safe (the project-manager SKILL.md in this repo already marks
  `/add-feature` as "**Do not run yet.** Frontmatter contract diverges; await BUCKET-2
  migration") — but do not expect `/add-feature` to be usable here until BUCKET-2 lands. This
  is tracked as an open decision (§7), not blocking the deletion itself.
- `graphify-out/manifest.json` / `graph.json` contain stale references to deleted worktree
  copies — run `graphify update .` after deletion (cosmetic, non-blocking).

### 6. neurorep_v3 (`C:\development\neurorep_v3`)
Most complex repo — 4 skill deletions in one pass (`create-feature-spec`, `frontend-design`,
`security`, `finishing-a-development-branch`).

- Delete local copies:
  - `.claude/skills/create-feature-spec/` (4,446 B, superseded by `add-feature`, which also
    answers the `/create-feature-spec` trigger phrase).
  - `.claude/skills/frontend-design/` (42-line truncated skeleton — Part II Engineering
    Directives, the "100 AI Tells" list, Motion-Engine Bento paradigm, and diagram.html are
    all absent locally and gained from the archive).
  - `.claude/skills/security/` (577-line stale copy — same pattern as other repos).
  - `.claude/skills/finishing-a-development-branch/` (4,450 B, dated 2026-02-05 — describes a
    4-option manual `git merge`/`gh pr create` workflow that checks `main` before `dev`; archive
    version is 3-option, delegates to `/ship`, and checks `dev` before `main`, matching this
    repo's dev-first workflow per CLAUDE.md lines 167–170).
- **Repo-specific content that MUST be preserved into CLAUDE.md before deletion** (from the
  deleted `create-feature-spec` copy — this is the one skill deletion in the whole migration
  with real content loss risk): hardcoded NeuroRep conventions — "hexagonal architecture,
  canonical models, API standards" and the instruction to match the quality bar of
  `docs/features/WORKFLOW_v2.md`. Fold this into CLAUDE.md's feature-spec guidance (see edit
  #2 below) so it isn't lost when the generic archive `add-feature` skill takes over.
- CLAUDE.md edits (all four deletions covered in one pass):
  1. Line 21: `.claude/skills/ship-to-dev/SKILL.md - Automated shipping to dev branch` →
     replace with a `github` skill reference (ship/merge/release/commit/prune/publish
     operations). **Note: this is a dangling reference already** — no local `ship-to-dev`
     skill exists in this repo; the line predates the consolidation and was never cleaned up.
  2. Line 25: `.claude/skills/create-feature-spec/SKILL.md - Feature specification format` →
     replace with `add-feature` (global) reference, **plus the preserved NeuroRep-specific
     guidance** (hexagonal architecture / canonical models / API standards / match
     `docs/features/WORKFLOW_v2.md` depth) folded directly into this section's prose.
  3. Line 24 (`finishing-a-development-branch`): keep the bullet, but note it now delegates
     integration to the github `ship` operation.
  4. Skills list (~lines 20–29): `frontend-design` and `security` bullets updated to reference
     global resolution (local copies deleted).
  5. Git Workflow section (~lines 159–184): repo uses a dev/uat/main branch strategy ("NEVER
     push directly to main"). Add the canonical github-skill operations table (§4) and note
     that the old standalone skills are consolidated into `github`.
- AGENTS.md: does not exist — optional; could formalize the 3 existing agent profiles
  (backend-api-developer, docs-test-engineer, webui-developer). Not required for this
  migration.
- Existing feature specs (WORKFLOW.md, AI_MODELS.md, CRAWLER.md, MANAGEMENT_SERVICE.md,
  UI_TASK_MANAGER.md) have inconsistent legacy naming vs. the archive's date-prefixed slug
  output — leave as-is (migrating existing specs is out of scope; open decision §7 only
  covers the *going-forward* naming choice).

---

## 4. CLAUDE.md / AGENTS.md Edit Specs

Two canonical blocks are defined once here and referenced by name in the per-repo list above,
to avoid repeating boilerplate 6 times. Adapt path/section placement to each repo's existing
structure — do not impose a section a repo doesn't already organize content around.

### Canonical block A — "github-bundle workflow"

```markdown
## Git & Release Workflow

All git integration work goes through the `github` skill (never legacy standalone skills):

| Old skill | New command | Operation |
|---|---|---|
| `ship-to-dev` | `/ship` | Stage, commit, push, open PR, merge to dev, clean up |
| `git-cleanup` | `/prune` | Remove stale branches and worktrees |
| `release-to-main` | `/release` | Promote dev → main as a versioned release |
| `publish-github` | `/publish` | Publish/provision repo-level GitHub settings |
| `commit-hygiene` | `/commit` | Stage, pull, commit (conventional), push |
| *(new)* | `/merge` | Merge one or more open PRs into dev with a merge commit |
| *(new)* | `/release-init` | One-time provisioning of changelog + tag-triggered release automation to the Release-Automation Standard |

Never invoke the old skill names — they no longer exist. Never merge or push directly into
`dev`/`main` locally; always delegate integration to `/ship` (feature branches) or `/release`
(dev→main).
```

### Canonical block B — "skill resolution / no local forks"

```markdown
## Skill Management

Skills are NOT forked per-repo. Canonical skill bundles live in the ai-agent-kit archive
(`C:\development\ai-agent-kit`) and are pushed to the global profile
(`~/.claude/skills`). This repo does not keep private copies of shared skills — use
`/update-skill` to refresh, and resolve skills from the global profile by default. If a skill
appears to be missing or stale, that is a global-profile problem to fix upstream, not a reason
to install or edit a local copy.
```

Per-repo insertions and deviations are listed in §3 above (e.g. chrome_toolbar's
`_project_specs/` vs `docs/`, AC_OPBTA's BUCKET-2 caveat layered into block B, neurorep_v3's
preserved hexagonal-architecture guidance layered into its feature-spec section rather than
block B verbatim).

---

## 5. Reference-Migration Table

| Old | New | File:line hits found |
|---|---|---|
| `/ship-to-dev` | `/ship` | neurorep_v3 `CLAUDE.md:21` (dangling — no local skill exists) |
| `/release-to-main` | `/release` | WinAppProfiles `Directory.Build.props:8` (XML comment) |
| `/git-cleanup` | `/prune` | none found |
| `/publish-github` | `/publish` (or `github:publish`) | ac-repo-radar `docs/INITIAL_PROMPT.md:123` |
| `/commit-hygiene` | `/commit` | AC_OPBTA `CLAUDE.md:29` ("ship-to-dev skill encodes the canonical PR workflow" — adjacent wording, same edit) |
| `/create-feature-spec` (standalone) | `/add-feature` | neurorep_v3 `CLAUDE.md:25` |
| `design-taste-frontend` | `frontend-design` | none found referencing by name in any repo CLAUDE.md/AGENTS.md |
| `security-review` | `security` | none found referencing by name in any repo CLAUDE.md/AGENTS.md |
| — | — | `~/.claude/CLAUDE.md` / `~/.claude/rules/git-workflow.md` — add consolidation mapping (§2, §3 Global profile) |

Additional non-command references requiring cleanup:
- neurorep_v3 `CLAUDE.md:24` — `finishing-a-development-branch` bullet, keep but annotate
  delegation to github `ship`.
- neurorep_v3 `CLAUDE.md:25` context — fold in preserved NeuroRep-specific spec guidance (see
  §3 neurorep_v3).
- WinAppProfiles `.claude/skills/commit-hygiene/SKILL.md:1` — local commit-hygiene copy,
  delete alongside global copy decision (§7).

---

## 6. Risks

Deduplicated across all 11 reports:

1. **Ordering risk — global-vs-local staleness (highest severity, affects every repo).**
   `security`, `add-feature`, `frontend-design`, and `finishing-a-development-branch` all have
   the property that deleting the repo-local copy without first refreshing (or creating) the
   global copy either changes nothing (repo falls back to an equally stale global `security`)
   or breaks the skill entirely (repo falls back to a *nonexistent* global `add-feature`/
   `frontend-design`/`finishing-a-development-branch`). This is why §8's implementation order
   fixes the global profile first, in its own iteration.
2. **neurorep_v3 `.worktrees/` staleness.** 42+ git worktrees under `.worktrees/` each carry
   their own copy of `.claude/skills/`. Deleting from the main working tree does not touch
   worktree copies. Either prune stale worktrees first, or accept that old worktrees keep
   resolving to stale local copies indefinitely (low practical impact — worktrees are
   short-lived by convention, but flag it).
3. **AC_OPBTA §10 frontmatter contract vs. archive `add-feature` output.** The archive skill's
   Conversational Mode and this repo's BUCKET-2-pending §10 contract produce incompatible
   frontmatter; `scripts/check-docs-taxonomy.py` rejects both the old and new skill's output
   under the current contract. `/add-feature` remains effectively unusable in AC_OPBTA until
   BUCKET-2 migration lands, independent of this consolidation.
4. **WinAppProfiles is a .NET/C# repo; the `security` skill's tooling (npm audit, lock-file
   checks, JS/TS code examples) doesn't map 1:1.** Not blocking, but security-reviewer agent
   usage there should lean on .NET-idiomatic patterns (parameterized queries via Dapper, etc.)
   rather than the skill's default examples.
5. **`/release-init` has not been run in most repos yet.** WinAppProfiles has no
   `.github/workflows` at all; other repos' release-automation conformance vs. the new
   Release-Automation Standard is unverified. `/release` itself still works without it
   (manual fallback), but full changelog/tag automation requires the one-time `/release-init`
   pass. Scope and timing is an open decision per repo (§7).
6. **`commit-hygiene` deletion (both global and WinAppProfiles-local) is content-safe but
   policy-sensitive.** Content is fully covered by `/commit` + `rules/git-workflow.md`, but
   deleting is a slightly different class of action (removing a whole skill by policy
   decision, not just refreshing a stale copy) — flagged as an open decision rather than
   auto-applied (§7).
7. **ac-repo-radar template/format mismatch.** `docs/features/template.md` uses CAP-ID format
   but the 14 existing feature specs don't — not caused by this migration, but the migration
   surfaces it since `/add-feature` will now be the actively-used path.
8. **neurorep_v3 dangling `ship-to-dev` reference predates this migration** (`CLAUDE.md:21`
   points at a skill that was never actually installed locally) — confirms CLAUDE.md drift
   independent of the current consolidation; must be fixed in the same edit pass regardless.
9. **Diagram assets.** Several archive skills include `diagram.html` that stale local/global
   copies lack (`security`, `github`, `frontend-design`, `finishing-a-development-branch`,
   `add-feature`). Purely additive — no risk, but confirm `/push-skill` carries the diagram
   file, not just SKILL.md.
10. **No `installed-from:` provenance marker on several stale copies** (global `security`,
    neurorep_v3's four skills, chrome_toolbar's `security`, scan_organization's `security`) —
    can't trace how/when they were installed. No action required, just reduces auditability
    going forward; consider stamping the marker convention on all future installs.

---

## 7. Open Decisions for the Human

Deduplicated across all reports — none of these are decided by this report; the implementation
loop must skip/flag them rather than resolve them unilaterally.

1. **Delete `commit-hygiene` from the global profile (and WinAppProfiles' local copy)?**
   Content is fully superseded by `/commit`, but it's a policy call to delete a skill outright
   vs. leave it dormant.
2. **neurorep_v3 project-manager adoption: Option A vs Option B.**
   - **A**: adopt full project-manager scaffolding (`/init-project` + CAP-ID migration of
     existing specs).
   - **B**: continue with standalone `add-feature` (date-prefixed slug naming going forward,
     existing specs left as-is).
   - Phase A recommendation leaned B (lower friction) unless the team wants formal
     orchestration — still the human's call.
3. **AC_OPBTA: create a `docs/workflow/SDLC.md` stub now, or defer until BUCKET-2 migration
   proper?** Affects whether `/add-feature`'s PM-deferral path can even partially engage in
   this repo.
4. **ac-repo-radar: align `docs/features/template.md` to the existing (non-CAP-ID) feature
   spec convention, or migrate existing specs to CAP-ID?**
5. **Run `/release-init` per repo, and on what timeline?** Candidates needing it most:
   WinAppProfiles (no `.github/workflows` yet); verify conformance in the other five repos
   before assuming `/release` is fully automated everywhere.
6. **Create AGENTS.md where missing?** Recommended default: **yes**, where a repo already has
   formalized agent workflows worth documenting (chrome_toolbar, ac-repo-radar, AC_OPBTA all
   flagged as "create"); **skip** where a repo has no agent-role complexity to document yet
   (scan_organization, neurorep_v3 — optional only).
7. **AC_OPBTA project-manager skill role**: keep installed as a documented "not yet usable"
   reference, patch it to be usable now, or remove it entirely pending BUCKET-2? Currently
   installed + marked "Do not run yet" is a confusing middle state.
8. **AC_OPBTA / neurorep_v3 spec-naming conventions** (dates in filenames, hexagonal
   architecture guidance depth) — cosmetic alignment, not required for correctness, left to
   human taste.

---

## 8. Implementation Order

0. **Global profile** (`C:\Users\erik.OPBTA\.claude` — not a git repo, direct edits, no PR):
   - `/push-skill frontend-design`
   - `/push-skill add-feature`
   - `/push-skill finishing-a-development-branch`
   - `/push-skill security` (overwrite stale copy)
   - `/push-skill github` (overwrite stale copy — picks up `release-init`)
   - Delete `~/.claude/skills/design-taste-frontend/` (superseded; safe once frontend-design
     push has landed)
   - Delete `~/.claude/skills/commit-hygiene/` **only if** open decision #1 (§7) is resolved
     to "yes" — otherwise leave in place and flag
   - Edit `~/.claude/CLAUDE.md`: add Git Workflow Consolidation section (canonical block A,
     §4, adapted)
   - Edit `~/.claude/rules/git-workflow.md`: lead Release Flow with `/release`, lead
     feature-branch workflow with `/ship`
   - Optional: add `~/.claude/rules/design-ui.md`

1. **chrome_toolbar** — delete local `security`; apply CLAUDE.md edits; create AGENTS.md.
2. **scan_organization** — delete local `security`; apply CLAUDE.md edits.
3. **WinAppProfiles** — delete local `security` + `commit-hygiene`; fix
   `Directory.Build.props:8`; apply CLAUDE.md + AGENTS.md edits; consider `/release-init`.
4. **ac-repo-radar** — delete local `add-feature`; fix `docs/INITIAL_PROMPT.md:123`; apply
   CLAUDE.md edits; create AGENTS.md.
5. **AC_OPBTA** — delete local `add-feature`; apply CLAUDE.md edits (incl. line 29 fix + BUCKET-2
   caveat); apply AGENTS.md edits; run `graphify update .`.
6. **neurorep_v3** (most complex — 4 deletions in one pass) — delete local `create-feature-spec`,
   `frontend-design`, `security`, `finishing-a-development-branch`; preserve NeuroRep-specific
   spec guidance into CLAUDE.md before/during deletion; fix dangling `ship-to-dev` reference
   at line 21; apply full CLAUDE.md edit set (§3 neurorep_v3).

Each repo iteration (1–6): feature branch off `dev`, conventional commit, PR back to `dev`,
merge with merge commit, verify, clean up branch/worktree. Skip/flag any open decision from §7
rather than resolving it in the loop.
