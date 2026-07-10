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
collisions — that is why no `/verify` ships (charter §4).

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
| `/verify` | *(none)* | built-in verify skill + superpowers own the trigger |

Verb-first names ratified: `/handoff`, `/burndown`, `/loop-prompt`, `/apply-script`,
`/probe-incident`, `/add-dashboard`, `/search-sessions`.

## Current Global Commands (25, `claude/commands/`)

| Command | Final owner | Change |
|---|---|---|
| `/code-review` | quality-manager | moves into bundle, name unchanged, fleet sweep (iter 14; resolution #3) |
| `/tdd` | quality-manager | moves, name unchanged, fleet sweep (iter 14) |
| `/test-coverage` | quality-manager | moves, name unchanged, fleet sweep (iter 14) |
| `/e2e` | quality-manager | moves, name unchanged, fleet sweep (iter 14) |
| `/start-app` | developer-manager | rewired to local-dev-harness; gains generation mode (iter 19) |
| `/skills-manager` | skills-manager | already bundle-owned; global copy reconciled (iter 4–5) |
| `/analyze-repo` | *(unassigned — global)* | review at closeout (iter 26) |
| `/analyze-workspace` | *(unassigned — global)* | review at closeout; workspace skill is deleted (resolution #1) |
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

## Current Bundle Commands

| Command | Bundle today | Final owner | Change |
|---|---|---|---|
| `/commit` `/ship` `/merge` `/release` `/release-init` `/prune` `/publish` | github | github | extended in place (iters 1–3), names unchanged |
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

Note (resolution #2): the *sub-skills* behind `/init-product` and `/propose-enhancements`
are staged as `status: draft` stubs in project-manager, but the commands stay cut until
promotion.
