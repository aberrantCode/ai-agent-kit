---
title: Master-Skills Reorganization Charter (Phase 0)
date: 2026-07-10
status: binding
owner: skills-manager
source: docs/reports/2026-07-10-master-skills-consensus.json (implementation contract)
map: docs/reports/2026-07-10-master-skills-consensus-plan.md
---

# Master-Skills Reorganization Charter

This charter is the Phase-0 governance document for the 27-iteration master-skills
reorganization. Every skill PR in the series must conform to it. Where this charter and an
individual bundle draft disagree, this charter wins; where erik's 2026-07-10 human
resolutions (§8) and anything else disagree, the resolutions win.

## 1. Routing and Triggering Model

**Masters are ownership/routing heads, not runtime gates.** A master bundle's `SKILL.md`
declares what the bundle owns and routes between sub-skills; it is never a prerequisite hop
at runtime.

**Sub-skills trigger independently** via their own trigger-rich frontmatter descriptions —
the shipped `github` bundle is the precedent. A user saying "split this PR" must land
directly on `pr-splitter` without the `github` master firing first.

**Convention (mandatory):** every sub-skill description opens with the exact prefix
``Sub-skill of `<master>`.`` followed by its own trigger-rich text.

## 2. Slug Rules

1. **Never rename an installed bundle.** `github`, `project-manager`, `skills-manager`,
   `youtube-extraction`, and all `ac-logo` command names are retained verbatim (extend in
   place). Renaming an installed bundle orphans every installed copy and CLAUDE.md
   reference across the fleet.
2. **Every absorption that deletes a referenced name** ships its fleet `/update-skill`
   sweep + CLAUDE.md reference-rewrite sweep in the same PR series as the deletion.
3. **Git history is the archive of record.** Deleted skill content is never tombstoned with
   `status: deprecated` long-term; verify absorption per the consensus JSON, then delete.

## 3. Boundary Sentences (verbatim)

Each sentence below must appear **verbatim in both SKILL.md files** of its pair:

1. > project-manager owns single-agent multi-turn loop composition and durable state files;
   > agent-manager owns multi-agent dispatch, recovery, and session-JSONL infrastructure.
2. > gated-batch owns per-item data-plane state; project-manager owns session-plane
   > resumption.
3. > quality-manager owns observe-and-judge + pre-ship smoke; developer-manager owns
   > launch; ops-manager owns post-deploy verification.
4. > design-manager owns "is it good"; quality-manager owns "does it work".

Routing corollary for #2: "resume the batch" routes on whether durable per-item state
exists.

## 4. Single Owners

| Concern | Sole owner |
|---|---|
| Session handoff / "give me a prompt for the next session" | project-manager `session-handoff` |
| Session-JSONL parsing + token-efficiency page | agent-manager `session-jsonl-toolkit` |
| Stall/salvage/re-dispatch (`reset --soft`) procedure | agent-manager `stalled-agent-recovery` |
| LLM JSON output repair (`repair_results.py`, UUID-stem merge) | agent-manager `llm-json-output-repair` |
| `/diagnose-runbook` | quality-manager |
| Shell-fleet trio (helper library, migration, skip taxonomy) | ops-manager `shell-fleet-migration` |
| `/get-secret` (operational secrets) | ops-manager `secrets-ops` |
| Plugin-precedence declarations (superpowers, impeccable, interface-design, codex, built-in verify) | skills-manager `external-skill-intake` |
| Worktree lifecycle (incl. OAuth/credential-loss lesson) | github `worktree-task-lifecycle` |
| Big-binary / large-asset policy | github `large-asset-vendoring` |
| repo-local ops-index convention | ops-manager `service-lifecycle` (generation mechanics: skills-manager) |

**No `/verify` command ships** — the built-in verify skill and
superpowers:verification-before-completion own that trigger; quality-manager's sub-skills
are the deep per-surface recipes the built-in routes into.

## 5. Cross-CLI Mirror Policy

The cross-CLI transpiler is **cut**. Instead:

- **Codex mirrors are created on demand** — only when a skill is actually used from Codex.
- **Gemini is frozen at 5 skills.**
- `/audit-skills` reports the Claude↔Codex gap **informationally** (never as a failure).
- Every mirror carries a **source-version stamp** so skill-parity-guard can flag staleness.

## 6. Parity Follow-Through (every deletion PR)

Every PR that deletes or renames a skill must, in the same PR:

1. Remove/update the README row (README parity: every archived skill has a row; every row
   points to a real file).
2. Regenerate `manifest.json` (`scripts/generate-manifest.py`).
3. Add/update/remove `diagram.html` as applicable.
4. Run the installed-copy sweep for affected fleet repos (or schedule it explicitly in the
   same PR series and say so in the PR body).

skill-parity-guard fix mode **proposes but never executes deletions** — curators delete,
never automation.

## 7. Hook Interactions

- **doc-blocker (PreToolUse):** project-manager state files — `progress.md`, `backlog.md`,
  `docs/learnings/`, `docs/alignment/` — are declared **sanctioned outputs**.
- **git-push-opens-Zed (PreToolUse):** any unattended `/burndown` or `/loop` run must
  document how it handles the Zed review hook firing on push.

## 8. Human Resolutions (erik, 2026-07-10 — binding, override encoded defaults)

1. **workspace API-contract half → DELETE.** Nothing migrates; the `workspace` directory is
   removed once the repo-picker half lands in what-next (iteration 9).
2. **13 deferred single-repo sub-skills → STAGE AS `status: draft`** stubs inside their
   owning bundles (overrides the encoded drop default): developer-manager gets
   go-development, fastapi-htmx, python-app-scaffolds, ollama-integration; project-manager
   gets product-inception-pack, enhancement-bundle; design-manager gets
   raw-json-to-domain-panel; gated-batch gets pdf-document-mining, human-review-gate-webui,
   report-then-apply-merge, rule-based-taxonomy-classifier; ops-manager gets dropbox-api;
   youtube-extraction gets the TTS/manual-generation recipes. Discoverable via
   `/search-skill`; promoted to `active` only when a second project needs them. The cut
   *commands* for these items stay cut.
3. **Global command moves** (code-review, tdd, test-coverage, e2e → quality-manager):
   move-with-sweep, names unchanged.
4. **Phase gate → SOFT GATE** (overrides the encoded hard gate): at iteration 10 the loop
   reviews and reports Phase-1 sub-skill firing evidence in the iteration summary, then
   proceeds to iteration 11 without stopping to ask.
5. **console-output-style → design-manager** (ships iteration 22).

## 9. Phases and Gate

- **Phase 1 (P0):** github, project-manager, skills-manager — iterations 1–9, fleet sweep
  at iteration 10 with the soft gate above.
- **Phase 2 (P1):** agent-manager, quality-manager, developer-manager, design-manager,
  ops-manager — iterations 11–22.
- **Phase 3 (P2):** utilities-manager, youtube-extraction extension, gated-batch —
  iterations 23–25, closeout at 26.

## 10. Verified Counts (2026-07-10 audit)

142 Claude skill directories / 84 Codex / 5 Gemini; 25 global slash commands; 15 agent
instructions. The charter PR (iteration 0) deletes `what-next-workspace` (eval artifacts,
not a skill), leaving **141 Claude skill directories**. Count corrections in README/CLAUDE.md
ship in the owning PRs; stale figures are never left standing once an owning PR touches the
surface.

## 11. Companion Documents

- **Disposition ledger** — `docs/reorg/disposition-ledger.md`: one binding row per skill
  directory (142 at audit time), flipped to `done` by the owning PR.
- **Command-namespace registry** — `docs/reorg/command-namespace-registry.md`: every
  current/planned/cut command, its owner, and the generic-verb rule.
