# Contributing to ai-agent-kit

This repo is the canonical archive for skills, instructions, commands, and vendor-neutral
assets (see root `README.md`). Every change lands via a feature branch and a PR back to
`dev` — see [Governance](#governance) for the mechanics. The four ways to contribute:

## Add a skill

A skill is a directory under `{vendor}/skills/<name>/`. Frontmatter (`SKILL.md`):

```yaml
---
name: my-skill                      # MUST equal the directory name (audit.ps1 enforces, error)
description: One-line, trigger-rich summary
category: Foundations & Workflow    # sole source of category truth (D8) — see the curated
                                     # CATEGORY_ORDER list in scripts/generate-manifest.py
                                     # for the live set of valid values (15 entries today)
status: active                      # active | draft | deprecated        (optional)
version: 1.0.0                      # semver or ISO date                 (optional)
requires: [base]                    # dependency list                    (optional)
installed-from: ai-agent-kit        # only on copies installed elsewhere, never in the archive
---
```

Bundle layout beside `SKILL.md`, all optional: `sub-skills/<name>/` (own `SKILL.md`,
description prefixed `` Sub-skill of `<master>`. `` per charter §1), `commands/` (slash
commands bundled with this skill only), `references/` (loaded on demand, not auto-context),
`rules/`. See `claude/README.md` for the full bundle anatomy.

**Regeneration duties (never hand-edit `manifest.json` or `CATALOG.md`):** after any
frontmatter or bundle change, run `python scripts/generate-manifest.py` then
`pwsh ./scripts/generate-catalog.ps1 -Force`. Before opening a PR, run
`pwsh ./scripts/audit.ps1` — it is the read-only health check for exactly this class of
mistake (frontmatter validity, name/directory match, category presence, manifest/catalog
staleness).

**Diagrams:** `diagram.html` is optional per skill; regenerate missing ones in bulk with
`/backfill-diagrams` rather than hand-authoring.

Adding a skill to a Codex/Gemini mirror is on-demand only (charter §5) — do this when the
skill is actually needed from that CLI, not preemptively; mirrors carry no `category:` of
their own (they inherit the Claude skill's category by name).

## Add a vendor

A new vendor is a new top-level directory (`{vendor}/`) mirroring `claude/`'s shape —
`skills/`, `instructions/`. Required for a new vendor:

1. `{vendor}/README.md` stating the mirror policy relative to `claude/` (today: Codex
   mirrors are created on demand, Gemini is frozen at its current skill set — charter §5).
2. Manifest support: extend `scripts/generate-manifest.py` to add the platform under
   `manifest.json`'s `platforms` key, then regenerate — never hand-edit the manifest.
3. Regenerate `CATALOG.md` afterward so the new vendor's tables appear.

A new vendor is a structural decision — see [Governance](#governance) before starting.

## Add a shared asset class

`shared/` holds vendor-neutral assets only. An asset qualifies if it "contains no
vendor-specific frontmatter contract, tool syntax, or install-path convention — plain
markdown/config any vendor's agent can consume" (D1, `docs/requirements/canonical-repo.md`
§4). If it needs a vendor's frontmatter schema or install path to function, it belongs
under that vendor's tree instead.

New classes are **README-first**: create `shared/<class>/README.md` — describing purpose,
conventions, and the vendor-neutral test as applied to that class — before any asset lands
in the directory. Then add `shared/<class>` to the class table in `shared/README.md`. Only
after both READMEs exist do actual assets get added.

## Governance

**Reorg-charter precedence.** `docs/reorg/charter.md` is binding for anything touching
skill *structure* — bundle composition, absorptions, deletions, renames (§2 slug rules),
mirror policy (§5), and the parity follow-through every deletion PR must ship (§6: updated
README row, regenerated manifest, diagram add/update/remove). Where this file and the
charter disagree, the charter wins. Never move, rename, or delete anything under
`claude/skills/`, `codex/skills/`, or `gemini/skills/` outside that process.

**Git workflow digest** (full rules: `~/.claude/rules/git-workflow.md`):

- Branch off latest `dev`: `type/short-description` (`feat`, `fix`, `refactor`, `docs`,
  `test`, `chore`, `perf`, `ci`). PR back to `dev` only — never push directly to `dev` or
  `main`.
- Conventional commit messages; PR description = **Summary** + **Test Plan**.
- Warn at 400 changed lines, hard limit 800 — call out generated-file or deletion-heavy
  overages explicitly in the PR body for sign-off.
- `/ship` runs `pwsh ./scripts/validate.ps1` before opening any PR and aborts on a nonzero
  exit (local validation gate — repo `CLAUDE.md`, `scripts/README.md`). Optionally wire the
  same gate as a `pre-push` git hook with `pwsh ./scripts/install-hooks.ps1` (opt-in,
  idempotent).

**Not yet implemented — do not tell a contributor to run these:** `install-to-project.ps1`,
`push-to-profile.ps1`, and `sync-installed.ps1` are documented stubs (`throw "TODO: not
implemented"`). Use the `skills-manager` slash commands (`/install-skill`, `/push-skill`,
`/update-skill`) instead until those scripts land. See `scripts/README.md` for full status.
