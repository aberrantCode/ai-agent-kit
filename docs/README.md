# docs/

Requirements, plans, reorg governance, and point-in-time reports for work on this repo itself
(not skill content).

## `requirements/`

Approved requirements documents (mission, goals, non-goals, resolved decisions, acceptance
criteria) for a body of work — e.g. `canonical-repo.md`. A requirements doc is binding once
its frontmatter `status:` says so; it names the plan that implements it via `plan:` in the
frontmatter.

## `plans/`

Task-by-task implementation plans that execute a requirements doc — e.g.
`canonical-repo-plan.md`. Plans reference their governing requirements doc via `depends-on:`
in frontmatter and break work into PR-sized tasks.

## `reorg/` — binding governance

`docs/reorg/charter.md` is the **binding** Phase-0 governance document for the master-skills
reorganization: every skill PR must conform to it, and it overrides individual bundle drafts
where they disagree. Companion files:

- `disposition-ledger.md` — one binding row per skill directory, flipped to `done` by the
  owning PR.
- `command-namespace-registry.md` — every current/planned/cut command, its owner, and the
  generic-verb rule.

Nothing outside this subtree may restructure, rename, or delete a skill directory — that
authority belongs solely to the charter process (N1, `docs/requirements/canonical-repo.md`).

## `reports/`

Point-in-time artifacts — consensus documents, audit snapshots, dated reports — that inform
requirements/plans but are not themselves binding once superseded. Filenames are
date-prefixed (`YYYY-MM-DD-<topic>.md` or `.json`).

## Conventions

- A requirements doc and its plan are a pair; keep `depends-on:`/`plan:` frontmatter links
  current when either moves or is renamed.
- Reports are historical record — do not edit a report to reflect new decisions; supersede it
  with a new dated report and update whichever requirements/plan doc references it.
