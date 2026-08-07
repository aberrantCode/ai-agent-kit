---
title: Command-Namespace Registry
date: 2026-07-10
status: binding
owner: skills-manager
source: docs/reports/2026-07-10-master-skills-consensus.json (implementation contract)
---

# Command-Namespace Registry

All slash commands share **one global namespace**: global commands (`claude/commands/`),
bundle commands (`claude/skills/<bundle>/commands/`), repo-local commands
(`.claude/commands/`), plugin commands, and CLI built-ins. Before adding any command, check
this registry; a new name must not collide with anything here. Built-ins and plugins win
collisions — that is why no `/verify` ships ([charter §4](charter.md#4-single-owners)).

## The Generic-Verb Rule

A command name must be a **specific verb–object pair** (or an established proper noun).
Bare generic verbs are banned — they misfire on everyday phrasing ("apply this change" must
not trigger `/apply`). Renames already applied by the board under this rule:

| Rejected name | Shipped name | Reason |
|---|---|---|
| `/apply` | `/apply-script` | "apply" collides with everyday edit requests |
| `/probe` | `/probe-incident` | bare verb, ambiguous target |
| `/dashboard` | `/add-dashboard` | bare noun, no verb |
| `/next-action-handoff` | `/handoff` | verb-first shortening (still specific) |
| `/backlog-burndown` | `/burndown` | verb-first shortening (still specific) |
| `/capture` | `/pm-capture` | bare verb; namespaced to the project-manager bundle (PM lifecycle redesign) |
| `/groom` | `/pm-groom` | bare verb; namespaced to the project-manager bundle (PM lifecycle redesign) |
| `/task` | `/pm-task` | bare noun; namespaced (the [PM Lifecycle Redesign spec](../reports/2026-07-16-pm-lifecycle-redesign.review.md), [§2.4](../reports/2026-07-16-pm-lifecycle-redesign.review.md#24-new--changed-commands), uses `/pm-task` as the example) |
| `/retro` | `/pm-retro` | bare noun; namespaced to the project-manager bundle (PM lifecycle redesign) |
| `/verify` | *(none)* | built-in verify skill + superpowers own the trigger |
| `/init` | `/init-repo` | collides with the Claude Code **built-in** `/init` (scaffolds CLAUDE.md); built-ins win collisions silently, so `/init` would never reach the github bundle. Natural-language triggers ("init the repo", "initialize this repo") are registered on the sub-skill instead, so the spoken form still works. |

Verb-first names ratified: `/handoff`, `/burndown`, `/loop-prompt`, `/apply-script`,
`/probe-incident`, `/add-dashboard`, `/search-sessions`.

> **▣ Diagram —** per-command lifecycle: unassigned → global → bundle-owned, or → cut *(type: state)* — [view](diagrams/command-lifecycle.html)

## Current Global Commands (25, `claude/commands/`)

| Command | Final owner | Change |
|---|---|---|
| `/code-review` | quality-manager | moves into bundle, name unchanged, fleet sweep (iter 14; [resolution #3](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)) |
| `/tdd` | quality-manager | moves, name unchanged, fleet sweep (iter 14) |
| `/test-coverage` | quality-manager | moves, name unchanged, fleet sweep (iter 14) |
| `/e2e` | quality-manager | moves, name unchanged, fleet sweep (iter 14) |
| `/start-app` | developer-manager | rewired to local-dev-harness; gains generation mode (iter 19) |
| `/skills-manager` | skills-manager | already bundle-owned; global copy reconciled (iter 4–5) |
| `/analyze-repo` | *(unassigned — global)* | review at closeout (iter 26) |
| `/analyze-workspace` | *(unassigned — global)* | review at closeout; workspace skill is deleted ([resolution #1](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)) |
| `/build-fix` | *(unassigned — global)* | review at closeout |
| `/check-contributors` | *(unassigned — global)* | review at closeout |
| `/diagnose` | *(unassigned — global)* | review at closeout; note quality-manager's `/diagnose-runbook` GENERATES repo-local `/diagnose` commands |
| `/diff-review` | *(unassigned — global)* | visual-explainer companion; stays global |
| `/fact-check` | *(unassigned — global)* | visual-explainer companion; stays global |
| `/generate-slides` | *(unassigned — global)* | visual-explainer companion; stays global |
| `/generate-web-diagram` | *(unassigned — global)* | visual-explainer companion; stays global |
| `/plan-review` | *(unassigned — global)* | visual-explainer companion; stays global |
| `/project-recap` | *(unassigned — global)* | visual-explainer companion; stays global |
| `/initialize-project` | *(unassigned — global)* | review at closeout vs project-manager `/init-project` overlap |
| `/new-action` | *(unassigned — global)* | review at closeout |
| `/plan` | *(unassigned — global)* | review at closeout |
| `/refactor-clean` | *(unassigned — global)* | review at closeout |
| `/sync-contracts` | *(unassigned — global)* | review at closeout |
| `/update-code-index` | *(unassigned — global)* | review at closeout |
| `/update-codemaps` | *(unassigned — global)* | review at closeout |
| `/update-docs` | *(unassigned — global)* | review at closeout |

*The 11 rows above marked "review at closeout" with no settled owner are backlog, not current-state fact — see [`docs/backlog.md`](../backlog.md) for the live intake queue; they stay listed here for reorg completeness and are not deleted.*

## Current Bundle Commands

| Command | Bundle today | Final owner | Change |
|---|---|---|---|
| `/commit` `/ship` `/merge` `/release` `/release-init` `/prune` `/publish` | github | github | extended in place (iters 1–3), names unchanged |
| `/init-repo` | github | github | **new** — repo-configuration provisioning pass (Repo-Configuration Standard). Verb-first per the Generic-Verb Rule; `/init` rejected as a built-in collision (see above) |
| `/repo-status` | github | github | **new** (2026-08-02) — read-only repo-state inspection: working tree, branch tracking, worktrees, open PRs, and merged-stale branches, ending with a recommendation for which of ship/merge/release/prune applies next. Never mutates state; object-first name per the Generic-Verb Rule, sibling of `/repo-color` and `/init-repo`. |
| `/add-feature` `/analyze-features` `/analyze-parallelism` `/continue-tasks` `/init-features` `/init-project` `/iterate-tasks` `/reinit` `/review-tasks` `/sync-status` `/sync-tracker` `/update-tasks` | project-manager | project-manager | unchanged (standalone add-feature skill merges into the bundle sub-skill, iter 9) |
| `/continue-new-session` | project-manager | project-manager | kept as back-compat **alias** of new `/handoff` (iter 6) |
| `/audit-skills` `/find-skills` `/import-skill` `/install-skill` `/push-skill` `/search-skill` `/sync-skill` `/update-skill` | skills-manager | skills-manager | extended in place (iters 4–5), names unchanged |
| `/backfill-diagrams` | skills-manager | skills-manager | **retired** into skill-parity-guard fix mode (iter 4) |
| `/find-logo` `/generate-logo` `/reskin-logo` `/archive-logo` | ac-logo | design-manager `logo-pipeline` | move with bundle absorption, **names unchanged** (iter 21); `/reskin-logo` gains logo-restylizer's variant engine |
| `/what-next` `/what-next-update` | what-next | project-manager | move into bundle unchanged (iter 9) |
| `/fix-start` | fix-start | quality-manager | moves with generalization (iter 15) |
| `/feature-start` | feature-start | — | **cut**: merges into `/add-feature` (iter 9) |
| `/pre-pr` | pre-pr | — | **cut**: generic gates fold into github `ship` (iter 2) |
| `/retro-fit-spec` | retro-fit-spec | — | **cut**: absorbed by project-manager `backfill-features` → `/backfill-features` (iter 9) |
| `/spec-align` | spec-align | — | **cut**: absorbed by `backfill-features` gap-analysis mode (iter 9) |
| `/recreate-files` | youtube-extraction | youtube-extraction | unchanged |
| `/add-remote-installer` | add-remote-installer (skill) | utilities-manager | skill demoted to bundle command (iter 25) |
| `/handoff` `/dispatch-session-prompt` `/hand-off-audit` | session-handoff | session-handoff | **retired + merged** (2026-08-03) — `continue-new-session-prompt` and `compliance-audit` (the latter never previously archived) merged into one umbrella bundle `session-handoff`, addressed via the harness's `parent:child` sub-skill naming: `session-handoff:handoff` (was `continue-new-session-prompt`, owns `/handoff`, `/dispatch-session-prompt`) and `session-handoff:audit` (was `compliance-audit`, still owns `/hand-off-audit`). Both predecessor skills retired from the global profile the same day; see [PR #148](https://github.com/aberrantCode/ai-agent-kit/pull/148). **Command renamed 2026-08-04**: `/continue-new-session-prompt` → `/handoff` (the slash-command file itself was never renamed in the earlier merge, only the skill invocation, so `/handoff` was unrecognized until this rename). **`/repo-color` extracted 2026-08-05** to the new `spawn-terminal` bundle (row below), together with the tab-color scripts and the generic terminal-launch core `handoff` now delegates to. |
| `/spawn-terminal` `/repo-color` | spawn-terminal | spawn-terminal | **new** (2026-08-05) — generic Windows-Terminal spawn core extracted from `session-handoff:handoff`'s launcher: opens a new tab running an arbitrary command or script, in a chosen folder, colored per-repo, optionally full-screen. `/spawn-terminal` is an object-first verb pair per the Generic-Verb Rule. `/repo-color` moved here from `session-handoff` (it drives the per-repo tab-color registry, which now lives with this bundle's `resolve-repo-color.ps1` / `manage-repo-colors.ps1` / `demo-repo-tabs.ps1`). `handoff`'s `launch-claude-session.ps1` is now a thin Claude specialization that delegates to `spawn-terminal.ps1`. |
| `/work-resume` `/work-resume-auto` `/work-report` `/work-scan` | work-resume | work-resume | **new** (2026-07-30) — conversation-resumption bundle; scans a repo's recent sessions across all worktree conventions, reconstructs what each expected next, reconciles against git, and proposes the next action. Object-first names each carry a specific verb (resume/report/scan) per the Generic-Verb Rule. Distinct from project-manager's plan-oriented `/what-next` and the cut `/search-sessions` (this is resume-scoped, not a generic history search). |
| `/startup-cost` | startup-context-audit | startup-context-audit | **new** (2026-08-07) — read-only measurement of a session's startup (first-turn) context cost: decomposes the current repo's fresh baseline into readable on-disk instructions vs. the non-visible harness, then tables recent repos. Specific compound-noun name (a sibling of `/repo-status`), not a bare generic verb per the Generic-Verb Rule. Distinct from `usage-limit-reducer`'s planned agent-manager `/token-report` (that reports *historical* burn; this reports the *per-session baseline*). |
| `/update-service` (alias `/opbta-update`) | opbta-service | ops-manager | **new** (2026-08-02) — global command dispatching the `opbta-service` skill's **update** operation; cwd is the source-repo context, resolved via the `.opbta-service` breadcrumb. Ships the planned ops-manager `/update-service` (iter 17 row below) early through the precursor `opbta-service` skill as **interim owner**; `/opbta-update` is a back-compat alias matching the skill's documented `/opbta-*` family. Absorbed by ops-manager at reorg iter 17. |

Repo-local `.claude/commands/` copies of the skills-manager commands are installed
duplicates, not separate names.

## Planned New Commands (by owning bundle and iteration)

| Command | Bundle | Iter |
|---|---|---|
| `/split-pr` | github | 2 |
| `/sync-dev`, `/changelog-preview` | github | 3 |
| `/sweep-installed-copies` | skills-manager | 4 |
| `/skill-rollout`, `/scout-external-skills`, `/claude-md-skill-list-sync` | skills-manager | 5 |
| `/handoff` (alias `/continue-new-session`) | project-manager | 6 |
| `/burndown`, `/loop-prompt` | project-manager | 7 |
| `/log-learning` | project-manager | 8 |
| `/backfill-features` | project-manager | 9 |
| `/search-sessions`, `/token-report` | agent-manager | 11 |
| `/fleet-fanout`, `/recover-agent` | agent-manager | 12 |
| `/launch-workstreams`, `/mine-history`, `/verify-mcp` | agent-manager | 13 |
| `/dependency-security-review` | quality-manager | 14 |
| `/smoke-test`, `/compliance-gate`, `/diagnose-runbook` | quality-manager | 15 |
| `/apply-script`, `/probe-incident` | ops-manager | 16 |
| `/add-service`, `/update-service`, `/retire-service`, `/deploy-internal`, `/add-host`, `/get-secret`, `/add-dashboard` | ops-manager | 17 |
| `/extract-runtime` | ops-manager | 18 |
| `/align-to-design-system`, `/screenshot-review`, `/design-parity`, `/codify-design-laws`, `/mockup` | design-manager | 21–22 |
| `/extract-video-resources`, `/extract-prd`, `/track-channel`, `/extract-talk` | youtube-extraction | 23 |
| `/batch-run`, `/rename-files` | gated-batch | 24 |
| `/clean-workspace`, `/onboard-credentials` | utilities-manager | 25 |

## Project-Manager Lifecycle Redesign — new commands (2026-07-16)

Source: the [PM Lifecycle Redesign spec](../reports/2026-07-16-pm-lifecycle-redesign.review.md) ([§2.4](../reports/2026-07-16-pm-lifecycle-redesign.review.md#24-new--changed-commands), [§3](../reports/2026-07-16-pm-lifecycle-redesign.review.md#3-new--changed-artifacts-at-a-glance)). All four are
`pm-`-prefixed to satisfy the Generic-Verb Rule above (the bare forms are banned generic
verbs/nouns); the spec's §3 "open naming question" is resolved here in favor of the prefix.
Owner: **project-manager** bundle. Sub-skill names are unprefixed (`capture`, `groom`, `task`,
`retro`); the command wrappers carry the prefix.

| Command | Sub-skill | [Build step](../reports/2026-07-16-pm-lifecycle-redesign.review.md#6-suggested-build-order-once-approved) | Status |
|---|---|---|---|
| `/pm-capture` | `capture` | 3 | shipped |
| `/pm-groom` | `groom` | 3 | shipped |
| `/pm-task` | `task` | 4 | shipped |
| `/pm-retro` | `retro` | 6 | shipped |

## Cut Commands (do not reintroduce without a new board ruling)

`/verify` (built-in wins), `/guide`, `/profile-perf`, `/check-mirrors`, `/publish-report`,
`/repo-badge-audit` (folded into release-init), `/branch-sync-audit` (folded into
prune + /sync-dev), `/prototype-git-bootstrap` (mode of publish), `/transpile-skill`,
`/repo-ops-index`, `/init-product`, `/propose-enhancements`, `/apply-ux-feedback` (merged
into `/screenshot-review` batch mode), `/gen-start-app` (mode of `/start-app`),
`/scaffold-cli`, `/dev-proxy`, `/seed-dev` (documented modes of local-dev-harness),
`/triage-console`, `/generate-manual`, `/narrate`, `/repair-video`, utilities' duplicate
`/search-sessions`, duplicate `/get-secret`, `/rotate-secret` (a `--rotate` flag of
`/get-secret`).

Note ([resolution #2](charter.md#8-human-resolutions-erik-2026-07-10--binding-override-encoded-defaults)): the *sub-skills* behind `/init-product` and `/propose-enhancements`
are staged as `status: draft` stubs in project-manager, but the commands stay cut until
promotion.
