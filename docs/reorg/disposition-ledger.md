---
title: Skill Disposition Ledger - Master-Skills Reorganization
date: 2026-07-10
status: binding
owner: skills-manager
source: docs/reports/2026-07-10-master-skills-consensus.json (implementation contract)
---

# Skill Disposition Ledger

One row per directory under `claude/skills/` at audit time (**142 directories**; verified 2026-07-10). Every directory has exactly one disposition; no orphans. `Iter` is the implementation-tracker iteration in the [master-skills consensus plan](../reports/2026-07-10-master-skills-consensus-plan.md) that executes (and, for deletions, deletes) the row. Target bundle names used throughout this ledger (`agent-manager`, `quality-manager`, `design-manager`, and the rest of the `*-manager` bundles) are future/planned bundles defined in that same plan — they are not yet on disk. Git history is the archive of record for all deleted content. Every deletion ships README-row removal + `manifest.json` regeneration + diagram/installed-copy parity in the same PR ([charter rule 6](charter.md#6-parity-follow-through-every-deletion-pr)).

As each iteration ships, flip its rows' Status from `pending` to `done` in the owning PR.

*This ledger reflects the 2026-07-10 master-skills audit and may lag skills shipped since; the live inventory source of truth is [`CATALOG.md`](../../CATALOG.md).*

## Summary

*Hand-maintained; should be generated from the Ledger below rather than kept in sync by hand (counts drift otherwise).*

| Disposition | Directories |
|---|---:|
| Extend in place (bundle head, slug retained) | 4 |
| Absorb into a bundle sub-skill, then delete | 70 |
| Lift into a bundle unchanged, then delete the top-level copy | 2 |
| Merge into an existing sub-skill, then delete | 1 |
| Move into a bundle (content unchanged) | 1 |
| Split across two owners, then delete | 4 |
| Reconcile flat/bundle duplicate, keep bundle copy, delete flat copy | 7 |
| Merge with sibling into a new standalone skill | 2 |
| Delete outright (not a skill, or project-specific) | 6 |
| Stays standalone (no change) | 10 |
| Stays standalone; frontmatter improved in place | 35 |
| **Total** | **142** |

*Phase tags in the Target column (`P0`, `P2`) are reorg phases defined in [charter.md §9](charter.md#9-phases-and-gate) — distinct from the P1–P5 proposal codes used elsewhere in requirements docs.*

> **▣ Diagram —** disposition Sankey: old skill → disposition type → target bundle *(type: sankey)* — [view](diagrams/disposition-sankey.html)

## Ledger

| Directory | Disposition | Target | [Iter](../reports/2026-07-10-master-skills-consensus-plan.md) | Status | Notes |
|---|---|---|---|---|---|
| `ac-logo` | absorb-delete | design-manager / logo-pipeline | 21 | pending | All ac-logo command names retained verbatim; global-profile stale-copy cleanup + /update-skill sweep in the same PR series. |
| `ac-opbta-ops` | absorb-delete | ops-manager (cross-cutting invariants) | 18 | pending | AC_OPBTA repo retains a thin installed index with `requires: ops-manager`; concrete environment values live there, not in the archive. |
| `accumulated-feature-branch-workflow` | absorb-delete | github / pr-splitter | 2 | pending |  |
| `add-feature` | merge-delete | project-manager / add-feature (existing sub-skill) | 9 | pending | Standalone top-level skill merges into the existing bundle sub-skill; one /add-feature command remains. |
| `add-remote-installer` | absorb-delete | utilities-manager / /add-remote-installer (command) | 25 | pending | Already command-shaped; demoted to a bundle command with /update-skill handling in the same PR series. |
| `additive-merge-conflict-resolution` | lift-into-bundle | github / additive-merge-conflict-resolution | 2 | pending | Lifted unchanged as a bundle sub-skill. |
| `agentic-development` | absorb-delete | agent-manager / agent-runtime-config | 13 | pending |  |
| `ai-models` | absorb-delete | agent-manager / agent-runtime-config | 13 | pending |  |
| `analyze-conversations` | absorb-delete | session-manager / mine | - | done | Became `mine` friction mode (2026-10-21 session-manager PR); `analyze-conversations.py` rewired onto `transcripts`; `/analyze-conversations` command name retained. Re-pointed from agent-manager / history-mining-pipeline by [charter §3/§4 amendment](charter.md#3-boundary-sentences-verbatim). |
| `base` | standalone | - | - | pending | Universal coding patterns; NOT absorbed by skills-manager. Remove dangling requires:[base] references from cut architecture-manager drafts if any land. |
| `brand-token-extraction-and-documentation` | absorb-delete | design-manager / brand-extraction | 22 | pending |  |
| `chrome-extension-builder` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `code-deduplication` | absorb-delete | quality-manager / code-deduplication | 15 | pending | Wired into the review checklist. |
| `code-review` | absorb-delete | quality-manager / code-review (multi-engine) | 14 | pending | Model IDs read from agent-manager's review-model-config convention, never hardcoded. Global /code-review moves with fleet sweep ([resolution #3](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `codex-review` | absorb-delete | quality-manager / code-review (multi-engine) | 14 | pending | Model IDs read from agent-manager's review-model-config convention, never hardcoded. Global /code-review moves with fleet sweep ([resolution #3](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `comment-harvesting` | reconcile-delete | youtube-extraction / (same-named bundle sub-skill) | 23 | pending | Flat top-level duplicate of the bundled sub-skill; deleted after content reconciliation (bundle copy wins). |
| `commit-hygiene` | absorb-delete | github / pr-splitter | 2 | pending |  |
| `composition-patterns` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `content-aware-file-renaming` | absorb-delete | gated-batch / content-aware-file-renaming | 24 | pending | Absorbed unchanged as the corpus-normalization front door. |
| `conversation-history-mining-for-domain-knowledge` | absorb-delete | session-manager / mine | - | done | Became `mine` knowledge mode (2026-10-21 session-manager PR). Re-pointed from agent-manager / history-mining-pipeline by the charter amendment. |
| `credentials` | absorb-delete | utilities-manager / credential-onboarding | 25 | pending |  |
| `crlf-gitattributes-normalization` | lift-into-bundle | github / crlf-gitattributes-normalization | 2 | pending | Lifted unchanged as a bundle sub-skill. |
| `css-variables-for-multi-theme-reskin` | absorb-delete | design-manager / design-token-pipeline | 22 | pending | Becomes the lightweight layer. |
| `csv-driven-llm-pipeline` | absorb-delete | gated-batch / resumable-batch-pipeline | 24 | pending | gated-batch also stages pdf-document-mining, human-review-gate-webui, report-then-apply-merge, rule-based-taxonomy-classifier as `status: draft` stubs ([resolution #2](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `database-schema` | standalone | - | - | pending | Was architecture-manager absorption; stays standalone after that master's dissolution. |
| `deploy-idempotency-two-pass-gate` | absorb-delete | ops-manager / idempotent-apply-script | 16 | pending | Gains explicit feature-branch -> PR branch-discipline section; AC_OPBTA direct-commit stays a repo-local exception. |
| `deployment-driver-pin-rewrite-from-release-tag-source-of-truth` | absorb-delete | ops-manager / internal-registry-deploy | 17 | pending |  |
| `design-critique-to-safe-refactor` | absorb-delete | design-manager / screenshot-ux-review | 22 | pending |  |
| `diagnostics-probe-design` | absorb-delete | ops-manager / diagnostics-probe | 16 | pending |  |
| `doc-coauthoring` | absorb-delete | project-manager / operator-runbook-authoring | 9 | pending | Generic documentation workflow preserved as a documented mode, not lost. |
| `existing-repo` | absorb-delete | project-manager / backfill-features | 9 | pending | Mandatory analysis phase. |
| `explain-code` | standalone | - | - | pending | Stays standalone; developer-manager routes to it, never absorbs. |
| `extraction-reporting` | reconcile-delete | youtube-extraction / extraction-reporting | 23 | pending | Flat duplicate deleted; bundle copy extended with repatriated llm_ai_labs post-processing scripts + RESOURCES.md format. |
| `feature-start` | delete | - | - | done | HomeRadar-specific; deleted outright rather than de-branded or bundled (2026-10-22, user decision). HomeRadar's repo keeps its own installed copies; git history is the archive of record. /feature-start command retired. |
| `file-reconstruction` | reconcile-delete | youtube-extraction / (same-named bundle sub-skill) | 23 | pending | Flat top-level duplicate of the bundled sub-skill; deleted after content reconciliation (bundle copy wins). |
| `finishing-a-development-branch` | absorb-delete | github / ship (merge/keep/discard decision gate) | 3 | pending | Plugin-precedence vs superpowers:finishing-a-development-branch declared via skills-manager external-skill-intake. |
| `firewall-alias-as-indirection` | absorb-delete | ops-manager / service-lifecycle | 17 | pending |  |
| `fix-start` | delete | - | - | done | HomeRadar-specific; deleted outright rather than de-branded or bundled (2026-10-22, user decision). HomeRadar's repo keeps its own installed copies; git history is the archive of record. /fix-start command retired. |
| `fleet-cp1252-mojibake-fix` | absorb-delete | utilities-manager / fleet-cp1252-mojibake-fix | 25 | pending | Absorbed as-is; also surfaced in the master's Windows Ground Rules table. |
| `frame-content-recognition` | reconcile-delete | youtube-extraction / (same-named bundle sub-skill) | 23 | pending | Flat top-level duplicate of the bundled sub-skill; deleted after content reconciliation (bundle copy wins). |
| `frame-extraction` | reconcile-delete | youtube-extraction / frame-extraction | 23 | pending | CONFIRMED diverged from the bundle copy - reconcile first, keep the bundle copy, add the slide-boundary sampling profile. |
| `frontend-design` | absorb-delete | design-manager / frontend-aesthetics | 21 | pending | Absorbed wholesale. |
| `gemini-review` | absorb-delete | quality-manager / code-review (multi-engine) | 14 | pending | Model IDs read from agent-manager's review-model-config convention, never hardcoded. Global /code-review moves with fleet sweep ([resolution #3](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `github` | extend-in-place | github ([P0](charter.md#9-phases-and-gate)) | 1-3 | pending | Slug retained. Gains worktree-task-lifecycle, pr-splitter, large-asset-vendoring, /sync-dev, /changelog-preview, /split-pr. |
| `gpu-workload-placement-and-arbitration` | absorb-delete | ops-manager / gpu-placement | 17 | pending | Absorbed unchanged. |
| `grafana-dashboard-engineer` | absorb-delete | ops-manager / observability-dashboards | 17 | pending | Resolves the documented rationalization pair; /update-skill sweep for github-awesome's stale flat copy in the same PR series. |
| `grafana-dashboard-workflow` | absorb-delete | ops-manager / observability-dashboards | 17 | pending | Resolves the documented rationalization pair; /update-skill sweep for github-awesome's stale flat copy in the same PR series. |
| `graphify` | standalone | - | - | pending | Live global-trigger wiring; cross-referenced under Session Infrastructure, never absorbed. |
| `guide-assistant` | absorb-delete | utilities-manager / guide-assistant | 25 | pending | Absorbed unchanged as the runbook-execution front-end; no /guide command. |
| `honcho` | standalone | - | - | pending | Live plugin/global-trigger wiring; cross-referenced under Session Infrastructure, never absorbed. |
| `honcho-deriver-queue-health-diagnostics` | absorb-delete | ops-manager / diagnostic-ladders | 16 | pending |  |
| `iterative-audit-gate-with-streak-reset` | absorb-delete | quality-manager / audit-gate | 15 | pending | Absorbed essentially unchanged. |
| `iterative-development` | absorb-delete | project-manager / loop-prompt-composer | 7 | pending |  |
| `llm-patterns` | absorb-delete | agent-manager / agent-runtime-config | 13 | pending |  |
| `logo-restylizer` | absorb-delete | design-manager / logo-pipeline | 21 | pending | All ac-logo command names retained verbatim; global-profile stale-copy cleanup + /update-skill sweep in the same PR series. |
| `lvm-thin-pool-diagnostics-recovery` | absorb-delete | ops-manager / diagnostic-ladders | 16 | pending |  |
| `marko` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `multi-perspective-dns-diagnostic-ladder` | absorb-delete | ops-manager / diagnostic-ladders | 16 | pending |  |
| `nodejs-backend` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `parallel-subagent-fanout` | absorb-delete | agent-manager / fleet-repo-fanout | 12 | pending | subagent-driven-development contributes fresh-agent + two-stage-review doctrine as the single-repo case. |
| `playwright-testing` | absorb-delete | quality-manager / e2e-playwright | 14 | pending | Global /e2e moves with fleet sweep ([resolution #3](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `pre-pr` | delete | - | - | done | HomeRadar-specific; deleted outright rather than de-branded or bundled (2026-10-22, user decision). HomeRadar's repo keeps its own installed copies; git history is the archive of record. /pre-pr command retired. |
| `project-manager` | extend-in-place | project-manager ([P0](charter.md#9-phases-and-gate)) | 6-9 | pending | Slug retained. Sole owner of session handoff; gains loop-prompt-composer, backlog-burndown, learnings-ledger, backfill-features. Stages product-inception-pack + enhancement-bundle as `status: draft` stubs ([resolution #2](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). **PM Lifecycle Redesign (2026-07-16, [PM Lifecycle Redesign spec](../reports/2026-07-16-pm-lifecycle-redesign.review.md)): added sub-skills `capture`/`groom`/`task`/`retro` (commands `/pm-capture` `/pm-groom` `/pm-task` `/pm-retro`), the [`docs/backlog.md`](../backlog.md) intake store + `scope-manifest.md` chore-lane guard, and STATUS §4 generation. PRs #77–#82.** |
| `project-plan-task-reconciliation` | absorb-delete | project-manager / orchestrator-bookkeeping | 8 | pending |  |
| `project-tooling` | absorb-delete | developer-manager / local-dev-harness | 19 | pending | /start-app command rewired, name unchanged; gains a generation mode. developer-manager also stages go-development, fastapi-htmx, python-app-scaffolds, ollama-integration as `status: draft` stubs ([resolution #2](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `pwa-development` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `python` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `react-best-practices` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `react-virtualization-with-jsdom-measurement` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `react-web` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `reactive-ui-state-with-delegated-event-routing` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `recursive-batch-handoff` | absorb-delete | session-manager / handoff | - | done | Became `handoff` chain mode (2026-10-21 session-manager PR). |
| `remote-installer` | absorb-delete | utilities-manager / installer-lifecycle | 25 | pending |  |
| `requesting-code-review` | absorb-delete | quality-manager / code-review (multi-engine) | 14 | pending | Model IDs read from agent-manager's review-model-config convention, never hardcoded. Global /code-review moves with fleet sweep ([resolution #3](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `retro-fit-spec` | delete | - | - | done | HomeRadar-specific; deleted outright rather than de-branded or bundled (2026-10-22, user decision). HomeRadar's repo keeps its own installed copies; git history is the archive of record. /retro-fit-spec command retired. |
| `scanner-plugin-integration` | standalone | - | - | pending | Was architecture-manager absorption; stays standalone. |
| `security` | absorb-delete | quality-manager / security-review | 14 | pending |  |
| `security-aware-persistence-design` | standalone | - | - | pending | Was architecture-manager absorption; stays standalone. |
| `self-contained-html-artifact-with-inline-assets` | absorb-delete | design-manager / html-mockup-prototyper | 22 | pending | Packaging rules stay the canonical layer other bundles reference. design-manager also stages raw-json-to-domain-panel as a `status: draft` stub ([resolution #2](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)); console-output-style ships here ([resolution #5](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `self-paced-loop-iteration` | absorb-delete | project-manager / loop-prompt-composer | 7 | pending |  |
| `session-management` | absorb-delete | session-manager / checkpoint | - | done | Merged with `state-file-driven-multi-turn-resumption` into one state-file convention in `checkpoint` (2026-10-21 session-manager PR); Codex mirror deleted (Claude only). |
| `shell-helper-migration` | absorb-delete | ops-manager / shell-fleet-migration | 18 | pending | The full shell trio co-located as one workflow. |
| `shell-migration-skip-taxonomy` | absorb-delete | ops-manager / shell-fleet-migration | 18 | pending | The full shell trio co-located as one workflow. |
| `side-effect-free-helper-library` | absorb-delete | ops-manager / shell-fleet-migration | 18 | pending | The full shell trio co-located as one workflow. |
| `site-architecture` | standalone | - | - | pending | Orphan closed as standalone by board ruling. |
| `skills-manager` | extend-in-place | skills-manager ([P0](charter.md#9-phases-and-gate)) | 4-5 | pending | Slug retained. Gains skill-parity-guard, installed-copy-sweep, external-skill-intake; owns this ledger + the command-namespace registry. |
| `sops-secrets` | absorb-delete | ops-manager / secrets-ops | 17 | pending | secrets-ops is the SOLE owner of /get-secret. dropbox-api staged as `status: draft` stub ([resolution #2](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `spec-align` | delete | - | - | done | HomeRadar-specific; deleted outright rather than de-branded or bundled (2026-10-22, user decision). HomeRadar's repo keeps its own installed copies; git history is the archive of record. /spec-align command retired. |
| `spec-consistency-doc-refactoring-pattern` | absorb-delete | project-manager / orchestrator-bookkeeping | 8 | pending |  |
| `stale-symbolic-ref-detection-and-repair` | split-delete | github (git slice) + ops-manager / diagnostics-probe (general half) | 16 | pending | Git slice LANDED in github master principles (iter 1, verify-refs-before-destructive bullet); general verify-cached-state-before-destructive-action half absorbed by ops-manager diagnostics-probe (iter 16); directory deleted once both halves land. |
| `start-app` | absorb-delete | developer-manager / local-dev-harness | 19 | pending | /start-app command rewired, name unchanged; gains a generation mode. developer-manager also stages go-development, fastapi-htmx, python-app-scaffolds, ollama-integration as `status: draft` stubs ([resolution #2](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `state-file-driven-multi-turn-resumption` | absorb-delete | session-manager / checkpoint | - | done | Merged with `session-management` into one state-file convention in `checkpoint` (2026-10-21 session-manager PR). |
| `subagent-driven-development` | absorb-delete | agent-manager / fleet-repo-fanout | 12 | pending | subagent-driven-development contributes fresh-agent + two-stage-review doctrine as the single-repo case. |
| `superpowers-overrides` | absorb-delete | skills-manager / external-skill-intake | 5 | pending | Becomes the adapted-external-copy policy; external-skill-intake is the single owner of ALL plugin-precedence declarations. |
| `tdd-workflow` | absorb-delete | quality-manager / tdd | 14 | pending | Global /tdd, /test-coverage move with fleet sweep ([resolution #3](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `team-coordination` | absorb-delete | agent-manager / agent-coordination | 13 | pending | Shared-state claiming/handoff conventions only; ALL next-session handoff-prompt content and triggers stripped and ceded to project-manager session-handoff. |
| `transcript-acquisition` | reconcile-delete | youtube-extraction / (same-named bundle sub-skill) | 23 | pending | Flat top-level duplicate of the bundled sub-skill; deleted after content reconciliation (bundle copy wins). |
| `two-surface-observability-reconciliation` | split-delete | ops-manager / diagnostics-probe (observability half) + project-manager / orchestrator-bookkeeping (project-tracking half) | 16 | pending | Project-tracking half lands iter 8; observability half + deletion iter 16. **PM-half TRIM landed early (2026-07-16, PR #82): the "framework vs. living backlog" When-to-use bullet + Method step 2 removed (obsoleted by generated STATUS §4); the genuine split-observability/stale-healthcheck/metrics-derivation content is retained. Full split-delete still due at iter 16.** |
| `typescript` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `ui-redesign-with-snapshot-regeneration` | absorb-delete | design-manager / screenshot-ux-review | 22 | pending |  |
| `ui-testing` | absorb-delete | quality-manager / visual-verify-loop | 15 | pending | Becomes THE canonical launch-and-observe recipe for every surface; browser-console-triage content folds in here. |
| `ui-web` | absorb-delete | design-manager / ui-standards | 21 | pending | Four-way merge into one stack-aware audit rubric; deletion ships with fleet reference-rewrite in the same PR series. |
| `usage-limit-reducer` | absorb-delete | session-manager / usage + /token-report | - | done | Became `usage` historical-burn mode (2026-10-21 session-manager PR); `usage-report.py` rewired onto `transcripts`. Verbatim trigger phrases ('hit my limit', 'running out of tokens', 'which model should I use') MUST appear in the session-manager frontmatter description. Re-pointed from agent-manager / session-jsonl-toolkit by the charter amendment. |
| `user-journeys` | absorb-delete | design-manager / ui-standards | 21 | pending | Four-way merge into one stack-aware audit rubric; deletion ships with fleet reference-rewrite in the same PR series. |
| `using-git-worktrees` | absorb-delete | github / worktree-task-lifecycle | 1 | done | Absorbed into github/sub-skills/worktree-task-lifecycle (directory selection, ignore verification, clean baseline); Claude + Codex copies deleted. |
| `video-acquisition` | reconcile-delete | youtube-extraction / (same-named bundle sub-skill) | 23 | pending | Flat top-level duplicate of the bundled sub-skill; deleted after content reconciliation (bundle copy wins). |
| `visual-explainer` | standalone | - | - | pending | Plugin-installed, third-party, non-product-UI scope; design-manager routing table cross-references it. |
| `web-content` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `web-design-guidelines` | absorb-delete | design-manager / ui-standards | 21 | pending | Four-way merge into one stack-aware audit rubric; deletion ships with fleet reference-rewrite in the same PR series. |
| `what-next` | move-into-bundle | project-manager / what-next | 9 | pending | Moves in unchanged plus new workspace mode (absorbs the workspace repo-picker half). /what-next + /what-next-update names unchanged. |
| `what-next-workspace` | delete | - | 0 | done | Eval artifacts (grade.py, migrate.py, iteration-1/2 dirs, __pycache__), not a skill. Was untracked by git; removed from disk in the charter PR. |
| `workspace` | split-delete | project-manager / what-next (repo-picker half); API-contract half DELETED | 9 | pending | Human [resolution #1](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults) (erik, 2026-07-10): API-contract/cross-repo-topology half is deleted outright, nothing migrates; git history is the archive. |
| `worktree-isolated-loop` | split-delete | github / worktree-task-lifecycle + project-manager / loop-prompt-composer | 1 | done | Git-isolation half absorbed into github worktree-task-lifecycle (iter 1); directory deleted — loop-handoff prose to be authored into project-manager loop-prompt-composer at iter 7 from git history (commit before this PR). |
| `youtube-extraction` | extend-in-place | youtube-extraction ([P2](charter.md#9-phases-and-gate)) | 23 | pending | Slug retained; media-manager cancelled. Gains youtube-channel-tracker, conference-talk-extraction, prd-forensics; TTS/manual-generation staged as `status: draft` stubs ([resolution #2](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)). |
| `youtube-prd-forensics` | absorb-delete | youtube-extraction / prd-forensics | 23 | pending | Output scoped as video-derived forensic PRDs under docs/, NOT docs/features/ specs. |

## Post-audit additions

Skills created after the 2026-07-10 audit. They are not part of the frozen 142-row table
or its summary counts above; the live inventory is [`CATALOG.md`](../../CATALOG.md). Listed
here so each new directory still carries an explicit disposition.

| Directory | Disposition | Target | Iter | Status | Notes |
|---|---|---|---|---|---|
| `startup-context-audit` | absorb-delete | session-manager / usage | - | done | New standalone skill (2026-08-07), then absorbed into `usage` startup-baseline mode (2026-10-21 session-manager PR); `startup-context.py` rewired onto `transcripts`; `/startup-cost` name unchanged. |
| `statusline` | standalone | - (no relocation) | - | done | New standalone skill (2026-08-26). Owns the Claude Code status-line lifecycle: the canonical worktree/handoff-safe `assets/statusline.sh` (reads native `context_window` stdin fields first, transcript only as fallback) plus install/remove/inspect/modify/audit sub-skills and thin `<verb>-statusline` commands. **Absorbs and replaces the retired `claude/statuslines/` asset dir** (deleted this PR; git history is the archive) — single-ownership per charter §3, so the archive asset and the deployed `~/.claude/statusline.sh` no longer drift by construction. Distinct concern from `startup-context-audit`/`usage-limit-reducer` (those measure token *burn*; this owns the *display surface* that shows it). Ships `references/statusline-payload.md`; `diagram.html` to be backfilled via `/backfill-diagrams`. |
| `session-handoff` | absorb-delete | session-manager / handoff + dispatch + retire + delegation-ledger + audit | - | done | Umbrella created 2026-08-03 (no prior row). Split into session-manager sub-skills (2026-10-21 session-manager PR); shrunk to a `status: deprecated` router alias for one release — delete next release. Commands moved: `/handoff`, `/dispatch-session-prompt`, `/hand-off-audit`. |
| `spawn-terminal` | standalone | - (no relocation) | - | done | New standalone skill (2026-08-05; no prior row). Generic Windows-Terminal spawn core; unchanged. `session-manager` declares it in `requires:` and its `dispatch` launcher resolves it. |
| `work-resume` | absorb-delete | session-manager / resume | - | done | New bundle (2026-07-30; no prior row). Absorbed whole into `resume` (2026-10-21 session-manager PR): SKILL.md, README, four commands (names unchanged), `resume-scan.py` rewired onto `transcripts`; its three internal sub-skills folded into `resume/references/`. |
| `session-manager` | new bundle | - (bundle head) | - | done | New master bundle (2026-10-21 session-manager PR) per the charter §3/§4 amendment: owns the session lifecycle (resume, checkpoint, handoff, dispatch, retire, audit, mine, delegation-ledger, usage) plus the shared `transcripts` JSONL parser. Also absorbs `project-manager/sub-skills/continue-new-session` (→ `handoff` copy mode; `/continue-new-session` kept as alias). |
