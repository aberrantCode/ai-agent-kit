# claude/

Canonical authoring surface for Claude Code assets — this tree is the single source of
truth, per the [canonical-repo requirements](../docs/requirements/canonical-repo.md).

> **▣ Diagram —** vendor mirror flow: claude (canonical) → codex (on-demand mirror) →
> gemini (frozen mirror), with /audit-skills detecting staleness *(type: flow)*

Everything here is authored first; `codex/` and `gemini/` are stamped mirrors, never the
other way around, per the [reorg charter's cross-CLI mirror
policy](../docs/reorg/charter.md). Counts are not hardcoded here — see
`manifest.json` / [`CATALOG.md`](../CATALOG.md), generated per the [single-sourced-facts
requirement](../docs/requirements/canonical-repo.md).

## `skills/<name>/` — bundle anatomy

Each skill is a directory under `skills/`. Required and optional members:

| Member | Required | Purpose |
|---|---|---|
| `SKILL.md` | yes | Frontmatter (`name`, `description`, `status`, `version`, `requires`, `installed-from`, `category` — see root [`CLAUDE.md`](../CLAUDE.md)) + body content. |
| `sub-skills/<name>/` | no | Delegate sub-skills with their own `SKILL.md`, triggering independently, per the charter's [routing-and-triggering model](../docs/reorg/charter.md). Each sub-skill description opens with the exact prefix `` Sub-skill of `<master>`. `` |
| `commands/` | no | Slash commands bundled *with this skill* — distinct from `claude/commands/` (see below). |
| `references/` | no | Reference material the skill loads on demand; not auto-loaded into context. |
| `rules/` | no | Rule sets the skill applies. |
| `diagram.html` | no | Generated visual diagram (`/backfill-diagrams`). |
| `evals/` | no | Benchmark/eval harness output; only summarized benchmarks under `evals/benchmarks/` are tracked (see [`.gitignore`](../.gitignore)). |

Skill-tree structure (bundle composition, absorptions, deletions, renames) is governed
exclusively by the [reorg charter](../docs/reorg/charter.md) and the [disposition
ledger](../docs/reorg/disposition-ledger.md) — this README documents anatomy, not
disposition, a distinction related to (but narrower than) the [no-skill-tree-restructuring
non-goal](../docs/requirements/canonical-repo.md).

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

- Never move, rename, or delete anything under `skills/` outside the [reorg charter](../docs/reorg/charter.md) process.
- New skills get `category:` frontmatter, per the [category-source-of-truth
  decision](../docs/requirements/canonical-repo.md) — read by
  [`scripts/generate-manifest.py`](../scripts/generate-manifest.py).
- Installed copies elsewhere carry `installed-from: ai-agent-kit` (legacy: `llm_skills`).
