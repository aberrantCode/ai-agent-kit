# gemini/

Frozen mirror of [`claude/`](../claude/README.md) for Google Gemini CLI, per the reorg
charter's [cross-CLI mirror policy](../docs/reorg/charter.md). Gemini is
**frozen at its current set of skills** — new Claude skills are not automatically mirrored
here, and growing this set is a deliberate, manual decision, not a default.

> **▣ Diagram —** vendor mirror flow: claude (canonical) → codex (on-demand mirror) →
> gemini (frozen mirror), with /audit-skills detecting staleness *(type: flow)* —
> [view](diagrams/vendor-mirror-flow.html)

## `skills/<name>/SKILL.md`

Same bundle-anatomy conventions as `claude/skills/` (see [`claude/README.md`](../claude/README.md))
apply to the skills mirrored here, minus any Claude-Code-specific tool syntax. Each mirrored
skill carries a **source-version stamp** referencing the Claude skill and version it was
frozen from, so staleness can be flagged, per the [mirror
policy](../docs/reorg/charter.md). `/audit-skills` reports the Claude↔Gemini gap
**informationally** — this tree is expected to lag `claude/skills/` by design.

## `instructions/`

**Mirror policy: not yet decided** — this is the [open question on Codex/Gemini
instruction mirroring](../docs/requirements/canonical-repo.md). Gemini currently has 3
agent instructions, undocumented in any count table prior to this effort. The mirroring rule
for instructions has not been ruled on — see the [canonical-repo
requirements](../docs/requirements/canonical-repo.md). Do not invent a policy here;
catalog generation must still include these files once `CATALOG.md` ships, per the
[catalog-generation task](../docs/plans/canonical-repo-plan.md).

## Conventions

- Never move, rename, or delete anything under `skills/` outside the [reorg
  charter](../docs/reorg/charter.md) process.
- Do not hand-maintain a skill count in this file — it drifts from `manifest.json`/`CATALOG.md`,
  per the [single-sourced-facts requirement](../docs/requirements/canonical-repo.md). If
  the frozen set changes, that is a deliberate skill-tree decision routed through the reorg
  charter, not an edit made here.
