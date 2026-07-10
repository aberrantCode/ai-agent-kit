---
title: Skill Disposition Ledger - Master-Skills Reorganization
date: 2026-07-10
status: binding
owner: skills-manager
source: docs/reports/2026-07-10-master-skills-consensus.json (implementation contract)
---

# Skill Disposition Ledger

One row per directory under `claude/skills/` at audit time (**142 directories**; verified 2026-07-10). Every directory has exactly one disposition; no orphans. `Iter` is the implementation-tracker iteration in `docs/reports/2026-07-10-master-skills-consensus-plan.md` that executes (and, for deletions, deletes) the row. Git history is the archive of record for all deleted content. Every deletion ships README-row removal + `manifest.json` regeneration + diagram/installed-copy parity in the same PR (charter rule 6).

As each iteration ships, flip its rows' Status from `pending` to `done` in the owning PR.

## Summary

| Disposition | Directories |
|---|---:|
| Extend in place (bundle head, slug retained) | 4 |
| Absorb into a bundle sub-skill, then delete | 74 |
| Lift into a bundle unchanged, then delete the top-level copy | 2 |
| Merge into an existing sub-skill, then delete | 2 |
| Move into a bundle (content unchanged) | 1 |
| Split across two owners, then delete | 4 |
| Reconcile flat/bundle duplicate, keep bundle copy, delete flat copy | 7 |
| Merge with sibling into a new standalone skill | 2 |
| Delete outright (not a skill) | 1 |
| Stays standalone (no change) | 10 |
| Stays standalone; frontmatter improved in place | 35 |
| **Total** | **142** |

## Ledger

| Directory | Disposition | Target | Iter | Status | Notes |
|---|---|---|---|---|---|
| `ac-logo` | absorb-delete | design-manager / logo-pipeline | 21 | pending | All ac-logo command names retained verbatim; global-profile stale-copy cleanup + /update-skill sweep in the same PR series. |
| `ac-opbta-ops` | absorb-delete | ops-manager (cross-cutting invariants) | 18 | pending | AC_OPBTA repo retains a thin installed index with `requires: ops-manager`; concrete environment values live there, not in the archive. |
| `accumulated-feature-branch-workflow` | absorb-delete | github / pr-splitter | 2 | pending |  |
| `add-feature` | merge-delete | project-manager / add-feature (existing sub-skill) | 9 | pending | Standalone top-level skill merges into the existing bundle sub-skill; one /add-feature command remains. |
| `add-remote-installer` | absorb-delete | utilities-manager / /add-remote-installer (command) | 25 | pending | Already command-shaped; demoted to a bundle command with /update-skill handling in the same PR series. |
| `additive-merge-conflict-resolution` | lift-into-bundle | github / additive-merge-conflict-resolution | 2 | pending | Lifted unchanged as a bundle sub-skill. |
| `aeo-optimization` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `agentic-development` | absorb-delete | agent-manager / agent-runtime-config | 13 | pending |  |
| `ai-models` | absorb-delete | agent-manager / agent-runtime-config | 13 | pending |  |
| `analyze-conversations` | absorb-delete | agent-manager / history-mining-pipeline | 13 | pending | Becomes the recurring-friction-audit mode. |
| `android-java` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `android-kotlin` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `aws-aurora` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `aws-dynamodb` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `azure-cosmosdb` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `base` | standalone | - | - | pending | Universal coding patterns; NOT absorbed by skills-manager. Remove dangling requires:[base] references from cut architecture-manager drafts if any land. |
| `brand-token-extraction-and-documentation` | absorb-delete | design-manager / brand-extraction | 22 | pending |  |
| `chrome-extension-builder` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `cloudflare-d1` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `code-deduplication` | absorb-delete | quality-manager / code-deduplication | 15 | pending | Wired into the review checklist. |
| `code-review` | absorb-delete | quality-manager / code-review (multi-engine) | 14 | pending | Model IDs read from agent-manager's review-model-config convention, never hardcoded. Global /code-review moves with fleet sweep (resolution #3). |
| `codex-review` | absorb-delete | quality-manager / code-review (multi-engine) | 14 | pending | Model IDs read from agent-manager's review-model-config convention, never hardcoded. Global /code-review moves with fleet sweep (resolution #3). |
| `comment-harvesting` | reconcile-delete | youtube-extraction / (same-named bundle sub-skill) | 23 | pending | Flat top-level duplicate of the bundled sub-skill; deleted after content reconciliation (bundle copy wins). |
| `commit-hygiene` | absorb-delete | github / pr-splitter | 2 | pending |  |
| `composition-patterns` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `content-aware-file-renaming` | absorb-delete | gated-batch / content-aware-file-renaming | 24 | pending | Absorbed unchanged as the corpus-normalization front door. |
| `conversation-history-mining-for-domain-knowledge` | absorb-delete | agent-manager / history-mining-pipeline | 13 | pending |  |
| `credentials` | absorb-delete | utilities-manager / credential-onboarding | 25 | pending |  |
| `crlf-gitattributes-normalization` | lift-into-bundle | github / crlf-gitattributes-normalization | 2 | pending | Lifted unchanged as a bundle sub-skill. |
| `css-variables-for-multi-theme-reskin` | absorb-delete | design-manager / design-token-pipeline | 22 | pending | Becomes the lightweight layer. |
| `csv-driven-llm-pipeline` | absorb-delete | gated-batch / resumable-batch-pipeline | 24 | pending | gated-batch also stages pdf-document-mining, human-review-gate-webui, report-then-apply-merge, rule-based-taxonomy-classifier as `status: draft` stubs (resolution #2). |
| `database-schema` | standalone | - | - | pending | Was architecture-manager absorption; stays standalone after that master's dissolution. |
| `deploy-idempotency-two-pass-gate` | absorb-delete | ops-manager / idempotent-apply-script | 16 | pending | Gains explicit feature-branch -> PR branch-discipline section; AC_OPBTA direct-commit stays a repo-local exception. |
| `deployment-driver-pin-rewrite-from-release-tag-source-of-truth` | absorb-delete | ops-manager / internal-registry-deploy | 17 | pending |  |
| `design-critique-to-safe-refactor` | absorb-delete | design-manager / screenshot-ux-review | 22 | pending |  |
| `diagnostics-probe-design` | absorb-delete | ops-manager / diagnostics-probe | 16 | pending |  |
| `doc-coauthoring` | absorb-delete | project-manager / operator-runbook-authoring | 9 | pending | Generic documentation workflow preserved as a documented mode, not lost. |
| `existing-repo` | absorb-delete | project-manager / backfill-features | 9 | pending | Mandatory analysis phase. |
| `explain-code` | standalone | - | - | pending | Stays standalone; developer-manager routes to it, never absorbs. |
| `extraction-reporting` | reconcile-delete | youtube-extraction / extraction-reporting | 23 | pending | Flat duplicate deleted; bundle copy extended with repatriated llm_ai_labs post-processing scripts + RESOURCES.md format. |
| `feature-start` | merge-delete | project-manager / add-feature (existing sub-skill) | 9 | pending | Merges into add-feature, not backfill-features; /feature-start command retired. |
| `file-reconstruction` | reconcile-delete | youtube-extraction / (same-named bundle sub-skill) | 23 | pending | Flat top-level duplicate of the bundled sub-skill; deleted after content reconciliation (bundle copy wins). |
| `finishing-a-development-branch` | absorb-delete | github / ship (merge/keep/discard decision gate) | 3 | pending | Plugin-precedence vs superpowers:finishing-a-development-branch declared via skills-manager external-skill-intake. |
| `firebase` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `firewall-alias-as-indirection` | absorb-delete | ops-manager / service-lifecycle | 17 | pending |  |
| `fix-start` | absorb-delete | quality-manager / fix-start | 15 | pending | Generalized from HomeRadar paths; /update-skill pass for zillow_tracker's installed copy in the same PR series. |
| `fleet-cp1252-mojibake-fix` | absorb-delete | utilities-manager / fleet-cp1252-mojibake-fix | 25 | pending | Absorbed as-is; also surfaced in the master's Windows Ground Rules table. |
| `flutter` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `frame-content-recognition` | reconcile-delete | youtube-extraction / (same-named bundle sub-skill) | 23 | pending | Flat top-level duplicate of the bundled sub-skill; deleted after content reconciliation (bundle copy wins). |
| `frame-extraction` | reconcile-delete | youtube-extraction / frame-extraction | 23 | pending | CONFIRMED diverged from the bundle copy - reconcile first, keep the bundle copy, add the slide-boundary sampling profile. |
| `frontend-design` | absorb-delete | design-manager / frontend-aesthetics | 21 | pending | Absorbed wholesale. |
| `gemini-review` | absorb-delete | quality-manager / code-review (multi-engine) | 14 | pending | Model IDs read from agent-manager's review-model-config convention, never hardcoded. Global /code-review moves with fleet sweep (resolution #3). |
| `github` | extend-in-place | github (P0) | 1-3 | pending | Slug retained. Gains worktree-task-lifecycle, pr-splitter, large-asset-vendoring, /sync-dev, /changelog-preview, /split-pr. |
| `gpu-workload-placement-and-arbitration` | absorb-delete | ops-manager / gpu-placement | 17 | pending | Absorbed unchanged. |
| `grafana-dashboard-engineer` | absorb-delete | ops-manager / observability-dashboards | 17 | pending | Resolves the documented rationalization pair; /update-skill sweep for github-awesome's stale flat copy in the same PR series. |
| `grafana-dashboard-workflow` | absorb-delete | ops-manager / observability-dashboards | 17 | pending | Resolves the documented rationalization pair; /update-skill sweep for github-awesome's stale flat copy in the same PR series. |
| `graphify` | standalone | - | - | pending | Live global-trigger wiring; cross-referenced under Session Infrastructure, never absorbed. |
| `guide-assistant` | absorb-delete | utilities-manager / guide-assistant | 25 | pending | Absorbed unchanged as the runbook-execution front-end; no /guide command. |
| `honcho` | standalone | - | - | pending | Live plugin/global-trigger wiring; cross-referenced under Session Infrastructure, never absorbed. |
| `honcho-deriver-queue-health-diagnostics` | absorb-delete | ops-manager / diagnostic-ladders | 16 | pending |  |
| `iterative-audit-gate-with-streak-reset` | absorb-delete | quality-manager / audit-gate | 15 | pending | Absorbed essentially unchanged. |
| `iterative-development` | absorb-delete | project-manager / loop-prompt-composer | 7 | pending |  |
| `klaviyo` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `llm-patterns` | absorb-delete | agent-manager / agent-runtime-config | 13 | pending |  |
| `logo-restylizer` | absorb-delete | design-manager / logo-pipeline | 21 | pending | All ac-logo command names retained verbatim; global-profile stale-copy cleanup + /update-skill sweep in the same PR series. |
| `lvm-thin-pool-diagnostics-recovery` | absorb-delete | ops-manager / diagnostic-ladders | 16 | pending |  |
| `marko` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `medusa` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `ms-teams-apps` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `multi-perspective-dns-diagnostic-ladder` | absorb-delete | ops-manager / diagnostic-ladders | 16 | pending |  |
| `nodejs-backend` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `parallel-subagent-fanout` | absorb-delete | agent-manager / fleet-repo-fanout | 12 | pending | subagent-driven-development contributes fresh-agent + two-stage-review doctrine as the single-repo case. |
| `playwright-testing` | absorb-delete | quality-manager / e2e-playwright | 14 | pending | Global /e2e moves with fleet sweep (resolution #3). |
| `posthog-analytics` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `pre-pr` | absorb-delete | github / ship (generic pre-PR gates) | 2 | pending | HomeRadar-branded archive copy; generic gates (tests, 400/800 size cap) fold into ship. Deleted with README/manifest parity in the same PR. |
| `project-manager` | extend-in-place | project-manager (P0) | 6-9 | pending | Slug retained. Sole owner of session handoff; gains loop-prompt-composer, backlog-burndown, learnings-ledger, backfill-features. Stages product-inception-pack + enhancement-bundle as `status: draft` stubs (resolution #2). |
| `project-plan-task-reconciliation` | absorb-delete | project-manager / orchestrator-bookkeeping | 8 | pending |  |
| `project-tooling` | absorb-delete | developer-manager / local-dev-harness | 19 | pending | /start-app command rewired, name unchanged; gains a generation mode. developer-manager also stages go-development, fastapi-htmx, python-app-scaffolds, ollama-integration as `status: draft` stubs (resolution #2). |
| `pwa-development` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `python` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `react-best-practices` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `react-native` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `react-virtualization-with-jsdom-measurement` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `react-web` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `reactive-ui-state-with-delegated-event-routing` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `recursive-batch-handoff` | absorb-delete | project-manager / session-handoff | 6 | pending |  |
| `reddit-ads` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `reddit-api` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `remote-installer` | absorb-delete | utilities-manager / installer-lifecycle | 25 | pending |  |
| `requesting-code-review` | absorb-delete | quality-manager / code-review (multi-engine) | 14 | pending | Model IDs read from agent-manager's review-model-config convention, never hardcoded. Global /code-review moves with fleet sweep (resolution #3). |
| `retro-fit-spec` | absorb-delete | project-manager / backfill-features | 9 | pending | De-branded on absorption. |
| `scanner-plugin-integration` | standalone | - | - | pending | Was architecture-manager absorption; stays standalone. |
| `security` | absorb-delete | quality-manager / security-review | 14 | pending |  |
| `security-aware-persistence-design` | standalone | - | - | pending | Was architecture-manager absorption; stays standalone. |
| `self-contained-html-artifact-with-inline-assets` | absorb-delete | design-manager / html-mockup-prototyper | 22 | pending | Packaging rules stay the canonical layer other bundles reference. design-manager also stages raw-json-to-domain-panel as a `status: draft` stub (resolution #2); console-output-style ships here (resolution #5). |
| `self-paced-loop-iteration` | absorb-delete | project-manager / loop-prompt-composer | 7 | pending |  |
| `session-management` | absorb-delete | project-manager / session-handoff | 6 | pending |  |
| `shell-helper-migration` | absorb-delete | ops-manager / shell-fleet-migration | 18 | pending | The full shell trio co-located as one workflow. |
| `shell-migration-skip-taxonomy` | absorb-delete | ops-manager / shell-fleet-migration | 18 | pending | The full shell trio co-located as one workflow. |
| `shopify-apps` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `side-effect-free-helper-library` | absorb-delete | ops-manager / shell-fleet-migration | 18 | pending | The full shell trio co-located as one workflow. |
| `site-architecture` | standalone | - | - | pending | Orphan closed as standalone by board ruling. |
| `skills-manager` | extend-in-place | skills-manager (P0) | 4-5 | pending | Slug retained. Gains skill-parity-guard, installed-copy-sweep, external-skill-intake; owns this ledger + the command-namespace registry. |
| `sops-secrets` | absorb-delete | ops-manager / secrets-ops | 17 | pending | secrets-ops is the SOLE owner of /get-secret. dropbox-api staged as `status: draft` stub (resolution #2). |
| `spec-align` | absorb-delete | project-manager / backfill-features | 9 | pending | Becomes the gap-analysis companion mode. |
| `spec-consistency-doc-refactoring-pattern` | absorb-delete | project-manager / orchestrator-bookkeeping | 8 | pending |  |
| `stale-symbolic-ref-detection-and-repair` | split-delete | github (git slice) + ops-manager / diagnostics-probe (general half) | 16 | pending | Git slice absorbed into github master principles (iter 1); general verify-cached-state-before-destructive-action half absorbed by ops-manager diagnostics-probe (iter 16); directory deleted once both halves land. |
| `start-app` | absorb-delete | developer-manager / local-dev-harness | 19 | pending | /start-app command rewired, name unchanged; gains a generation mode. developer-manager also stages go-development, fastapi-htmx, python-app-scaffolds, ollama-integration as `status: draft` stubs (resolution #2). |
| `state-file-driven-multi-turn-resumption` | absorb-delete | project-manager / session-handoff | 6 | pending |  |
| `subagent-driven-development` | absorb-delete | agent-manager / fleet-repo-fanout | 12 | pending | subagent-driven-development contributes fresh-agent + two-stage-review doctrine as the single-repo case. |
| `supabase` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `supabase-nextjs` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `supabase-node` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `supabase-python` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `superpowers-overrides` | absorb-delete | skills-manager / external-skill-intake | 5 | pending | Becomes the adapted-external-copy policy; external-skill-intake is the single owner of ALL plugin-precedence declarations. |
| `tdd-workflow` | absorb-delete | quality-manager / tdd | 14 | pending | Global /tdd, /test-coverage move with fleet sweep (resolution #3). |
| `team-coordination` | absorb-delete | agent-manager / agent-coordination | 13 | pending | Shared-state claiming/handoff conventions only; ALL next-session handoff-prompt content and triggers stripped and ceded to project-manager session-handoff. |
| `transcript-acquisition` | reconcile-delete | youtube-extraction / (same-named bundle sub-skill) | 23 | pending | Flat top-level duplicate of the bundled sub-skill; deleted after content reconciliation (bundle copy wins). |
| `two-surface-observability-reconciliation` | split-delete | ops-manager / diagnostics-probe (observability half) + project-manager / orchestrator-bookkeeping (project-tracking half) | 16 | pending | Project-tracking half lands iter 8; observability half + deletion iter 16. |
| `typescript` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `ui-mobile` | absorb-delete | design-manager / ui-standards | 21 | pending | Four-way merge into one stack-aware audit rubric; deletion ships with fleet reference-rewrite in the same PR series. |
| `ui-redesign-with-snapshot-regeneration` | absorb-delete | design-manager / screenshot-ux-review | 22 | pending |  |
| `ui-testing` | absorb-delete | quality-manager / visual-verify-loop | 15 | pending | Becomes THE canonical launch-and-observe recipe for every surface; browser-console-triage content folds in here. |
| `ui-web` | absorb-delete | design-manager / ui-standards | 21 | pending | Four-way merge into one stack-aware audit rubric; deletion ships with fleet reference-rewrite in the same PR series. |
| `usage-limit-reducer` | absorb-delete | agent-manager / session-jsonl-toolkit + /token-report | 11 | pending | Verbatim trigger phrases ('hit my limit', 'running out of tokens', 'which model should I use') MUST appear in the agent-manager frontmatter description. |
| `user-journeys` | absorb-delete | design-manager / ui-standards | 21 | pending | Four-way merge into one stack-aware audit rubric; deletion ships with fleet reference-rewrite in the same PR series. |
| `using-git-worktrees` | absorb-delete | github / worktree-task-lifecycle | 1 | pending |  |
| `vercel-deploy-claimable` | standalone | - | - | pending | Vendor-authored; contradicts ops-manager's internal-hosts mission. |
| `video-acquisition` | reconcile-delete | youtube-extraction / (same-named bundle sub-skill) | 23 | pending | Flat top-level duplicate of the bundled sub-skill; deleted after content reconciliation (bundle copy wins). |
| `visual-explainer` | standalone | - | - | pending | Plugin-installed, third-party, non-product-UI scope; design-manager routing table cross-references it. |
| `web-content` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `web-design-guidelines` | absorb-delete | design-manager / ui-standards | 21 | pending | Four-way merge into one stack-aware audit rubric; deletion ships with fleet reference-rewrite in the same PR series. |
| `web-payments` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `what-next` | move-into-bundle | project-manager / what-next | 9 | pending | Moves in unchanged plus new workspace mode (absorbs the workspace repo-picker half). /what-next + /what-next-update names unchanged. |
| `what-next-workspace` | delete | - | 0 | done | Eval artifacts (grade.py, migrate.py, iteration-1/2 dirs, __pycache__), not a skill. Was untracked by git; removed from disk in the charter PR. |
| `woocommerce` | standalone-improve | routed by developer-manager (no relocation) | 20 | pending | Stays standalone; trigger-rich frontmatter description improved in place; developer-manager's router indexes it by repo signal. |
| `workspace` | split-delete | project-manager / what-next (repo-picker half); API-contract half DELETED | 9 | pending | Human resolution #1 (erik, 2026-07-10): API-contract/cross-repo-topology half is deleted outright, nothing migrates; git history is the archive. |
| `worktree-isolated-loop` | split-delete | github / worktree-task-lifecycle + project-manager / loop-prompt-composer | 1 | pending | Git-isolation half -> github worktree-task-lifecycle (iter 1); loop-handoff prose -> project-manager loop-prompt-composer (authored iter 7 from the absorbed content; git history is the archive). |
| `worldview-layer-scaffold` | merge | worldview-scaffolds (new standalone) | 26 | pending | Two halves of one pattern; merged into a single standalone worldview-scaffolds skill at closeout reconciliation. |
| `worldview-shader-preset` | merge | worldview-scaffolds (new standalone) | 26 | pending | Two halves of one pattern; merged into a single standalone worldview-scaffolds skill at closeout reconciliation. |
| `youtube-extraction` | extend-in-place | youtube-extraction (P2) | 23 | pending | Slug retained; media-manager cancelled. Gains youtube-channel-tracker, conference-talk-extraction, prd-forensics; TTS/manual-generation staged as `status: draft` stubs (resolution #2). |
| `youtube-prd-forensics` | absorb-delete | youtube-extraction / prd-forensics | 23 | pending | Output scoped as video-derived forensic PRDs under docs/, NOT docs/features/ specs. |
