---
title: Canonical Repo Restructure — Implementation Plan
date: 2026-07-13
status: approved — erik, 2026-07-13 (3 review-committee rounds; P1–P5 decided, see requirements §7)
requirements: docs/requirements/canonical-repo.md
charter-dependency: docs/reorg/charter.md (binding; skill-structure decisions defer to it)
---

# Canonical Repo Restructure — Implementation Plan

Self-contained execution checklist. Each task is dispatchable to a single subagent with
only this file, the requirements doc, and the task's listed references as context. The
orchestrator verifies each task's acceptance criteria before checking it off.

**Global rules for every task** (include in every subagent prompt):

- Work on a feature branch off latest `dev`; PR back to `dev`; never push to `dev`/`main`.
- Never move, rename, or delete anything under `claude/skills/`, `codex/skills/`, or
  `gemini/skills/` except the explicitly scoped frontmatter additions in T5
  (requirements N1/N2). Skill structure belongs to `docs/reorg/charter.md`.
- `install-skills.ps1` stays at repo root (requirements D5).
- New PowerShell scripts: `#Requires -Version 7.0`, cross-platform (no Windows-only
  APIs), `utf8NoBOM` output, ordinal sorting, and the requirements §6 shared
  conventions (parameters, exit codes, safety, subprocess rules).
- Conventional commits; PR description = Summary + Test Plan; ≤800 changed lines
  (generated-file or deletion-heavy overages must be called out in the PR body for
  explicit sign-off).
- Do not hand-edit `manifest.json` or `CATALOG.md` — regenerate.
- Any task that flips a script from stub to implemented also updates the status column
  in `scripts/README.md` in the same PR.

## PR map

| PR | Tasks | Content | Est. changed lines |
|---|---|---|---|
| PR 1 | — | requirements doc + this plan (this branch: `docs/canonical-repo-restructure`) | ~480 |
| PR 2 | T1, T2 | `shared/` tree + prompts move + all folder READMEs | ~550 (mostly new files) |
| PR 3 | T3 | script stubs + `scripts/README.md` | ~400 |
| PR 4 | T4 | `audit.ps1` implemented + `generate-manifest.py` `--output`/`--validate` flags | ~450 |
| PR 5 | T5 | category frontmatter backfill + manifest generator taxonomy removal | ~200 hand + manifest regen (generated) |
| PR 6 | T6 | `generate-catalog.ps1` implemented + `CATALOG.md` | ~150 hand + CATALOG (generated) |
| PR 7 | T7 | root `README.md` rewrite + project `CLAUDE.md` pointer fix | ~600 (mostly deletion of old tables) — flag overage, deletion-heavy |
| PR 8 | T8, T9 | local validation gate (validate.ps1 + hook installer + CLAUDE.md rule) + CONTRIBUTING.md | ~350 |

Sequencing constraints (the real dependencies, not folder aesthetics):

- **PR 2 → PR 3:** T3's `scripts/README.md` documents conventions (D5 trust model,
  shared/ regeneration duties) that reference the T1/T2 READMEs.
- **PR 3 → PR 4:** T4 implements against the stub contracts and README conventions
  established by T3.
- **PR 4 → PR 5 → PR 6 → PR 7:** audit must exist before the mass frontmatter sweep
  (T5 verification); catalog needs categories (T6 needs T5); README rewrite links to
  `CATALOG.md` (T7 needs T6).
- **PR 8 last** — it gates on scripts from PR 4/6 existing.

---

## Tasks

### T1 — `shared/` tree + prompts move
- [x] **Status:** done — PR #58
- **Agent / model:** general-purpose / sonnet
- **Description:** Create the vendor-neutral asset area and populate its first class.
- **Work plan:**
  1. Verify with grep that no repo file outside `docs/requirements/` and `docs/plans/`
     references `claude/prompts` (analysis on 2026-07-13 found none), then
     `git mv claude/prompts shared/prompts` (3 files).
  2. Write `shared/README.md`: the D1 vendor-neutral test (quote it), the four classes,
     how a new class is added (README-first, then assets).
  3. Write `shared/prompts/README.md` (naming, one-prompt-per-file, frontmatter:
     `name`, `description`, optional `use-with`).
  4. Write `shared/workflows/README.md` — must include the requirements §5 boundary
     sentence verbatim: "a shared workflow is a vendor-neutral orchestration *document*
     a human or agent follows; anything that installs and triggers as a skill belongs
     in a vendor skill tree."
  5. Write `shared/configs/README.md` (reusable config fragments; **no secrets —
     pointers only**, enforced mechanically by `audit.ps1`'s secret-scan check once T4
     lands).
  6. Write `shared/plugins/README.md`: pure reference list; every entry carries
     provenance and a vetting status (`vetted` / `unvetted`); make **no ownership
     claims** about plugin-precedence declarations — that belongs to skills-manager
     `external-skill-intake` (charter §4) once that sub-skill ships.
  7. `workflows/`, `configs/`, `plugins/` contain only their README (D7).
- **Acceptance criteria:** `claude/prompts/` gone; 3 prompt files intact under
  `shared/prompts/` (`git log --follow` shows rename); 5 new READMEs; no other tree
  changes; grep for `claude/prompts` **outside `docs/requirements/` and `docs/plans/`**
  returns nothing; workflows boundary sentence present verbatim; plugins README has the
  provenance/vetting rule and no ownership claims.
- **References:** requirements §4 D1/D6/D7, §5 (class boundary); `docs/reorg/charter.md` §4.

### T2 — Folder READMEs (root-level + vendor subtrees)
- [x] **Status:** done — PR #58
- **Agent / model:** general-purpose / sonnet
- **Description:** Give every root-level folder a prescriptive README (G4).
- **Work plan:**
  1. `claude/README.md` — canonical authoring surface; explain `skills/` bundle anatomy
     (SKILL.md, sub-skills/, commands/, references/, rules/), `instructions/`
     frontmatter contract, `commands/` vs skill-bundled commands.
  2. `codex/README.md` — on-demand mirror + source-version stamp (charter §5);
     instructions subtree marked "mirror policy: TBD (OQ4)".
  3. `gemini/README.md` — frozen at current set (charter §5); same OQ4 line for
     instructions.
  4. `docs/README.md` — map `requirements/`, `plans/`, `reorg/` (binding governance),
     `reports/`.
  5. Untrack `logs/` per P5: `git rm -r --cached logs/`, add `logs/` to `.gitignore`;
     no `logs/README.md` (G4 applies to tracked folders only).
  6. Do NOT write `scripts/README.md` here — it ships with T3 so it stays consistent
     with the stubs it documents.
- **Acceptance criteria:** READMEs exist for `claude/`, `codex/`, `gemini/`, `docs/`;
  each states purpose, contents, conventions in ≤60 lines; charter cited where it
  governs; vendor instruction sections carry the OQ4 TBD line rather than an invented
  policy; `logs/` absent from `git ls-files` and present in `.gitignore` (local file
  untouched on disk); no README contradicts `docs/reorg/charter.md` or the
  requirements doc.
- **References:** requirements §5 coverage rule, OQ4; charter §5, §6; root `CLAUDE.md`.

### T3 — Script stubs + `scripts/README.md`
- [x] **Status:** done — PR #59
- **Agent / model:** general-purpose / sonnet
- **Description:** Enumerate the automation surface as documented PowerShell 7 stubs.
- **Work plan:**
  1. Create `install-to-project.ps1`, `push-to-profile.ps1`, `sync-installed.ps1`,
     `generate-catalog.ps1`, `backfill-categories.ps1`. Each stub: comment-based help
     (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.OUTPUTS`, exit codes) matching the
     requirements §6 contracts **including the shared conventions table** (common
     parameter surface, preview-by-default, backup/no-clobber, path containment), then
     a `param(...)` block and `throw "TODO: not implemented"` body.
  2. `#Requires -Version 7.0` in every new script; note in `scripts/README.md` that
     `install-skills.ps1`'s 5.1 floor is a grandfathered remote-bootstrap exception.
  3. Write `scripts/README.md`: table of all scripts incl. existing
     `generate-manifest.py`, implemented-vs-stub status column, the root-installer URL
     contract **with its trust model and integrity-conscious alternatives spelled out
     (requirements D5)**, and the regeneration rule (charter rule 6). Cross-link the
     `shared/` READMEs (regeneration duties for shared assets) and vendor-tree READMEs
     from T1/T2 — this is the concrete PR2→PR3 dependency.
- **Acceptance criteria:** 5 stubs + README exist; `Get-Help ./scripts/<stub>.ps1`
  renders synopsis/params; running a stub exits non-zero with a TODO message; contracts
  textually consistent with requirements §6 incl. shared conventions; trust-model
  language present.
- **References:** requirements §6 (incl. shared conventions), D3, D5;
  `install-skills.ps1` (style precedent only — its 5.1 floor is not to be copied);
  `.claude/commands/install-skill.md`, `.claude/commands/audit-skills.md`.

### T4 — Implement `audit.ps1` (+ generator flags)
- [x] **Status:** done — PR #61
- **Agent / model:** general-purpose / opus (multi-check logic; single-parser design)
- **Description:** Real, read-only archive health check per requirements §6.
- **Work plan:**
  1. Extend `scripts/generate-manifest.py` with `--output PATH` (default unchanged:
     repo-root `manifest.json`) and `--validate --json` (emit parsed frontmatter +
     per-skill validation results to stdout). **One frontmatter parser for the whole
     repo** — `audit.ps1` consumes this JSON instead of re-implementing YAML parsing
     in PowerShell.
  2. Implement checks (each → finding record with severity `error|warn|info`) exactly
     as listed in requirements §6: frontmatter validity + name/dir match [error];
     missing `category:` [severity keyed off the generator's `categorySource` marker
     from `--validate --json`: `legacy-dict` → warn, `frontmatter` → error — explicit
     signal, never a coverage heuristic]; `installed-from:` in archive [error];
     secret-shaped content under `shared/` — API-key/token/connection-string regex set
     [error]; manifest freshness via `--output <temp>` + diff **excluding the volatile
     `generated` timestamp field** (raw diff false-positives on day rollover) [error];
     CATALOG parity both directions if `CATALOG.md` exists [error]; Claude↔Codex gap
     [info]; missing `diagram.html` [info].
  3. Exit codes: `0` clean or warnings-only; `1` any error-severity finding; `2`
     execution failure. Console table + `-Json` flag.
  4. Subprocess safety: explicit interpreter + argument array (no shell string
     interpolation), bounded non-predictable temp path (requirements §6 shared
     conventions).
  5. Run against the live repo; fix false positives; document known findings in PR
     body. Note: the CATALOG-parity branch can only be exercised against a seeded
     fixture until T6 lands — say so in the PR body; T6 re-verifies it live.
  6. Update `scripts/README.md` status column (audit → implemented,
     generate-manifest.py → modified).
- **Acceptance criteria:** runs clean-or-explained on current repo in <60s; detects a
  seeded fault of each class in a temp fixture (test evidence in PR body); read-only
  outside temp; exit codes as specified; no second YAML parser exists in the PowerShell
  code; `scripts/README.md` status current.
- **References:** requirements §6; charter §5, §6, §10; `scripts/generate-manifest.py`
  (esp. its block-scalar frontmatter handling, lines ~129–144).

### T5 — Category frontmatter backfill + manifest generator update
- [x] **Status:** done — PR #62 (P1 approved — sub-step 3b delivered)
- **Agent / model:** general-purpose / sonnet (script does the sweep; agent writes the script)
- **Description:** Make `category:` frontmatter the single source of truth (D8).
- **Work plan:**
  1. Implement `backfill-categories.ps1`: seed mapping from the `CATEGORIES` dict in
     `generate-manifest.py` reconciled against the pre-rewrite README table categories
     (README wins on conflict — it is newer); inject `category:` into each Claude
     `SKILL.md` frontmatter; **skip any file whose frontmatter already has a non-empty
     `category:`** (protects hand assignments; this is the idempotency rule);
     `-WhatIf` preview by default, explicit apply flag; emit an unresolved-skills
     report for human assignment.
  2. Run preview → apply; hand-assign any unresolved skills (list them in the PR body
     for erik).
  3. Update `generate-manifest.py`: (a) read `category:` from frontmatter and delete
     the hardcoded skill→category dict, mirrors inherit the source skill's category —
     but **retain an explicit ordered category list** (curated order, not alphabetical)
     that populates `manifest['categories']`, preserving current display order; flip
     the `--validate --json` `categorySource` marker to `frontmatter`; (b) add
     `schemaVersion` to manifest output and document the manifest shape in
     `scripts/README.md` (P1 — approved).
  4. Regenerate `manifest.json`; verify escalation concretely: `audit.ps1 -Json` now
     reports the missing-category finding type at severity `error` (seed one skill
     with the field removed in a temp fixture to prove it).
  5. Update `scripts/README.md` status column (backfill → executed).
- **Acceptance criteria:** every Claude `SKILL.md` has `category:`; generator has no
  hardcoded skill→category mapping (the ordered category-display list remains, by
  design); regenerated manifest diff shows only category-sourcing changes
  (+ `schemaVersion` if P1 approved); `audit.ps1` exits 0 on the live repo and the
  seeded-fixture escalation check passes; no non-frontmatter content changes under
  `*/skills/` (`git diff` inspection); `scripts/README.md` status current.
- **References:** requirements D8, §6, §7 P1; `scripts/generate-manifest.py:14-95`
  (full `CATEGORIES` dict **and** the `STANDARD_SKILLS` list that follows it);
  pre-rewrite README category tables (git history if T7 already landed — it won't have,
  per PR map order).

### T5b — Align frontmatter names to directories
- [x] **Status:** done — PR #63
- **Agent / model:** general-purpose / sonnet
- **Description:** `audit.ps1`'s `name-dir-match` check (T4) surfaced 19 error-severity
  findings on the live repo: 10 distinct skills (9 mirrored in both `claude/skills/`
  and `codex/skills/`, plus `graphify` which is claude-only) whose frontmatter `name:`
  field disagrees with its directory name — legacy `vercel-`/`homeradar-` provenance
  prefixes (and one `graphify-windows`) that predate the directory rename, plus one
  inverse case (`vercel-deploy-claimable` directory vs. stale `vercel-deploy`
  frontmatter). These block T8's acceptance criterion of a clean `audit.ps1` exit.
- **Override (erik, 2026-07-14 — binding for this task only):** the plan's global rule
  "never move, rename, or delete anything under `*/skills/` except the T5 category
  additions" is explicitly overridden, **scoped strictly to the 19 frontmatter `name:`
  fields** identified by the live `audit.ps1` run (10 distinct skill names, see PR body
  table). No directory renames. No other content edits, moves, or deletions under
  `*/skills/`. Directory always wins — frontmatter is edited to match the directory,
  never the reverse.
- **Work plan:**
  1. Run `pwsh ./scripts/audit.ps1`; derive the finding list mechanically (do not trust
     a hardcoded table) — cross-check against the known 19/10 shape and stop to report
     any discrepancy.
  2. Edit each flagged `SKILL.md`'s `name:` frontmatter field to equal its directory
     name; keep `claude/` and `codex/` mirrors consistent with each other.
  3. Cross-reference sweep: grep the repo for each old frontmatter name; update any
     reference outside `*/skills/` (README rows, docs, command files, `requires:`
     lists) to the new name. Leave historical/dated docs (e.g. rationalization
     reports, consensus snapshots) describing past state untouched. References to old
     names found *inside* `*/skills/` (e.g. one skill's body prose linking to another
     by its old name, or a `diagram.html` label) are left as-is in this task — editing
     them would violate the "only `name:` lines change under `*/skills/`" acceptance
     criterion — and are reported as follow-up for a future skill-body pass.
  4. Regenerate `manifest.json` via `scripts/generate-manifest.py` (never hand-edited).
  5. README parity check for the 10 renamed skills (charter §6 duty).
- **Acceptance criteria:** `pwsh ./scripts/audit.ps1` exits `0` with zero
  error-severity findings on the live repo; `git diff dev...HEAD -- '*/skills/'` shows
  only `name:` frontmatter lines changed (19 files); no skill directory renamed
  (`git diff dev...HEAD --diff-filter=R --stat` empty for `*/skills/`); `manifest.json`
  regenerated; this section's override is recorded here and restated in the PR body.
- **Unblocks:** T8 (local validation gate) depends on `audit.ps1` exiting clean.
- **References:** requirements §6 (`audit.ps1` contract), N1/N2; charter §6 (parity
  follow-through); T4 (audit implementation).

### T5c — Category taxonomy consolidation
- [x] **Status:** done — PR #66
- **Agent / model:** general-purpose / sonnet
- **Description:** T6's generated `CATALOG.md` surfaced category drift from T5's
  backfill: two near-identical category names (`Tooling & DevOps` / `DevOps &
  Tooling`) and a split frontend taxonomy (`Frontend Frameworks` / `Frontend & UI`)
  that doesn't match erik's documented category vocabulary. erik reviewed the actual
  skill lists behind each name and issued binding decisions rather than a mechanical
  merge.
- **Override (erik, 2026-07-14 — binding for this task only, same shape as T5b's
  override):** the plan's global rule "never move, rename, or delete anything under
  `*/skills/` except the T5 category additions" is explicitly extended, **scoped
  strictly to the `category:` frontmatter VALUE on 28 named `claude/skills/*/SKILL.md`
  files** (15 DevOps-cluster skills + 7 `Frontend Frameworks` skills + 6 `Frontend &
  UI` skills). No directory renames, no `name:` changes, no body/content edits, no
  file moves or deletions. Nothing under `codex/skills/` or `gemini/skills/` changes
  (mirrors carry no `category:` of their own — T5 confirmed this still holds).
- **erik's decisions (binding — do not re-litigate):**
  1. **DevOps categories split by real meaning, not merged.** `Tooling & DevOps` (11
     skills) is unchanged. `DevOps & Tooling` (15 skills) is renamed to
     `Infrastructure & Ops` — the two clusters hid genuinely different skill
     populations (archive/lifecycle tooling vs. infra/observability diagnostics).
  2. **Frontend categories consolidated to match erik's global CLAUDE.md taxonomy**,
     which lists `Frontend` and `UI & Design` with no `Frontend Frameworks` entry.
     `Frontend Frameworks` (7 skills) and `Frontend & UI` (6 skills) both fold into a
     single `Frontend` category (13 skills). `UI & Design` (10 skills) is unchanged.
  - Net: 16 categories → 15. `DevOps & Tooling`, `Frontend Frameworks`, and
    `Frontend & UI` cease to exist; `Infrastructure & Ops` and `Frontend` appear.
- **Work plan:**
  1. Derive the affected file list mechanically from `manifest.json` (query by
     current category) rather than trusting a hardcoded list; cross-check against the
     15/7/6 shape and stop to report any discrepancy.
  2. Edit the `category:` frontmatter value in each of the 28 affected
     `claude/skills/*/SKILL.md` files per the decisions above.
  3. Update the curated `CATEGORY_ORDER` list in `scripts/generate-manifest.py`
     (16 → 15 entries): replace `Frontend Frameworks` + `Frontend & UI` with a single
     `Frontend` in the slot the frontend categories occupied; replace
     `DevOps & Tooling` with `Infrastructure & Ops` in the slot it occupied (right
     after `Tooling & DevOps`). Keep `scripts/backfill-categories.ps1`'s mirrored
     `$script:CategoryOrder` and `$script:CategorySeed` entries for the 28 skills in
     sync (comment-mandated).
  4. Regenerate `manifest.json` (`python scripts/generate-manifest.py`) and
     `CATALOG.md` (`pwsh ./scripts/generate-catalog.ps1 -Force`); verify byte-stable
     across repeat runs and locale-invariant (tr-TR).
  5. Fix stale category-count/category-name references outside the generated files:
     `scripts/README.md` (`16 entries` → `15 entries`, two occurrences),
     `README.md`'s "Categories at a glance" table and full skill-list table (28 rows).
     Do not touch `docs/reports/` or other dated historical snapshots.
  6. Run `pwsh ./scripts/audit.ps1`; fix any regressions before opening the PR.
- **Acceptance criteria:** `manifest.json`'s `categories` array has exactly 15
  entries, contains `Frontend` and `Infrastructure & Ops`, and does not contain
  `Frontend Frameworks`, `Frontend & UI`, or `DevOps & Tooling`; category membership
  counts are `Frontend` = 13, `Infrastructure & Ops` = 15, `Tooling & DevOps` = 11,
  `UI & Design` = 10; `git diff dev...HEAD -- 'claude/skills/'` shows only `category:`
  lines changed across 28 files; no changes under `codex/skills/` or `gemini/skills/`;
  `CATALOG.md` regenerated and byte-stable, no stale category headings remain;
  `pwsh ./scripts/audit.ps1` exits 0 with zero error-severity findings.
- **References:** requirements D8, §6; charter §6 (parity follow-through); T5, T5b
  (override precedent); T6 (the CATALOG.md run that surfaced the drift).

### T6 — Implement `generate-catalog.ps1` + first `CATALOG.md`
- [x] **Status:** done — PR #65
- **Agent / model:** general-purpose / sonnet
- **Description:** Render the full asset catalog from `manifest.json` (D2).
- **Work plan:**
  1. Deterministic renderer: categories in `manifest['categories']` order (curated —
     see T5 step 3a), skills sorted within category via
     `[System.StringComparer]::Ordinal` on name; output `utf8NoBOM`.
  2. Add `.gitattributes` entries pinning `CATALOG.md` and `manifest.json` to LF.
  3. Content: per-vendor skill tables (name-link, category, description, cross-vendor
     availability), instruction tables **including Codex/Gemini instructions** (OQ4 —
     they exist but are uncounted today), command tables, per-class shared-asset
     listings, generated header ("do not hand-edit; run scripts/generate-catalog.ps1")
     with source-manifest timestamp.
  4. Commit generated `CATALOG.md`; re-verify audit's CATALOG-parity check live (was
     fixture-only in T4).
  5. Update `scripts/README.md` status column (generate-catalog → implemented).
- **Acceptance criteria:** regeneration is byte-stable (run twice → no diff; run under
  a different locale → no diff); every skill directory on disk has exactly one row;
  every row's link resolves; `audit.ps1` CATALOG parity passes live; PR body flags the
  generated-file line count; `scripts/README.md` status current.
- **References:** requirements D2, §6, §7 P1; `manifest.json`; current README tables
  (content reference only — do not preserve their hand-drift).

### T7 — Root `README.md` rewrite + count-pointer fixes
- [x] **Status:** done — PR #68
- **Agent / model:** general-purpose / opus (orientation-writing quality is the deliverable)
- **Description:** Replace the 40KB catalog-README with a mission-first orientation doc.
- **Work plan:**
  1. New README: ≤150 lines AND ≤600 words of body prose (code blocks, tables, link
     lists excluded from the word count) — the mechanical proxy for G1's 2-minute
     read. Contents: mission statement (requirements §1), what-it-is/for-whom/how,
     tree map (requirements §5 style, no counts), quick start (installer one-liner
     preserved verbatim + D5 trust-model note + integrity-conscious alternative),
     link to `CATALOG.md` for all tables, governance pointers (reorg charter,
     requirements, plan, CONTRIBUTING if it exists), conventions digest.
  2. Remove all hand-maintained tables and counts from README.
  3. Project `CLAUDE.md`: replace the directory-tree annotation counts ("15 agent
     instructions", "25 global slash commands") with a `CATALOG.md` pointer. (The
     90/90/5 figures are in the user-global CLAUDE.md — out of scope, OQ3.)
  4. Orientation test: dispatch a fresh-context reviewer subagent that reads ONLY the
     new README and must correctly answer, verbatim: (a) "What is this repo?"
     (b) "What does it contain?" (c) "How do I install a skill into a project?"
     (d) "Where is the full asset list?" Pass = all four answered correctly per the
     requirements doc; on failure, one revision pass, then escalate to erik.
- **Acceptance criteria:** length caps met; mission stated; orientation test passed
  (evidence: reviewer transcript summary in PR body); zero numeric asset counts remain
  in README or project CLAUDE.md; installer one-liner byte-identical to current; PR
  body flags the deletion-heavy overage (~600 lines) for sign-off.
- **References:** requirements §1, §2 G1, §8.1/§8.5, D2, D5; `CATALOG.md` (from T6);
  project `CLAUDE.md`.

### T8 — Local validation gate *(P2 approved as modified: local, not GitHub Actions)*
- [x] **Status:** done — PR #70
- **Agent / model:** general-purpose / sonnet
- **Description:** Local pre-PR validation replacing the original GitHub Actions
  proposal — erik wants reduced reliance on GitHub Actions.
- **Work plan:**
  1. Implement `scripts/validate.ps1`: regenerate `CATALOG.md` from the *committed*
     manifest, fail on `git diff --exit-code` (catalog staleness gate); manifest
     staleness via `audit.ps1`'s timestamp-excluded freshness check — never a raw
     git diff of a regenerated manifest (the `generated` date field would
     false-positive daily); run `audit.ps1` (propagate exit 1/2); summary table +
     `-Json` flag. Honors requirements §6 shared conventions.
  2. Implement `scripts/install-hooks.ps1`: opt-in installer that sets repo-local
     `core.hooksPath` to a committed `scripts/git-hooks/` directory containing a
     `pre-push` hook that runs `validate.ps1`. Document interaction with erik's
     global git-push-opens-Zed PreToolUse hook (charter §7 precedent) — the git hook
     runs regardless of which client pushes.
  3. Add a rule to the repo `CLAUDE.md`: `/ship` must run `scripts/validate.ps1`
     before opening any PR and abort on failure.
  4. Record the hosted-CI mirror of this gate as backlog (do not implement).
- **Acceptance criteria:** `validate.ps1` exits 0 on a clean repo, 1 on a seeded
  stale catalog and on a seeded audit error (evidence in PR body); hook installer is
  opt-in and idempotent; `CLAUDE.md` rule present; runtime <60s locally.
- **References:** requirements §7 P2 (as modified), D3, §6; T4/T6 scripts; charter §6,
  §7 (hook interactions).

### T9 — `CONTRIBUTING.md` *(P4 approved)*
- [ ] **Status:** todo
- **Agent / model:** general-purpose / sonnet
- **Description:** Codify contribution rules (P4 scope).
- **Work plan:**
  1. Sections, in order: (a) add a skill — frontmatter schema incl. `category:`,
     bundle layout, regeneration duties (manifest + catalog), diagram expectations;
     (b) add a vendor — top-level dir + README + manifest support; (c) add a shared
     asset class — README-first rule, D1 vendor-neutral test; (d) governance — reorg
     charter precedence for anything touching skill structure, git workflow digest
     (branch naming, PR limits, `/ship`).
  2. Source material: requirements §4–§7, charter §§2/5/6, `scripts/README.md`,
     `~/.claude/rules/git-workflow.md`.
  3. Link it from the root README (one line, T7's governance-pointers section already
     reserves the slot).
- **Acceptance criteria:** covers all four flows; consistent with charter,
  requirements, scripts/README; linked from root README; ≤120 lines.
- **References:** requirements §7 P4; charter §§2, 5, 6; `~/.claude/rules/git-workflow.md`.

---

## Verification protocol (orchestrator)

After each task's subagent reports done: (1) run its acceptance-criteria checks
mechanically (grep/diff/execution, not trust); (2) run `audit.ps1` once it exists;
(3) confirm PR size + description format; (4) only then flip the checkbox and record
the PR number next to it. Any acceptance failure → same subagent gets one fix pass,
then escalate to erik.

## Backlog (recorded, not scheduled)

- **P3 execution** — CHANGELOG-per-release + published SHA256 for `install-skills.ps1`
  belong to the `/release` flow (github skill, reorg-governed). Coordinate with the
  github bundle rather than tasking it here; T3's `scripts/README.md` documents the
  SHA256 verification step for consumers once releases carry it.
- Hosted-CI mirror of the T8 local validation gate (P2 as modified).
- OQ1 asset-first layout study (post reorg iteration 26).
- OQ2 Python ports of all PowerShell lifecycle scripts (contract = requirements §6
  shared conventions).
- OQ3 fleet-wide stale-count sweep (reorg iteration 10 vehicle).
- OQ4 instructions mirror-policy ruling.
- Implement `install-to-project.ps1` / `push-to-profile.ps1` / `sync-installed.ps1`
  bodies (stubs → real) once skills-manager command flows are ready to delegate to them.
