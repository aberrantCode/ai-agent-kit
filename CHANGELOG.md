# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

This file is generated from `git log` via `scripts/Generate-Changelog.ps1`.
Re-run after cutting a release tag to move the `[Unreleased]` section into its
proper version header.

## [Unreleased]

_No user-facing changes recorded._

## [0.9.0] - 2026-07-19

### Added

- assert every release tag has a changelog section (`d8b5231`)
- provision release automation and rebuild CHANGELOG (`46758ce`)
- add repo-init sub-skill and /init-repo command (`d8ac5b0`)
- add ai-agent-kit badge assets (dark+light) (`ef50bad`)
- standardize product intent on docs/REQUIREMENTS.md (INITIAL_PROMPT legacy) (`227d411`)
- retro + what-next backlog-awareness + reconciliation trim (build step 6) (`a00b530`)
- scaffold backlog + scope-manifest in init-project, adoption lift in reinit (build step 5) (`15bc1c2`)
- chore express lane — /pm-task + machine-enforced guard (build step 4) (`ae7a0d8`)
- add capture + groom intake/triage sub-skills (build step 3) (`79ac18b`)
- sync-status §4 backlog generation + BL-id uniqueness gate (build step 2) (`4bafcdf`)
- add PM backlog store + chore task templates (build step 1) (`36415d8`)
- local pre-PR validation gate — validate.ps1 + install-hooks.ps1 (T8) (`e6932f7`)
- consolidate category taxonomy — Infrastructure & Ops + Frontend (T5c) (`83edfc0`)
- implement generate-catalog.ps1 (T6) (`fa1f5a4`)
- backfill category frontmatter, drop hardcoded category dict (T5) (`0b1aa83`)
- implement audit.ps1 + generate-manifest.py --output/--validate flags (`3c9b313`)
- PowerShell 7 lifecycle script stubs + scripts/README.md (`89000c4`)
- shared/ vendor-neutral tree + prompts move (`632952a`)
- add release-init operation — Release-Automation Standard for the github skill (`1dc307d`)
- add ac-logo skill bundle — brand logo lifecycle with runtime AC_DESIGN resolution (`5a9f2b5`)
- add github skill bundle consolidating git/GitHub commands (`bbee4c5`)
- archive csv-driven-llm-pipeline skill (`909ff8c`)

### Changed

- make publish delegate all configuration to repo-init (`3f3e83a`)
- github pt1 — worktree-task-lifecycle sub-skill, absorb using-git-worktrees + worktree-isolated-loop (`830e8ef`)
- rationalization phase 1 — merge frontend-design, security, add-feature; refactor finishing-a-development-branch (`f70e77f`)
- rename github operations to thin verbs and remove superseded skills (`8f62e91`)

### Fixed

- pin UTF-8 decoding and skip scaffolding in changelog template (`23e856a`)
- repair /init-repo frontmatter YAML (`173eb39`)
- mark repo-init hook templates executable (`98d1ff1`)
- tolerate server-side branch auto-delete in merge cleanup (`f19050d`)
- skip validate.ps1 on deletion-only pushes (`9f1542a`)
- update stale skill-name and category references in skill bodies (`6600613`)
- align skill frontmatter name to directory (T5b) (`e7974c7`)
- copy references/ and rules/ on install, update, and push (`3f0907d`)
- copy rules/ bundle dirs so rule-library skills deploy (`672cd0c`)

### Documentation

- record P3 changelog execution as done (`b2cb83e`)
- fold dry-run findings into the repo-init standard (`d52f895`)
- register /init-repo, record /init as a built-in collision (`2ce6801`)
- add theme-aware badge masthead (`4f44c7c`)
- mark PM build step 7 done (PR #83) — all 7 steps complete (`c209559`)
- describe chore lane + intake across project-manager surfaces (build step 7) (`b1cd826`)
- mark PM build step 6 done (PR #82) in progress tracker (`3956f49`)
- mark PM build step 5 done (PR #81) in progress tracker (`984b063`)
- mark PM build step 4 done (PR #80) in progress tracker (`1db2bdf`)
- mark PM build step 3 done (PR #79) in progress tracker (`c14f402`)
- mark PM build step 2 done (PR #78) in progress tracker (`0250d8f`)
- mark PM build step 1 done (PR #77) in progress tracker (`536c3e6`)
- freeze chore authorization at promotion to close TOCTOU gap (Rev 5) (`44255f8`)
- enforce chore-lane scope boundary via scope-manifest (Rev 4) (`eebb804`)
- add PM lifecycle redesign proposal (Rev 3) (`d8ffea7`)
- flip T9 checkbox — PR #71 (`9380918`)
- add CONTRIBUTING.md (T9) (`7e20a7c`)
- flip T7 checkbox — PR #68 (`37d442a`)
- replace catalog-README with mission-first orientation doc (T7) (`f812d43`)
- flip T5c checkbox — PR #66 (`40479a8`)
- flip generate-catalog.ps1 status to implemented (T6) (`bcbc7d9`)
- flip T5b checkbox — PR #63 (`30ed664`)
- add T5b section to canonical-repo-plan (T5b) (`85f290c`)
- flip T5 checkbox — PR #62 (`94005be`)
- flip T4 checkbox — PR #61 (`ef6a0eb`)
- flip T3 checkbox — PR #59 (`784fe84`)
- flip T1/T2 checkboxes — PR #58 (`092c89a`)
- root-level and vendor folder READMEs; untrack logs/ (`0839b7d`)
- canonical-repo requirements + implementation plan (approved, 3 review rounds) (`7522b35`)
- add master-skills reorg phase-0 charter, disposition ledger, and command-namespace registry (iteration 0) (`df8bdf0`)
- record erik's resolutions of the five open master-skills reorg decisions (`3fb4fba`)
- add master-skills reorganization consensus plan (report + machine-readable consensus) (`9d5e87b`)
- add global skill consolidation analysis report (`ba400cd`)

### Internal

- mirror repo-init to codex, regenerate manifest and catalog (`62b7c11`)
- drop docs/git-log.md from the prune skill (`1487ee7`)
- generate CATALOG.md (T6) (`b93379b`)
- regenerate manifest.json (T5b) (`4094c5d`)
- fix audit findings — README parity, diagram backfill, codex github port (`a956ca0`)

## [0.8.0] - 2026-07-06

### Added

- add 36 conversation-history-mined skills (`bf47b96`)
- archive graphify and analyze-conversations (`7cbc431`)
- add honcho bundle, reconcile react-native, sync project-manager (`5d6db4b`)

### Internal

- bundle missing rules/ for composition-patterns and react-best-practices (`eea83ce`)
- rename repo from llm_skills to ai-agent-kit (`4951976`)

## [0.7.0] - 2026-05-25

### Added

- add /iterate-tasks for self-perpetuating subagent iteration (`99610c4`)
- add monorepo-aware runner detection for Verification Gate (`991f93a`)

### Fixed

- make reinit Step 3 report-by-default (`1aaa415`)

## [0.6.0] - 2026-05-20

### Added

- add /continue-new-session command for session handoff prompts (`a5621db`)
- add deterministic coordination helpers (`65a954a`)
- add init-project sub-skill and rationalize bundle (`9ae0abc`)
- Add 3 new skills to archive (content-aware-file-renaming, ac-opbta-ops, sops-secrets) (`fca175e`)
- Add repo-convention-aware superpowers skill overrides (`f1badaa`)
- Add intelligent project structure detection to grafana-dashboard-engineer (`21e7690`)
- Add markdown documentation generation to grafana-dashboard-engineer skill (`6a533ec`)
- Add grafana-dashboard-engineer skill to archive (`b22a21b`)
- archive 11 skills from global profile and projects (`e1729ba`)
- archive youtube-extraction skill bundle with 7 sub-skills (`997c629`)
- persist startup intelligence to docs/framework/start-app.md (`3f66a8c`)
- extract reusable eval harness + supporting diagrams (`50371dd`)
- add /what-next universal task-router skill (`3cbf42e`)

### Changed

- iter-2 improvements from eval feedback (`e0fea92`)
- manifest-driven installer with codex/gemini instructions (`53ee20f`)

### Documentation

- expand project-manager comparative plan (`36b2974`)
- add project-manager audit and plan (`ea19ac7`)
- add skills rationalization report with consolidation roadmap (`8856889`)

### Internal

- add dirty-tree guard, staging preview, and runner detection (`a99504a`)
- append ship-to-dev telemetry from skills-rationalization run (`f1e39c5`)

### Other

- Revert "Add repo-convention-aware superpowers skill overrides (#29)" (`fe7dd1c`)
- Add repo-convention-aware superpowers skill overrides (#29) (`d0e9db4`)
- Revert "Add markdown documentation and structure detection to grafana-dashboard-engineer (#28)" (`1637805`)
- Add markdown documentation and structure detection to grafana-dashboard-engineer (#28) (`86fbfbd`)
- Revert "Add markdown documentation generation to grafana-dashboard-engineer (#27)" (`50375a2`)
- Add markdown documentation generation to grafana-dashboard-engineer (#27) (`ef706af`)

## [0.5.0] - 2026-04-08

### Added

- collapsible category UI with Standard Skills group (`ac3f8ed`)
- add remote skill selector (install-skills.ps1) (`e15767e`)

### Changed

- rename agents/ to instructions/, add multi-platform installer with instruction support (`4b00b5a`)

### Fixed

- cast char to string before multiply in separator line (PS 5.1 compat) (`36e4af9`)

### Documentation

- refactor README with quick-start installer and collapsible tables (`a6c09d8`)

## [0.4.0] - 2026-04-06

### Added

- port 5 top-value skills to Codex (tdd-workflow, security-review, chrome-extension-builder, project-manager, skills-manager) (`621c985`)

## [0.3.0] - 2026-04-05

### Added

- backfill diagrams for all 91 skills, add 9 skills-manager commands, fix audit issues (`85dee5b`)

### Changed

- merge react-native-skills into react-native with Expo, performance, and animation rules (`9ec4fa4`)

### Internal

- sync skills — harden release-to-main guards, update ship-to-dev (`9fe05dc`)
- sync skills — add 5 homeradar sub-skills, update ship-to-dev (`d9da4ec`)

## [0.2.0] - 2026-03-22

### Added

- add add-feature skill with conversational spec workflow (`05a7d78`)
- add start-app skill and /start-app command (`81991c9`)

### Internal

- sync skills — add guide-assistant, update ship-to-dev and chrome-extension-builder (`fb375a3`)

## [0.1.1] - 2026-03-15

### Internal

- sync skills — add 4 new skills, update release-to-main and ship-to-dev (`3762230`)

### Other

- Create expert-review-and-enhancement.md (`8ed4690`)
- Create techical-author-draft.md (`ddcd045`)
- Create training-guide-and-manual.md (`8277fdc`)

## [0.1.0] - 2026-03-04

### Added

- add sync-skills domain skill, refactor command to thin wrapper, sync 10 new skills to archive (`52eba5f`)
- add Codex equivalents for all 63 remaining Claude skills and update README (`a8ff000`)
- add Codex equivalents for 15 Foundations & Workflow + Languages skills (`9ca7555`)

### Fixed

- use full word 'directory' in grep pattern for AGENTS.md worktree check (`e30b3e7`)

### Other

- Add Codex equivalents for 19 skills (Security + AI/LLM + Commerce + Third-Party + SEO + Tooling) (`dc0b83c`)
- Add Codex equivalents for 15 Databases & Storage + Code Quality skills (`8f6c5c0`)
- Add Codex SKILL.md equivalents for frontend, mobile, and UI skills (`8f3a5b1`)
- Initial plan (`c184bab`)
- Import visual-explainer skill from nicobailon/visual-explainer (`21c50d9`)
- Initial plan (`30691e9`)
- first commit (`f1a5a95`)

