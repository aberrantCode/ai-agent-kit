# codex/

On-demand mirror of [`claude/`](../claude/README.md) for OpenAI Codex CLI, per the reorg
charter's [cross-CLI mirror policy](../docs/reorg/charter.md).

> **▣ Diagram —** vendor mirror flow: claude (canonical) → codex (on-demand mirror) and
> claude (canonical) → gemini (frozen mirror), with /audit-skills detecting staleness *(type: flow)* —
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

**Mirror policy: not yet decided** — see [OQ4 in the canonical-repo
requirements](../docs/requirements/canonical-repo.md#open-questions). Existing instructions
are included in the generated [`CATALOG.md`](../CATALOG.md); catalog coverage does not
settle their mirroring policy. Do not infer an instruction policy from the skill policy.

## Conventions

- Never move, rename, or delete anything under `skills/` outside the [reorg
  charter](../docs/reorg/charter.md) process.
- Do not hand-maintain a mirror-coverage count in this file — `/audit-skills` reports the gap
  informationally at runtime.
- A mirror is stale content the moment its source-version stamp falls behind the Claude
  original; re-mirror on demand rather than eagerly.
