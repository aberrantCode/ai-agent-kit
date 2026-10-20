# codex/

On-demand mirror of [`claude/`](../claude/README.md) for OpenAI Codex CLI, per the reorg
charter's [cross-CLI mirror policy](../docs/reorg/charter.md).

> **▣ Diagram —** vendor mirror flow: claude (canonical) → codex (on-demand mirror) →
> gemini (frozen mirror), with /audit-skills detecting staleness *(type: flow)* —
> [view](diagrams/vendor-mirror-flow.html)

The cross-CLI transpiler is cut — mirrors are created manually, only when a skill is
actually used from Codex, not generated automatically from every Claude skill.

## `skills/<name>/SKILL.md`

Same bundle-anatomy conventions as `claude/skills/` (see [`claude/README.md`](../claude/README.md))
apply where a Codex mirror exists, minus any Claude-Code-specific tool syntax. Every mirror
carries a **source-version stamp** referencing the Claude skill and version it was mirrored
from, so `skill-parity-guard` / `/audit-skills` can flag staleness, per the [mirror
policy](../docs/reorg/charter.md). `/audit-skills` reports the Claude↔Codex gap
**informationally** — an incomplete mirror set is expected, not a failure.

## `instructions/`

**Mirror policy: not yet decided** — this is the [open question on Codex/Gemini
instruction mirroring](../docs/requirements/canonical-repo.md). Codex currently has 3
agent instructions, undocumented in any count table prior to this effort. The mirroring
rule for instructions (on-demand like skills, frozen like Gemini, or something else) has
not been ruled on — see the [canonical-repo requirements](../docs/requirements/canonical-repo.md).
Do not invent a policy here; catalog generation must still include these files once
`CATALOG.md` ships, per the [catalog-generation task](../docs/plans/canonical-repo-plan.md).

## Conventions

- Never move, rename, or delete anything under `skills/` outside the [reorg
  charter](../docs/reorg/charter.md) process.
- Do not hand-maintain a mirror-coverage count in this file — `/audit-skills` reports the gap
  informationally at runtime.
- A mirror is stale content the moment its source-version stamp falls behind the Claude
  original; re-mirror on demand rather than eagerly.
