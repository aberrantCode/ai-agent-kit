---
title: Canonical Repo Restructure — Requirements
date: 2026-07-13
status: approved — erik, 2026-07-13 (3 review-committee rounds; P1–P5 decided)
owner: erik
depends-on: docs/reorg/charter.md (binding for all skill-structure decisions)
plan: docs/plans/canonical-repo-plan.md
---

# Canonical Repo Restructure — Requirements

## 1. Mission

Make `ai-agent-kit` the canonical, vendor-agnostic source of truth for all of erik's
AI-agent assets — skills, commands, reusable prompts, agent instructions, workflows,
configurations, and plugin/addon references — across Claude Code, OpenAI Codex CLI,
Google Gemini CLI, and any future vendor, framework, or product.

## 2. Goals

- **G1 — Orientation.** A new reader understands what this repo is, what it contains,
  how to use it, and where the full asset list lives within 2 minutes of opening the
  root `README.md` (operationalized in plan T7).
- **G2 — Structure serves the mission.** The tree makes asset discovery obvious,
  separates vendor-specific from vendor-neutral assets, and absorbs **new asset
  classes** without restructuring. (New *vendors* still add a top-level directory +
  manifest wiring under the D1 hybrid model; removing that cost is OQ1's scope.)
- **G3 — Deterministic automation.** `scripts/` enumerates all deployment, installation,
  overlay, and integration automation as real scripts (implemented or documented stubs),
  so the lifecycle no longer depends solely on LLM-driven slash commands.
- **G4 — Self-describing folders.** Every root-level folder — and any subfolder whose
  purpose is non-obvious — carries a `README.md` prescribing purpose, contents, and
  conventions.
- **G5 — Single-sourced facts.** Counts, category assignments, and catalog tables are
  generated from one machine-readable source; no hand-edited number appears twice.
  *Enforcement caveat:* until T8's local validation gate (P2 as modified) ships, G5
  is soft-enforced by manually running `audit.ps1`.

## 3. Non-goals

- **N1 — No skill-tree restructuring.** Bundle composition, absorptions, deletions,
  renames, and dispositions belong exclusively to the master-skills reorg
  (`docs/reorg/charter.md`, disposition ledger, 27-iteration tracker). This effort
  changes the *container* around the skill trees, never the skill trees themselves.
  Skill counts on disk change as reorg iterations ship; therefore nothing in this
  effort may hardcode a skill count.
- **N2 — No mass file moves without sign-off.** The only content move in scope is
  `claude/prompts/` → `shared/prompts/` (3 files, referenced nowhere outside this
  effort's own docs), which erik approved in the 2026-07-13 interview.
- **N3 — No cross-CLI transpiler revival.** Charter §5 cut it; mirrors remain on-demand.
- **N4 — No new runtime behavior for installed skills.** Nothing here changes how a
  deployed skill behaves in a consuming project.

## 4. Resolved decisions (erik interview, 2026-07-13 — binding for this effort)

| # | Decision |
|---|---|
| D1 | **Vendor model: hybrid.** Vendor-first layout stays (`claude/` is the canonical authoring surface; `codex/`, `gemini/` are stamped mirrors per charter §5). A new `shared/` tree holds vendor-neutral assets. **Vendor-neutral test:** an asset qualifies for `shared/` only if it contains no vendor-specific frontmatter contract, tool syntax, or install-path convention — plain markdown/config any vendor's agent can consume. Full asset-first restructure is OQ1 (post reorg iteration 26). |
| D2 | **README: short + generated catalog.** Root `README.md` becomes a mission/orientation doc. The full skill/instruction/command tables move to a generated `CATALOG.md`; no hand-edited counts anywhere. |
| D3 | **Scripts: PowerShell 7 now; audit implemented.** New scripts declare `#Requires -Version 7.0` and must be **cross-platform** (no Windows-isms — keeps the OQ2 Python port and the backlog hosted-CI mirror cheap, even though the P2 gate runs locally). `install-skills.ps1`'s 5.1 floor is an intentional grandfathered exception (remote-bootstrap constraint). `audit.ps1` is fully implemented in this effort; install/push/sync are documented stubs. **Backlog:** migrate scripts to Python (OQ2). |
| D4 | **PR sequencing: docs first.** PR 1 carries this document plus the plan. Implementation follows in subsequent PRs sized under the 800-line hard limit (see plan §PR map). |
| D5 | **`install-skills.ps1` stays at repo root.** Its raw-GitHub URL is a published contract (`irm .../main/install-skills.ps1 | iex`). Documentation of this contract MUST state the trust model in plain language (piping `main` HEAD to `iex` executes whatever is on `main` as the invoking user) and MUST offer an integrity-conscious alternative: clone-and-inspect, or fetching by commit SHA / release tag with a published SHA256 per release (P3). |
| D6 | **`claude/prompts/` moves to `shared/prompts/`.** First occupant of `shared/`. |
| D7 | **Future asset classes get directories now.** `shared/workflows/`, `shared/configs/`, `shared/plugins/` are created containing only a README each, reserving the namespace and making the mission legible in the tree. |
| D8 | **Category source of truth: frontmatter.** Each `SKILL.md` gains a `category:` frontmatter field; `generate-manifest.py` reads it; `CATALOG.md` is generated from `manifest.json`. Requires a one-time scripted backfill across all Claude skills (mirrors inherit from their source skill). |

## 5. Target structure

Counts are deliberately absent — they live in `CATALOG.md`/`manifest.json` (G5, N1).

```
ai-agent-kit/
├── README.md               # mission + orientation (short; no counts, no tables)
├── CATALOG.md              # GENERATED — full asset tables, from manifest.json
├── CHANGELOG.md
├── CONTRIBUTING.md         # proposed (P4)
├── manifest.json           # GENERATED — machine-readable source of truth
├── install-skills.ps1      # root placement = published-URL contract (D5)
├── claude/                 # canonical authoring surface        [README]
│   ├── skills/             #   skill bundles (reorg-governed — see CATALOG.md)
│   ├── instructions/       #   agent instructions
│   └── commands/           #   global slash commands
├── codex/                  # on-demand mirror (charter §5)      [README]
│   ├── skills/
│   └── instructions/       #   mirror policy TBD — OQ4
├── gemini/                 # frozen mirror (charter §5)         [README]
│   ├── skills/
│   └── instructions/       #   mirror policy TBD — OQ4
├── shared/                 # vendor-neutral assets (D1 test)    [README]
│   ├── prompts/            #   reusable prompts (from claude/prompts/) [README]
│   ├── workflows/          #   vendor-neutral orchestration documents  [README]
│   ├── configs/            #   reusable config fragments — no secrets  [README]
│   └── plugins/            #   plugin/addon reference list + provenance [README]
├── scripts/                # all lifecycle automation           [README]
│   ├── generate-manifest.py    # existing (gains --output, --validate, category support)
│   ├── generate-catalog.ps1    # stub → implemented (D2/D8)
│   ├── audit.ps1               # IMPLEMENTED (D3)
│   ├── install-to-project.ps1  # stub
│   ├── push-to-profile.ps1     # stub
│   ├── sync-installed.ps1      # stub
│   ├── backfill-categories.ps1 # stub → one-time sweep (D8)
│   ├── validate.ps1            # local validation gate (P2) — T8
│   └── install-hooks.ps1       # opt-in pre-push hook installer (P2) — T8
├── docs/                   # requirements, plans, reorg governance, reports [README]
└── logs/                   # UNTRACKED local telemetry (P5) — gitignored, no README
```

Folder-README coverage rule (G4): every root-level directory gets a `README.md`. Vendor
READMEs describe their own `skills/` / `instructions/` / `commands/` subtrees (purposes
are non-obvious to newcomers); `shared/` gets one README per asset class because each
class has distinct conventions; `docs/README.md` maps `requirements/`, `plans/`,
`reorg/`, `reports/`.

Class boundary (charter-style): **a shared workflow is a vendor-neutral orchestration
*document* a human or agent follows; anything that installs and triggers as a skill
belongs in a vendor skill tree.** `shared/plugins/` is a pure reference list (each entry
carries provenance + vetting status); ownership of plugin-precedence *declarations*
remains with skills-manager `external-skill-intake` per charter §4 once that sub-skill
ships — until then `shared/plugins/README.md` makes no ownership claims.

## 6. Script requirements (G3)

Stub definition (binding): file exists; comment-based help documents **purpose,
parameters, exit codes, and intended behavior**; body is `throw "TODO: not implemented"`
so accidental execution fails loudly (exit ≠ 0).

**Shared conventions (all lifecycle scripts):**

| Convention | Requirement |
|---|---|
| Parameters | Common surface: `-Name <skill>`, `-TargetDir <path>`, `-Force`, `-WhatIf`, `-Json`. Scripts add specifics but never repurpose these. |
| Exit codes | `0` success / clean; `1` findings or validation failure; `2` execution error. `audit.ps1` refinement: exit `1` only on **error-severity** findings — warnings alone exit `0` (keeps CI usable before the T5 backfill lands). |
| Safety | Mutating scripts default to preview (`-WhatIf` semantics or report-only) and require explicit `-Force`/`-Apply` to write. Before overwriting an existing file: back it up or refuse (no silent clobber). All target paths are canonicalized and containment-checked against the intended root (no path traversal via crafted names). |
| Subprocess | Calls to `python` use an explicit interpreter + argument array (no shell string interpolation) and a bounded temp location. |
| Portability | `#Requires -Version 7.0`; no Windows-only APIs; output encoding `utf8NoBOM`; ordinal (culture-invariant) sorting. |

| Script | State after this effort | Contract summary |
|---|---|---|
| `audit.ps1` | **implemented** | Read-only archive health check. Checks (severity in brackets): `SKILL.md` present with valid frontmatter, `name` matching directory [error]; missing `category:` [warn while the generator reports `categorySource: legacy-dict`, error once it reports `frontmatter` — an explicit marker, never a coverage heuristic]; `installed-from:` present inside the archive [error]; secret-shaped content (API keys, tokens, connection strings) anywhere under `shared/` [error]; manifest freshness via `generate-manifest.py --output <temp>` + diff **excluding the volatile `generated` timestamp field** (raw diff would false-positive on day rollover) [error]; CATALOG parity both directions, if `CATALOG.md` exists [error]; Claude↔Codex mirror gap [info — charter §5]; missing `diagram.html` [info]. Frontmatter parsing is delegated to `generate-manifest.py --validate --json` — one parser, two consumers. Console table + `-Json` output. |
| `install-to-project.ps1` | stub | Copy a named skill bundle (SKILL.md + sub-skills/ + commands/ + references/ + rules/) into a target project's `.claude/`, stamping `installed-from: ai-agent-kit`. Honors shared safety conventions. |
| `push-to-profile.ps1` | stub | Deploy a bundle to `~/.claude/skills/` (or vendor equivalent), stamping provenance. Honors shared safety conventions. |
| `sync-installed.ps1` | stub | Scan a project (or fleet root) for stamped installed copies; diff against archive; **report-only by default**, `-Apply` writes with backup-before-overwrite. |
| `generate-catalog.ps1` | stub → implemented in plan | Render `CATALOG.md` from `manifest.json`. Byte-stable output (ordinal sort, `utf8NoBOM`, LF via `.gitattributes`) so CI can diff. |
| `backfill-categories.ps1` | stub → run once in plan | Inject `category:` frontmatter into each Claude `SKILL.md`; **skips any file with a non-empty `category:` already set** (protects hand assignments); `-WhatIf` preview by default, explicit apply; reports unresolvable skills for human assignment. |
| `generate-manifest.py` | modified in plan | Gains `--output PATH` (default: repo-root `manifest.json`), `--validate --json` (emit parsed frontmatter + validation results for audit.ps1, including a `categorySource: legacy-dict\|frontmatter` marker), and `category:` frontmatter support replacing the hardcoded skill→category dict. The **category display order** remains an explicit ordered list retained in the generator (curated order, not alphabetical) after the dict is deleted; `manifest.json`'s `categories` array is populated from it. |

Charter rule 6 alignment: every reorg deletion PR must regenerate `manifest.json` and
maintain README parity — `audit.ps1` is the mechanical check for exactly that, and must
therefore stay runnable at every reorg iteration (no assumptions about skill count or
bundle shape).

## 7. Proposals — decided by erik, 2026-07-13

- **P1 — Manifest strategy. APPROVED.** `manifest.json` is the single machine-readable
  SoT, generated from frontmatter (never hand-edited). `CATALOG.md` and any counts
  derive from it. Manifest gains a `schemaVersion` field and a documented shape in
  `scripts/README.md`. Implemented within T5.
- **P2 — Validation gate. APPROVED AS MODIFIED: local, not GitHub Actions.** erik
  wants to reduce reliance on GitHub Actions; validation runs locally before/during
  PR instead. Mechanism: `scripts/validate.ps1` — a wrapper that regenerates
  `CATALOG.md` from the *committed* manifest and fails on `git diff --exit-code`
  (catalog staleness gate), checks manifest staleness via `audit.ps1`'s
  timestamp-excluded freshness check (never a raw diff of a regenerated manifest —
  the `generated` date field would false-positive daily), and runs `audit.ps1`
  (fail on exit 1/2). Wiring: (a) an opt-in git `pre-push` hook installed by
  `scripts/install-hooks.ps1` (repo-local `core.hooksPath`), and (b) a repo
  `CLAUDE.md` rule that `/ship` runs `scripts/validate.ps1` before opening any PR.
  Mirror gaps stay informational (charter §5). A hosted CI mirror of the same gate is
  recorded as backlog, not scheduled. Implemented by T8.
- **P3 — Versioning. APPROVED.** Repo-level: continue tagged releases (`release:` flow) with
  CHANGELOG.md maintained per release (currently stale — last real entry May 20).
  Publish a SHA256 for `install-skills.ps1` with each release (D5 integrity
  alternative). Asset-level: keep optional `version:` frontmatter; mirrors carry the
  charter-mandated source-version stamp. No per-asset semver enforcement.
- **P4 — Contribution rules. APPROVED.** `CONTRIBUTING.md` covering: how to add a skill
  (frontmatter schema incl. `category:`, bundle layout, parity via regeneration,
  diagram expectations), how to add a new vendor (top-level dir + README + manifest
  support), how to add a shared asset class, and the reorg-charter precedence rule for
  anything touching skill structure.
- **P5 — `logs/` policy. DECIDED: untrack entirely.** `logs/` is removed from git
  tracking (`git rm -r --cached logs/`) and gitignored; timing telemetry stays local
  only. No `logs/README.md` is required (G4 applies to tracked folders). Executed in
  T2.

## 8. Acceptance criteria (merged: mission + interview)

1. Root `README.md` states the mission verbatim-equivalent and passes the T7
   orientation test (plan T7 defines the mechanical test: length cap + four verbatim
   newcomer questions answered by a fresh-context reviewer).
2. `shared/` exists with `prompts/` (populated), `workflows/`, `configs/`, `plugins/`
   (README-only), each with conventions documented, including the §5 class-boundary
   sentence and the D1 vendor-neutral test.
3. `scripts/` contains the scripts of §6 in their specified states, plus
   `scripts/README.md` enumerating them (with an implemented-vs-stub status column kept
   current by every task that flips a stub) and the root-installer URL + trust-model
   contract.
4. Every tracked root-level folder has a README (`logs/` exempt — untracked per P5);
   vendor and shared subfolders covered per §5's coverage rule.
5. `CATALOG.md` generated; README contains no asset tables or hand-maintained counts;
   the project `CLAUDE.md` directory-tree annotations drop absolute counts in favor of
   a `CATALOG.md` pointer. (The stale 90/90/5 figures live in the **user-global**
   CLAUDE.md — out of repo scope, tracked as OQ3.)
6. No skill directory is moved, renamed, or deleted by this effort (N1) — verified by
   `git diff --stat` showing no changes under `*/skills/` except frontmatter
   `category:` additions (D8).
7. All PRs conform to the git workflow (feature branch off `dev`, PR back to `dev`,
   ≤800 changed lines — generated-file and deletion-heavy exceptions require explicit
   sign-off in the PR description).
8. Proposals P1–P5 are decided (recorded in §7, erik 2026-07-13): P1/P3/P4 approved,
   P2 approved as modified (local gate), P5 resolved (untrack).

## 9. Open questions

- **OQ1 — Asset-first layout.** Revisit `skills/<name>/{vendor}/` after reorg
  iteration 26 closes; that is also when G2's vendor-addition cost is addressed.
  Recorded, not scheduled.
- **OQ2 — Python migration.** Port PowerShell lifecycle scripts to Python for
  cross-platform parity once contracts stabilize. The §6 shared conventions (parameter
  surface, exit codes, safety semantics) are the portable contract the port must honor.
- **OQ3 — Count references outside this repo.** User-global `CLAUDE.md` and other
  fleet docs carry stale counts (90/90/5). Out of repo scope; fix opportunistically in
  the next fleet sweep (reorg iteration 10).
- **OQ4 — Codex/Gemini instructions.** Both vendors have 3 instructions each,
  undocumented in any count table. Catalog generation must include them; the mirror
  policy for instructions needs a charter-consistent ruling. Until ruled, vendor
  READMEs state "instructions mirror policy: TBD (OQ4)" rather than inventing one.
