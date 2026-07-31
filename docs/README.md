# docs/

Requirements, plans, reorg governance, and point-in-time reports for work on this repo itself
(not skill content).

## Index

| Area | What's there |
|---|---|
| [`requirements/`](requirements/) | Approved requirements docs — binding scope for a body of work |
| [`plans/`](plans/) | Implementation plans that execute a requirements doc |
| [`reorg/`](reorg/) | Binding governance for the master-skills reorganization |
| [`workflow/`](workflow/) | Durable process references (SDLC, focus rules, scope manifest, runners) |
| [`features/`](features/) | Feature specs — scope authority for project-manager work |
| [`tasks/`](tasks/) | In-flight (`active/`) and completed (`archive/`) task files |
| [`issues/`](issues/) | Logged failures and blockers |
| [`reports/`](reports/) | Point-in-time audit/consensus artifacts, dated |
| [`backlog.md`](backlog.md) | Intake for not-yet-scheduled bugs, chores, debt, and ideas |
| [`STATUS.md`](STATUS.md) | Single entry point for "what's outstanding, what's next" |
| [`REQUIREMENTS.md`](REQUIREMENTS.md) | Legacy product-requirements intake (superseded by `requirements/`; kept for existing links) |

## `requirements/`

Approved requirements documents (mission, goals, non-goals, resolved decisions, acceptance
criteria) for a body of work — e.g. [`requirements/canonical-repo.md`](requirements/canonical-repo.md).
A requirements doc is binding once its frontmatter `status:` says so; it names the plan that
implements it via `plan:` in the frontmatter.

## `plans/`

Task-by-task implementation plans that execute a requirements doc — e.g.
[`plans/canonical-repo-plan.md`](plans/canonical-repo-plan.md). Plans reference their governing
requirements doc via `depends-on:` in frontmatter and break work into PR-sized tasks.

## `reorg/` — binding governance

[`reorg/charter.md`](reorg/charter.md) is the **binding** Phase-0 governance document for the
master-skills reorganization: every skill PR must conform to it, and it overrides individual
bundle drafts where they disagree. Companion files:

- [`reorg/disposition-ledger.md`](reorg/disposition-ledger.md) — one binding row per skill
  directory, flipped to `done` by the owning PR.
- [`reorg/command-namespace-registry.md`](reorg/command-namespace-registry.md) — every
  current/planned/cut command, its owner, and the generic-verb rule.

Nothing outside this subtree may restructure, rename, or delete a skill directory — that
authority belongs solely to the charter process (a [non-goal of the repo standard](requirements/canonical-repo.md#non-goals)).

## `workflow/`

Durable process reference for how this repo's own work is planned and executed — not
per-feature content. Includes [`workflow/SDLC.md`](workflow/SDLC.md) (CAP-ID Feature
Abbreviation Registry), [`workflow/FOCUS.md`](workflow/FOCUS.md), [`workflow/scope-manifest.md`](workflow/scope-manifest.md),
[`workflow/runners.md`](workflow/runners.md), and [`workflow/INDEX.md`](workflow/INDEX.md) (the
durable decisions/discoveries log for project-manager work).

## `features/`

Feature specs — the scope authority for project-manager work — plus the canonical
[`features/template.md`](features/template.md). See [`features/README.md`](features/README.md)
for the index.

## `tasks/`

One file per unit of implementation work: [`tasks/active/`](tasks/active/) for in-flight tasks,
[`tasks/archive/`](tasks/archive/) for completed ones, plus [`tasks/template.md`](tasks/template.md).
See [`tasks/README.md`](tasks/README.md).

## `issues/`

Logged failures and blockers surfaced during implementation.

## `reports/`

Point-in-time artifacts — consensus documents, audit snapshots, dated reports — that inform
requirements/plans but are not themselves binding once superseded. Filenames are
date-prefixed (`YYYY-MM-DD-<topic>.md` or `.json`).

[`reports/2026-04-09-skills-rationalization.md`](reports/2026-04-09-skills-rationalization.md) is
a historical report (2026-04-09 skills-archive rationalization) that predates this `reports/`
convention but now lives here under a date-prefixed name, per the convention above.

## `backlog.md`

Intake for not-yet-scheduled work — the single front door for bugs, chores, debt, and ideas.
See also [`backlog-archive.md`](backlog-archive.md) for resolved/promoted entries.

## `STATUS.md`

Single entry point for "what is outstanding, and what should happen next?" — see
[`STATUS.md`](STATUS.md).

## Conventions

- A requirements doc and its plan are a pair; keep `depends-on:`/`plan:` frontmatter links
  current when either moves or is renamed.
- Reports are historical record — do not edit a report to reflect new decisions; supersede it
  with a new dated report and update whichever requirements/plan doc references it.
