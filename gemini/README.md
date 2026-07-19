# gemini/

Frozen mirror of `claude/` for Google Gemini CLI (charter §5). Gemini is **frozen at its
current set of skills** — new Claude skills are not automatically mirrored here, and growing
this set is a deliberate, manual decision, not a default.

## `skills/<name>/SKILL.md`

Same bundle-anatomy conventions as `claude/skills/` (see `claude/README.md`) apply to the
skills mirrored here, minus any Claude-Code-specific tool syntax. Each mirrored skill carries
a **source-version stamp** referencing the Claude skill and version it was frozen from, so
staleness can be flagged (charter §5). `/audit-skills` reports the Claude↔Gemini gap
**informationally** — this tree is expected to lag `claude/skills/` by design.

## `instructions/`

**Mirror policy: TBD (OQ4).** Gemini currently has 3 agent instructions, undocumented in any
count table prior to this effort. The mirroring rule for instructions has not been ruled on —
see `docs/requirements/canonical-repo.md` OQ4. Do not invent a policy here; catalog generation
must still include these files once `CATALOG.md` ships (T6).

## Conventions

- Never move, rename, or delete anything under `skills/` outside the reorg charter process.
- Do not hand-maintain a skill count in this file — it drifts from `manifest.json`/`CATALOG.md`
  (G5). If the frozen set changes, that is a deliberate skill-tree decision routed through the
  reorg charter, not an edit made here.
