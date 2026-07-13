# claude/

Canonical authoring surface for Claude Code assets (D1, `docs/requirements/canonical-repo.md`
§4). Everything here is authored first; `codex/` and `gemini/` are stamped mirrors, never the
other way around (charter §5). Counts are not hardcoded here — see `manifest.json` /
`CATALOG.md` (generated, D2/G5).

## `skills/<name>/` — bundle anatomy

Each skill is a directory under `skills/`. Required and optional members:

| Member | Required | Purpose |
|---|---|---|
| `SKILL.md` | yes | Frontmatter (`name`, `description`, `status`, `version`, `requires`, `installed-from`, `category` — see root `CLAUDE.md`) + body content. |
| `sub-skills/<name>/` | no | Delegate sub-skills with their own `SKILL.md`, triggering independently. Each sub-skill description opens with the exact prefix `` Sub-skill of `<master>`. `` (charter §1). |
| `commands/` | no | Slash commands bundled *with this skill* — distinct from `claude/commands/` (see below). |
| `references/` | no | Reference material the skill loads on demand; not auto-loaded into context. |
| `rules/` | no | Rule sets the skill applies. |
| `diagram.html` | no | Generated visual diagram (`/backfill-diagrams`). |
| `evals/` | no | Benchmark/eval harness output; only summarized benchmarks under `evals/benchmarks/` are tracked (see `.gitignore`). |

Skill-tree structure (bundle composition, absorptions, deletions, renames) is governed
exclusively by `docs/reorg/charter.md` and the disposition ledger — this README documents
anatomy, not disposition (N1).

## `instructions/`

Agent instructions invoked via the Task tool. Frontmatter contract:

```yaml
---
name: <agent-name>
description: <one-line, PROACTIVELY-use guidance>
tools: <comma-separated tool list>
model: <model alias, e.g. opus>
---
```

Body is the system prompt for that agent role.

## `commands/`

Global slash commands available across all skills — distinct from a skill's own
`skills/<name>/commands/`, which only apply when that skill is active. Global commands live
here when they aren't owned by a single skill bundle.

## Conventions

- Never move, rename, or delete anything under `skills/` outside the reorg charter process.
- New skills get `category:` frontmatter (D8) — read by `scripts/generate-manifest.py`.
- Installed copies elsewhere carry `installed-from: ai-agent-kit` (legacy: `llm_skills`).
