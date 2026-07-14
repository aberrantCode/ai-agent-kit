# AI Agent Kit

**The canonical, vendor-agnostic source of truth for one workstation's AI-agent assets** —
skills, commands, reusable prompts, agent instructions, workflows, configurations, and
plugin/addon references — across Claude Code, OpenAI Codex CLI, Google Gemini CLI, and any
future vendor, framework, or product.

Every asset is authored once, lives here, and deploys out to a profile or a project. The flow
is always archive → consumer.

## What it is, who it's for

This is an **archive**, not an application. It holds the knowledge modules an AI coding agent
loads to work well in a given domain, and the automation that moves them around.

- **Using an agent CLI?** Take the [Quick start](#quick-start) — install what you need into
  your profile or into one project.
- **Looking for a particular asset?** Everything is listed in **[`CATALOG.md`](CATALOG.md)**.
- **Adding or changing an asset?** Start with [`CONTRIBUTING.md`](CONTRIBUTING.md), then the
  governance documents below.

## Repository map

```
ai-agent-kit/
├── README.md            # you are here — mission + orientation
├── CATALOG.md           # GENERATED — every asset, every vendor
├── CONTRIBUTING.md      # how to add a skill, a vendor, or a shared asset class
├── manifest.json        # GENERATED — machine-readable source of truth
├── install-skills.ps1   # remote installer; its root path is a published contract
├── claude/              # canonical authoring surface: skills, instructions, commands
├── codex/               # on-demand mirror of the Claude surface
├── gemini/              # frozen mirror
├── shared/              # vendor-neutral: prompts, workflows, configs, plugins
├── scripts/             # lifecycle automation — audit, generate, install, sync
└── docs/                # requirements, plans, and binding reorg governance
```

Vendor directories hold assets bound to one CLI's frontmatter contract and install paths.
`shared/` holds everything that is not: plain markdown or config any vendor's agent can read.

## Quick start

Pick by scope. A **profile install** lands in your CLI's home directory, so every project can
use the asset. A **project install** copies one bundle into one repository, so it travels with
that repo.

### Into your profile

```powershell
irm 'https://raw.githubusercontent.com/aberrantCode/ai-agent-kit/main/install-skills.ps1' | iex
```

The installer is interactive: pick platform, asset type, deploy paths, then browse and select.
Requires PowerShell 5.1+ on Windows, or `pwsh` on macOS and Linux.

**Know what that one-liner does.** It downloads whatever is sitting on this repo's `main`
branch at this moment and executes it as you, unreviewed. There is no version pin and no
integrity check in it. You are trusting this repo's `main`, GitHub's content CDN, and the
timing of your own request.

**To extend less trust than that:** clone the repo, read `install-skills.ps1`, and run it
locally — or pin the raw URL to a commit SHA instead of `main`, so the content cannot change
underneath you. [`scripts/README.md`](scripts/README.md) spells out both, plus the checksum
check to run against tagged releases once releases publish a SHA256.

### Into a single project

`/install-skill <name> <target-dir>` copies a bundle — `SKILL.md` plus any `sub-skills/`,
`commands/`, `references/`, and `rules/` — into that project's `.claude/`, stamping it
`installed-from: ai-agent-kit`. That slash command is not built into your CLI: it ships with
`skills-manager`, which is itself a skill in this archive. Profile-install it once with the
one-liner above and the command is available everywhere.

Prefer no tooling? Clone and copy the bundle directory:

```bash
git clone https://github.com/aberrantCode/ai-agent-kit.git
cp -r ai-agent-kit/claude/skills/typescript your-project/.claude/skills/typescript
```

## The full asset list

**[`CATALOG.md`](CATALOG.md)** — every skill, instruction, command, and shared asset, grouped
by category, with cross-vendor availability. It is generated from `manifest.json`; both are
produced by `scripts/` and never hand-edited.

No tables or counts appear on this page for the same reason: a number written twice is a
number that drifts.

## Conventions

Skill bundles live at `{vendor}/skills/{name}/SKILL.md` and may ship `sub-skills/`,
`commands/`, `references/`, and `rules/` beside it. Frontmatter:

```yaml
---
name: my-skill                      # must equal the directory name
description: One-line, trigger-rich summary
category: Foundations & Workflow    # sole source of category truth
status: active                      # active | draft | deprecated  (optional)
version: 1.0.0                      # semver or ISO date           (optional)
requires: [base]                    # dependency list              (optional)
---
```

- **Regenerate, never hand-edit.** Follow any frontmatter or bundle change with
  `python scripts/generate-manifest.py`, then `pwsh ./scripts/generate-catalog.ps1 -Force`.
- **Check your work.** `pwsh ./scripts/audit.ps1` is the read-only health check.
- **Delete superseded assets.** Git history is the archive of record; `deprecated` is a
  transient "scheduled for removal" marker, not a permanent tombstone.
- **Branch, then PR.** Feature branch off `dev`, PR back to `dev`; never push to either
  directly.

## Governance

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to add a skill, a vendor, or a shared asset class.
- [`docs/reorg/charter.md`](docs/reorg/charter.md) — **binding** for anything touching skill
  structure; it wins over everything else here.
- [`docs/requirements/canonical-repo.md`](docs/requirements/canonical-repo.md) — what this
  repo's structure must satisfy, and why.
- [`docs/plans/canonical-repo-plan.md`](docs/plans/canonical-repo-plan.md) — the restructure
  task list and acceptance criteria.
- [`scripts/README.md`](scripts/README.md) — every script, its status, and the full installer
  trust model.
