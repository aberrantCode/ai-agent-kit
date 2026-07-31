---
title: Canonical Repo Restructure — Requirements
date: 2026-07-13
status: approved — erik, 2026-07-13 (3 review-committee rounds; P1–P5 decided)
amended: 2026-07-22 — push-to-profile.ps1 nested-layout requirement clarified after an archive audit found profile-installed bundles could ship with sub-skills placed loose instead of nested (informally tracked as F-KO-05)
owner: erik
depends-on: docs/reorg/charter.md (binding for all skill-structure decisions)
plan: docs/plans/canonical-repo-plan.md
---

# Canonical Repo Restructure — Requirements

> **Status:** Satisfied / as-built. Every decision below has been implemented; the
> execution record — task-by-task status, what shipped in which PR — lives in
> [`../plans/canonical-repo-plan.md`](../plans/canonical-repo-plan.md). This document
> remains the definitions home for the G/N/D/P/OQ codes that the plan and other repo
> docs cite.
>
> **Amended 2026-07-22:** the `push-to-profile.ps1` contract in
> [Script requirements](#script-requirements) was tightened after an archive audit
> found that profile-installed skill bundles could ship with sub-skills placed loose
> at the profile's top level instead of nested under their parent bundle — the
> profile-bundle-missing-sub-skills bug (an audit finding; not a linkable report on
> this branch). The row below now states the nested-layout requirement explicitly.

## Mission

Make `ai-agent-kit` the canonical, vendor-agnostic source of truth for all of erik's
AI-agent assets — skills, commands, reusable prompts, agent instructions, workflows,
configurations, and plugin/addon references — across Claude Code, OpenAI Codex CLI,
Google Gemini CLI, and any future vendor, framework, or product.

## Goals

- **G1 — Orientation.** A new reader understands what this repo is, what it contains,
  how to use it, and where the full asset list lives within 2 minutes of opening the
  root `README.md` (operationalized in the [plan](../plans/canonical-repo-plan.md),
  task T7).
- **G2 — Structure serves the mission.** The tree makes asset discovery obvious,
  separates vendor-specific from vendor-neutral assets, and absorbs **new asset
  classes** without restructuring. (New *vendors* still add a top-level directory +
  manifest wiring under the [D1](#resolved-decisions) hybrid model; removing that
  cost is [OQ1](#open-questions)'s scope.)
- **G3 — Deterministic automation.** [`scripts/`](../../scripts/) enumerates all
  deployment, installation, overlay, and integration automation as real scripts
  (implemented or documented stubs), so the lifecycle no longer depends solely on
  LLM-driven slash commands.
- **G4 — Self-describing folders.** Every root-level folder — and any subfolder whose
  purpose is non-obvious — carries a `README.md` prescribing purpose, contents, and
  conventions.
- **G5 — Single-sourced facts.** Counts, category assignments, and catalog tables are
  generated from one machine-readable source; no hand-edited number appears twice.
  *Enforcement caveat:* until the plan's T8 local validation gate
  ([P2](#proposals) as modified) ships, G5 is soft-enforced by manually running
  [`audit.ps1`](../../scripts/audit.ps1).

## Non-goals

- **N1 — No skill-tree restructuring.** Bundle composition, absorptions, deletions,
  renames, and dispositions belong exclusively to the master-skills reorg
  ([`../reorg/charter.md`](../reorg/charter.md), [disposition
  ledger](../reorg/disposition-ledger.md), 27-iteration tracker). This effort
  changes the *container* around the skill trees, never the skill trees themselves.
  Skill counts on disk change as reorg iterations ship; therefore nothing in this
  effort may hardcode a skill count.
- **N2 — No mass file moves without sign-off.** The only content move in scope is
  `claude/prompts/` → `shared/prompts/` (3 files, referenced nowhere outside this
  effort's own docs), which erik approved in the 2026-07-13 interview.
- **N3 — No cross-CLI transpiler revival.** [Charter](../reorg/charter.md) §5 cut it;
  mirrors remain on-demand.
- **N4 — No new runtime behavior for installed skills.** Nothing here changes how a
  deployed skill behaves in a consuming project.

## Resolved decisions

Decided in erik's interview, 2026-07-13 — binding for this effort.

| # | Decision |
|---|---|
| D1 | **Vendor model: hybrid.** Vendor-first layout stays (`claude/` is the canonical authoring surface; `codex/`, `gemini/` are stamped mirrors per [charter](../reorg/charter.md) §5). A new `shared/` tree holds vendor-neutral assets. **Vendor-neutral test:** an asset qualifies for `shared/` only if it contains no vendor-specific frontmatter contract, tool syntax, or install-path convention — plain markdown/config any vendor's agent can consume. Full asset-first restructure is [OQ1](#open-questions) (post reorg iteration 26). |
| D2 | **README: short + generated catalog.** Root `README.md` becomes a mission/orientation doc. The full skill/instruction/command tables move to a generated `CATALOG.md`; no hand-edited counts anywhere. |
| D3 | **Scripts: PowerShell 7 now; audit implemented.** New scripts declare `#Requires -Version 7.0` and must be **cross-platform** (no Windows-isms — keeps the [OQ2](#open-questions) Python port and the backlog hosted-CI mirror cheap, even though the [P2](#proposals) gate runs locally). `install-skills.ps1`'s 5.1 floor is an intentional grandfathered exception (remote-bootstrap constraint). `audit.ps1` is fully implemented in this effort; install/push/sync are documented stubs. **Backlog:** migrate scripts to Python ([OQ2](#open-questions)). |
| D4 | **PR sequencing: docs first.** PR 1 carries this document plus the plan. Implementation follows in subsequent PRs sized under the 800-line hard limit (see the [plan](../plans/canonical-repo-plan.md)'s PR map). |
| D5 | **`install-skills.ps1` stays at repo root.** Its raw-GitHub URL is a published contract (`irm .../main/install-skills.ps1 | iex`). Documentation of this contract MUST state the trust model in plain language (piping `main` HEAD to `iex` executes whatever is on `main` as the invoking user) and MUST offer an integrity-conscious alternative: clone-and-inspect, or fetching by commit SHA / release tag with a published SHA256 per release ([P3](#proposals)). |
| D6 | **`claude/prompts/` moves to `shared/prompts/`.** First occupant of `shared/`. |
| D7 | **Future asset classes get directories now.** `shared/workflows/`, `shared/configs/`, `shared/plugins/` are created containing only a README each, reserving the namespace and making the mission legible in the tree. |
| D8 | **Category source of truth: frontmatter.** Each `SKILL.md` gains a `category:` frontmatter field; `generate-manifest.py` reads it; `CATALOG.md` is generated from `manifest.json`. Requires a one-time scripted backfill across all Claude skills (mirrors inherit from their source skill). |

## Target structure

Counts are deliberately absent — they live in `CATALOG.md`/`manifest.json`
([G5](#goals), [N1](#non-goals)).

> **▣ Diagram —** target repo file-tree with per-directory annotations *(type: tree)* — [view](diagrams/target-repo-tree.html)

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
│   ├── push-to-profile.ps1     # stub → implemented
│   ├── sync-installed.ps1      # stub
│   ├── backfill-categories.ps1 # stub → one-time sweep (D8)
│   ├── validate.ps1            # local validation gate (P2) — T8
│   └── install-hooks.ps1       # opt-in pre-push hook installer (P2) — T8
├── docs/                   # requirements, plans, reorg governance, reports [README]
└── logs/                   # UNTRACKED local telemetry (P5) — gitignored, no README
```

*(Legend for the inline codes above: `D`-prefixed → [Resolved decisions](#resolved-decisions);
`G`/`N`-prefixed → [Goals](#goals)/[Non-goals](#non-goals); `P`-prefixed →
[Proposals](#proposals); `OQ`-prefixed → [Open questions](#open-questions).)*

Full contracts for the scripts named in the tree above — parameters, exit codes,
implementation state — are documented once in [Script requirements](#script-requirements);
this tree only names each file and is not a second copy of that detail.

Folder-README coverage rule ([G4](#goals)): every root-level directory gets a
`README.md`. Vendor READMEs describe their own `skills/` / `instructions/` /
`commands/` subtrees (purposes are non-obvious to newcomers); `shared/` gets one
README per asset class because each class has distinct conventions;
`docs/README.md` maps `requirements/`, `plans/`, `reorg/`, `reports/`.

Class boundary (charter-style): **a shared workflow is a vendor-neutral orchestration
*document* a human or agent follows; anything that installs and triggers as a skill
belongs in a vendor skill tree.** `shared/plugins/` is a pure reference list (each entry
carries provenance + vetting status); ownership of plugin-precedence *declarations*
remains with skills-manager `external-skill-intake` per [charter](../reorg/charter.md)
§4 once that sub-skill ships — until then `shared/plugins/README.md` makes no
ownership claims.

## Script requirements

Operationalizes [G3](#goals) (deterministic automation). See also the `scripts/`
listing in [Target structure](#target-structure) — this section is the single place
the per-script contracts live.

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
| [`audit.ps1`](../../scripts/audit.ps1) | **implemented** | Read-only archive health check. Checks (severity in brackets): `SKILL.md` present with valid frontmatter, `name` matching directory [error]; missing `category:` [warn while the generator reports `categorySource: legacy-dict`, error once it reports `frontmatter` — an explicit marker, never a coverage heuristic]; `installed-from:` present inside the archive [error]; secret-shaped content (API keys, tokens, connection strings) anywhere under `shared/` [error]; manifest freshness via `generate-manifest.py --output <temp>` + diff **excluding the volatile `generated` timestamp field** (raw diff would false-positive on day rollover) [error]; CATALOG parity both directions, if `CATALOG.md` exists [error]; Claude↔Codex mirror gap [info — [charter](../reorg/charter.md) §5]; missing `diagram.html` [info]. Frontmatter parsing is delegated to `generate-manifest.py --validate --json` — one parser, two consumers. Console table + `-Json` output. |
| [`install-to-project.ps1`](../../scripts/install-to-project.ps1) | stub | Copy a named skill bundle (SKILL.md + sub-skills/ + commands/ + references/ + rules/) into a target project's `.claude/`, stamping `installed-from: ai-agent-kit`. Honors shared safety conventions. |
| [`push-to-profile.ps1`](../../scripts/push-to-profile.ps1) | **implemented** | Deploy a bundle to `~/.claude/skills/` (or vendor equivalent), stamping provenance. **Nested** layout (sub-skills stay under the bundle — never loose top-level, `audit.ps1` Check 8; fixes the profile-bundle-missing-sub-skills bug found in the 2026-07-22 archive audit, informally tracked as F-KO-05 — see the "Amended" note above); parent + each sub-skill `SKILL.md` stamped `installed-from: ai-agent-kit`; companion commands relocated to the profile's top-level `commands/`; `status: draft` skipped. Honors shared safety conventions (preview default, `-Force` writes with backup-to-sibling-`-backups`, containment-checked paths). |
| [`sync-installed.ps1`](../../scripts/sync-installed.ps1) | stub | Scan a project (or fleet root) for stamped installed copies; diff against archive; **report-only by default**, `-Apply` writes with backup-before-overwrite. |
| [`generate-catalog.ps1`](../../scripts/generate-catalog.ps1) | stub → implemented in plan | Render `CATALOG.md` from `manifest.json`. Byte-stable output (ordinal sort, `utf8NoBOM`, LF via `.gitattributes`) so CI can diff. |
| [`backfill-categories.ps1`](../../scripts/backfill-categories.ps1) | stub → run once in plan | Inject `category:` frontmatter into each Claude `SKILL.md`; **skips any file with a non-empty `category:` already set** (protects hand assignments); `-WhatIf` preview by default, explicit apply; reports unresolvable skills for human assignment. |
| [`generate-manifest.py`](../../scripts/generate-manifest.py) | modified in plan | Gains `--output PATH` (default: repo-root `manifest.json`), `--validate --json` (emit parsed frontmatter + validation results for audit.ps1, including a `categorySource: legacy-dict\|frontmatter` marker), and `category:` frontmatter support replacing the hardcoded skill→category dict. The **category display order** remains an explicit ordered list retained in the generator (curated order, not alphabetical) after the dict is deleted; `manifest.json`'s `categories` array is populated from it. |

[Charter](../reorg/charter.md) rule 6 alignment: every reorg deletion PR must
regenerate `manifest.json` and maintain README parity — `audit.ps1` is the
mechanical check for exactly that, and must therefore stay runnable at every reorg
iteration (no assumptions about skill count or bundle shape).

## Proposals

Decided by erik, 2026-07-13. **Naming note:** the P1–P5 codes below are this
document's own proposal numbers — a different scheme from the reorg
[charter](../reorg/charter.md)'s P0–P3 *phase* codes. Same letter, unrelated
numbering and scope; don't conflate a "P2" here with a charter phase.

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
  Mirror gaps stay informational ([charter](../reorg/charter.md) §5). A hosted CI
  mirror of the same gate is recorded as backlog, not scheduled. Implemented by T8.
- **P3 — Versioning. APPROVED.** Repo-level: continue tagged releases (`release:` flow) with
  CHANGELOG.md maintained per release (currently stale — last real entry May 20).
  Publish a SHA256 for `install-skills.ps1` with each release
  ([D5](#resolved-decisions) integrity alternative). Asset-level: keep optional
  `version:` frontmatter; mirrors carry the charter-mandated source-version stamp.
  No per-asset semver enforcement.
- **P4 — Contribution rules. APPROVED.** `CONTRIBUTING.md` covering: how to add a skill
  (frontmatter schema incl. `category:`, bundle layout, parity via regeneration,
  diagram expectations), how to add a new vendor (top-level dir + README + manifest
  support), how to add a shared asset class, and the [reorg-charter](../reorg/charter.md)
  precedence rule for anything touching skill structure.
- **P5 — `logs/` policy. DECIDED: untrack entirely.** `logs/` is removed from git
  tracking (`git rm -r --cached logs/`) and gitignored; timing telemetry stays local
  only. No `logs/README.md` is required ([G4](#goals) applies to tracked folders).
  Executed in T2.

## Acceptance criteria (merged: mission + interview)

1. Root `README.md` states the mission verbatim-equivalent and passes the T7
   orientation test (the [plan](../plans/canonical-repo-plan.md)'s T7 defines the
   mechanical test: length cap + four verbatim newcomer questions answered by a
   fresh-context reviewer).
2. `shared/` exists with `prompts/` (populated), `workflows/`, `configs/`, `plugins/`
   (README-only), each with conventions documented, including the [Target
   structure](#target-structure) class-boundary sentence and the
   [D1](#resolved-decisions) vendor-neutral test.
3. `scripts/` contains the scripts of [Script requirements](#script-requirements) in
   their specified states, plus `scripts/README.md` enumerating them (with an
   implemented-vs-stub status column kept current by every task that flips a stub)
   and the root-installer URL + trust-model contract.
4. Every tracked root-level folder has a README (`logs/` exempt — untracked per
   [P5](#proposals)); vendor and shared subfolders covered per [Target
   structure](#target-structure)'s coverage rule.
5. `CATALOG.md` generated; README contains no asset tables or hand-maintained counts;
   the project `CLAUDE.md` directory-tree annotations drop absolute counts in favor of
   a `CATALOG.md` pointer. (The stale 90/90/5 figures live in the **user-global**
   CLAUDE.md — out of repo scope, tracked as [OQ3](#open-questions).)
6. No skill directory is moved, renamed, or deleted by this effort ([N1](#non-goals)) —
   verified by `git diff --stat` showing no changes under `*/skills/` except
   frontmatter `category:` additions ([D8](#resolved-decisions)).
7. All PRs conform to the git workflow (feature branch off `dev`, PR back to `dev`,
   ≤800 changed lines — generated-file and deletion-heavy exceptions require explicit
   sign-off in the PR description).
8. The [Proposals](#proposals) (P1–P5) are decided (erik, 2026-07-13): P1/P3/P4
   approved, P2 approved as modified (local gate), P5 resolved (untrack).

## Open questions

- **OQ1 — Asset-first layout.** Revisit `skills/<name>/{vendor}/` after reorg
  iteration 26 closes; that is also when [G2](#goals)'s vendor-addition cost is
  addressed. Recorded, not scheduled.
- **OQ2 — Python migration.** Port PowerShell lifecycle scripts to Python for
  cross-platform parity once contracts stabilize. The [Script
  requirements](#script-requirements) shared conventions (parameter surface, exit
  codes, safety semantics) are the portable contract the port must honor.
- **OQ3 — Count references outside this repo.** User-global `CLAUDE.md` and other
  fleet docs carry stale counts (90/90/5). Out of repo scope; fix opportunistically in
  the next fleet sweep (reorg iteration 10).
- **OQ4 — Codex/Gemini instructions.** Both vendors have 3 instructions each,
  undocumented in any count table. Catalog generation must include them; the mirror
  policy for instructions needs a [charter](../reorg/charter.md)-consistent ruling.
  Until ruled, vendor READMEs state "instructions mirror policy: TBD (OQ4)" rather
  than inventing one.
