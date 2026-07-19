---
title: Master-Skills Reorganization — Board Consensus Plan
date: 2026-07-10
status: ready-for-implementation
sources: 38-agent discovery workflow (19 mining agents over 42 repos + 15 conversation-history sets, 1 taxonomy architect, 12 bundle designers, 5-member review board, 1 chair)
machine-readable: docs/reports/2026-07-10-master-skills-consensus.json
---

# Master-Skills Reorganization — Board Consensus Plan

## 1. Executive Summary

A 38-agent discovery workflow mined every repo under `C:\development` and its Claude Code
conversation history for common issues, repetitive work, and skill opportunities, then designed
and board-reviewed a master-skills reorganization of the archive. The board (architect,
redundancy-checker, maintenance-skeptic, dx-reviewer, consistency-reviewer) approved a
**reduced, phase-gated plan of 11 bundles** — not the 12 drafted:

- **architecture-manager is dissolved** — its pattern sub-skills redistribute to ops-manager
  and developer-manager; its absorbed skills stay standalone.
- **data-manager shrinks** to a single `gated-batch` skill.
- **media-manager is cancelled** — `youtube-extraction` is extended in place under its shipped slug.
- **The extend-in-place slug rule applies universally**: `github`, `project-manager`,
  `skills-manager`, `youtube-extraction`, and all `ac-logo` command names are retained.
  Renaming an installed bundle orphans every installed copy and CLAUDE.md reference.
- **Masters are ownership/routing heads, not runtime gates.** Sub-skills trigger independently
  via their own trigger-rich frontmatter (the `github` bundle precedent); every sub-skill
  description opens with ``Sub-skill of `<master>`.``
- **~25 draft commands were cut or merged**; verb-first naming applied (`/handoff`,
  `/burndown`, `/apply-script`, `/probe-incident`, `/search-sessions`).
- **Phase 1 is soft-gated** (erik, 2026-07-10): `github` + `project-manager` + `skills-manager`
  ship first; at iteration 10 the loop reviews and reports Phase-1 sub-skill firing evidence,
  then proceeds without blocking on confirmation.

Board verdicts: architect, redundancy-checker, dx-reviewer, consistency-reviewer =
**approve-with-changes**; maintenance-skeptic = **reject-restructure** (its cuts were adopted
wholesale by the chair — the skeptic's cuts win ties by charter).

The complete per-bundle specification (every sub-skill, command, absorption, and constraint
note) is in the machine-readable consensus JSON next to this file. That JSON is the
implementation contract; this document is the map.

## 2. Final Bundle Set

| # | Bundle | Priority | Sub-skills | Commands | Absorbs (existing skills) |
|---|--------|----------|-----------:|---------:|--------------------------:|
| 1 | `github` (extended in place) | P0 | 12 | 10 | 10 |
| 2 | `project-manager` (extended in place) | P0 | 8 | 7 | 16 |
| 3 | `skills-manager` (extended in place) | P0 | 6 | 14 | 2 |
| 4 | `agent-manager` (new) | P1 | 10 | 7 | 9 |
| 5 | `quality-manager` (new) | P1 | 10 | 9 | 11 |
| 6 | `developer-manager` (new, thin router) | P1 | 6 | 1 | 2 (+34 standalone stack skills routed, not moved) |
| 7 | `design-manager` (new) | P1 | 11 | 9 | 12 |
| 8 | `ops-manager` (new) | P1 | 11 | 10 | 17 |
| 9 | `utilities-manager` (new) | P2 | 6 | 3 | 5 |
| 10 | `youtube-extraction` (extended in place) | P2 | 10 | 5 | 9 |
| 11 | `gated-batch` (new single skill, not a master) | P2 | 3 | 2 | 2 |

One-line missions:

1. **github** — all git/GitHub mechanics; gains worktree-task-lifecycle, pr-splitter,
   large-asset-vendoring, `/sync-dev`, `/changelog-preview`, `/split-pr`.
2. **project-manager** — spec→plan→task lifecycle, session continuity, handoffs; SOLE owner of
   "give me a prompt for the next session"; gains loop-prompt-composer, backlog-burndown,
   learnings-ledger (from AC_OPBTA's 228-session pattern), backfill-features.
3. **skills-manager** — archive lifecycle + the reorg's own tooling: skill-parity-guard,
   installed-copy-sweep, external-skill-intake (sole owner of plugin-precedence declarations),
   disposition ledger, command-namespace registry.
4. **agent-manager** — multi-agent dispatch/recovery + session-JSONL infrastructure: canonical
   JSONL toolkit + token-efficiency page (absorbs usage-limit-reducer), fleet-repo-fanout,
   stalled-agent-recovery, history-mining-pipeline, `/search-sessions`, `/token-report`.
5. **quality-manager** — proves code works before ship: multi-engine code-review merge
   (code-review + codex-review + gemini-review + requesting-code-review), security, TDD,
   canonical visual-verify-loop for all surfaces, container-smoke-test, `/diagnose-runbook`.
6. **developer-manager** — thin stack-router; the 34 stack skills STAY STANDALONE with
   improved frontmatter; gains powershell, dotnet-wpf, local-dev-harness, and the three
   relocated pattern sub-skills (openapi-contract-codegen, deterministic-build-fingerprinting,
   data-tracker-scaffold).
7. **design-manager** — visual/UX routing head: AC token pipeline, logo-pipeline (absorbs
   ac-logo + logo-restylizer), design-system-alignment (archives align-to-ac),
   screenshot-ux-review, html-mockup-prototyper, console-output-style.
8. **ops-manager** — live-infrastructure operations: idempotent-apply-script contract
   (AC_OPBTA's 200+ instances), diagnostics-probe, service/host lifecycle, secrets-ops (sole
   owner of `/get-secret`), observability-dashboards, shell-fleet-migration trio.
9. **utilities-manager** — Windows workstation utility expertise: wt.exe automation, $PROFILE
   automation, installer-lifecycle (absorbs remote-installer), credential-onboarding,
   `/clean-workspace`.
10. **youtube-extraction** — extended in place: reconciles flat/bundle sub-skill duplicates,
    adds youtube-channel-tracker (github-awesome's 19-script pipeline), conference-talk
    extraction, prd-forensics absorption.
11. **gated-batch** — resumable per-item batch pipelines + the destructive-batch safety
    contract (dry-run default, --confirm, journal, canary, rollback).

## 3. Key Rulings (Phase-0 charter content)

1. **Routing model**: sub-skills trigger independently; masters are ownership/routing heads.
2. **Slug rule**: never rename an installed bundle; every absorption that deletes a referenced
   name ships its fleet `/update-skill` + CLAUDE.md reference-rewrite sweep in the same PR series.
3. **Boundary sentences (verbatim, in both SKILL.md files of each pair)**:
   - project-manager owns single-agent multi-turn loop composition and durable state files;
     agent-manager owns multi-agent dispatch, recovery, and session-JSONL infrastructure.
   - gated-batch owns per-item data-plane state; project-manager owns session-plane resumption.
   - quality-manager owns observe-and-judge + pre-ship smoke; developer-manager owns launch;
     ops-manager owns post-deploy verification.
   - design-manager owns "is it good"; quality-manager owns "does it work".
4. **Cross-CLI mirror policy**: the transpiler is cut. Codex mirrors are created on demand when
   a skill is actually used from Codex; Gemini is frozen at 5; `/audit-skills` reports the gap
   informationally; mirrors carry source-version stamps.
5. **Single owners**: session handoff → project-manager; session-JSONL + token-efficiency →
   agent-manager; `/diagnose-runbook` → quality-manager; shell-fleet trio → ops-manager;
   `/get-secret` → ops-manager; plugin-precedence declarations → skills-manager
   external-skill-intake.
6. **No `/verify` command** — the built-in verify skill and
   superpowers:verification-before-completion own that trigger; quality-manager's sub-skills
   are the deep recipes the built-in routes into.
7. **Counts corrected**: 142 Claude skill directories / 84 Codex / 5 Gemini, 25 global
   commands — CLAUDE.md/README count fixes ship in the owning PRs.
8. **Parity follow-through**: every deletion PR runs skill-parity-guard (README row +
   manifest.json + diagram.html + installed-copy sweep); fix mode proposes but never executes
   deletions.
9. **Hook interactions**: PM state files are declared sanctioned outputs for the doc-blocker
   PreToolUse hook; unattended `/burndown` and `/loop` runs must document handling of the
   git-push-opens-Zed review hook.

## 4. Open Decisions — RESOLVED by erik, 2026-07-10

All five decisions were resolved in an interview on 2026-07-10. These resolutions are
binding and override the encoded defaults where they differ (#2 and #4). The same
resolutions are recorded machine-readably in `human_resolutions` of the consensus JSON.

1. **workspace API-contract/cross-repo-topology half** → **DELETE.** Nothing migrates; the
   workspace skill directory is removed once the repo-picker half lands in what-next
   (iteration 9). Git history is the archive if a real multi-repo need resurfaces.
2. **Deferred single-repo sub-skills** → **STAGE AS `status: draft`** (overrides the encoded
   drop default). Each of the 13 items is authored as a thin draft stub inside its owning
   bundle per the JSON mapping (go-development, fastapi-htmx, python-app-scaffolds,
   ollama-integration → developer-manager; product-inception-pack, enhancement-bundle →
   project-manager; raw-json-to-domain-panel → design-manager; pdf-document-mining,
   human-review-gate-webui, report-then-apply-merge, rule-based-taxonomy-classifier →
   gated-batch; dropbox-api → ops-manager; TTS/manual-generation → youtube-extraction),
   discoverable via `/search-skill`, promoted to `active` only when a second project needs them.
3. **Global command moves** (code-review, tdd, test-coverage, e2e into quality-manager) →
   **move-with-sweep, names unchanged** (encoded default confirmed).
4. **Phase-gate strictness** → **SOFT GATE** (overrides the encoded hard gate). At iteration
   10 the loop reviews and reports Phase-1 sub-skill firing evidence, then proceeds to
   iteration 11 without stopping to ask.
5. **console-output-style placement** → **design-manager** (encoded default confirmed).

## 5. Implementation Tracker

Each iteration = one feature branch off `dev` → PR → `/ship`. Flip the checkbox in the same
PR as the iteration's work. Full scope per iteration lives in `implementation_order` +
`final_master_skills` of the consensus JSON.

- [x] 0. Charter + ledger (docs-only): routing model, boundary sentences, slug rules, mirror policy, command-namespace registry + generic-verb rule, 142-directory disposition ledger, delete what-next-workspace eval artifacts, correct counts in README/CLAUDE.md
- [x] 1. github pt1: master SKILL.md extension + worktree-task-lifecycle; delete using-git-worktrees, worktree-isolated-loop; parity pass
- [ ] 2. github pt2: pr-splitter + large-asset-vendoring; lift additive-merge-conflict-resolution + crlf-gitattributes-normalization; delete commit-hygiene, accumulated-feature-branch-workflow, pre-pr; /split-pr
- [ ] 3. github pt3: /sync-dev + /changelog-preview; extend ship/merge/release/release-init/prune/publish; regenerate diagram; /push-skill github
- [ ] 4. skills-manager pt1: skill-parity-guard + installed-copy-sweep; /sweep-installed-copies; extend /audit-skills; retire /backfill-diagrams; CLAUDE.md command table
- [ ] 5. skills-manager pt2: lifecycle-operations restructure + external-skill-intake (absorb superpowers-overrides) + mirror policy + /skill-rollout, /scout-external-skills, /claude-md-skill-list-sync; push to global
- [ ] 6. project-manager pt1: master SKILL.md + session-handoff + /handoff (alias /continue-new-session); delete session-management, state-file-driven-multi-turn-resumption, recursive-batch-handoff
- [ ] 7. project-manager pt2: loop-prompt-composer + backlog-burndown + /loop-prompt + /burndown; delete self-paced-loop-iteration, iterative-development
- [ ] 8. project-manager pt3: orchestrator-bookkeeping + learnings-ledger + /log-learning
- [ ] 9. project-manager pt4: backfill-features + operator-runbook-authoring + what-next move with workspace mode; push to global
- [ ] 10. Fleet sweep #1 across C:\development for all Phase-1 deletions/renames — **SOFT GATE (resolved 2026-07-10): review + report Phase-1 sub-skill firing evidence, then proceed to iteration 11 without blocking**
- [ ] 11. agent-manager pt1: bundle head + session-jsonl-toolkit + /search-sessions + /token-report
- [ ] 12. agent-manager pt2: fleet-repo-fanout + stalled-agent-recovery + llm-json-output-repair + /fleet-fanout + /recover-agent
- [ ] 13. agent-manager pt3: binpacked-batch-dispatch + history-mining-pipeline + parallel-workstream-launcher + agent-coordination + agent-runtime-config + mcp-wiring-verification; push to global
- [ ] 14. quality-manager pt1: bundle head + code-review merge (4 skills) + security-review + tdd + e2e-playwright; command moves with fleet sweep
- [ ] 15. quality-manager pt2: visual-verify-loop + container-smoke-test + audit-gate + fix-start + code-deduplication + compliance-gate-authoring + /diagnose-runbook; push to global
- [ ] 16. ops-manager pt1: bundle head + idempotent-apply-script + diagnostics-probe + diagnostic-ladders + /apply-script + /probe-incident
- [ ] 17. ops-manager pt2: service-lifecycle + internal-registry-deploy + secrets-ops (/get-secret) + observability-dashboards + gpu-placement + fleet-host-onboarding + commands
- [ ] 18. ops-manager pt3: shared-runtime-extraction + shell-fleet-migration + /extract-runtime; thin AC_OPBTA installed index; push to global
- [ ] 19. developer-manager: router head + powershell + dotnet-wpf + local-dev-harness + relocated pattern sub-skills + /start-app rewire; push to global
- [ ] 20. Stack-skill description pass: in-place frontmatter improvements for 34 standalone stack skills (batched 2-3 PRs)
- [ ] 21. design-manager pt1: bundle head + logo-pipeline (absorb ac-logo + logo-restylizer) + frontend-aesthetics + ui-standards merge (delete 4 + fleet reference rewrite)
- [ ] 22. design-manager pt2: design-token-pipeline + design-system-alignment + design-parity + screenshot-ux-review + html-mockup-prototyper + brand-extraction + console-output-style + commands; push to global
- [ ] 23. youtube-extraction extension: reconcile flat/bundle duplicates (delete 7 flat copies) + channel-tracker + talk-extraction + prd-forensics + commands; /update-skill sweep for 4 repos
- [ ] 24. gated-batch: new skill + /batch-run + /rename-files
- [ ] 25. utilities-manager: bundle head + windows sub-skills + installer-lifecycle + credential-onboarding + fleet-cp1252 + guide-assistant + commands; push to global
- [ ] 26. Closeout: final fleet sweep, full /audit-skills parity run, disposition-ledger reconciliation, count corrections, memory rollout note

## 6. Kickoff Prompt

Paste into a fresh session (or run under `/loop`) to execute one iteration per pass:

```
In C:\development\ai-agent-kit: read docs/reports/2026-07-10-master-skills-consensus-plan.md
(the map) and docs/reports/2026-07-10-master-skills-consensus.json (the implementation
contract — final_master_skills carries every sub-skill/command definition and constraint note).

Execute the FIRST unchecked iteration in "## 5. Implementation Tracker":
1. git checkout dev && git pull; create branch refactor/<iteration-slug> off dev.
2. Implement exactly what the consensus JSON specifies for this iteration's bundle(s). Honor
   every "notes" constraint: slug rules, verbatim boundary sentences, the
   "Sub-skill of `<master>`." description convention, diagram.html, README + manifest parity,
   and any fleet /update-skill sweep named for this iteration.
3. Before deleting any skill, verify its content is absorbed per the JSON; git history is the
   archive of record.
4. Flip this iteration's checkbox in the plan doc on the same branch.
5. /ship the branch to dev.
6. Open decisions (§4 of the plan): all five are RESOLVED (2026-07-10) — apply the recorded
   resolutions, which override encoded defaults where they differ: delete the workspace
   API-contract half; stage the 13 deferred sub-skills as status: draft stubs in their owning
   bundles; move the quality commands with sweep; soft gate; console-output-style →
   design-manager. See also human_resolutions in the consensus JSON.
7. SOFT GATE: after iteration 10 ships, compile and report Phase-1 sub-skill firing evidence
   in the iteration summary, then continue to iteration 11 without stopping to ask.
8. End your turn by emitting this same prompt verbatim as the copy-ready prompt for the next
   iteration.
```
