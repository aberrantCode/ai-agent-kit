# codex/

On-demand mirror of `claude/` for OpenAI Codex CLI (charter §5). The cross-CLI transpiler is
cut — mirrors are created manually, only when a skill is actually used from Codex, not
generated automatically from every Claude skill.

## `skills/<name>/SKILL.md`

Same bundle-anatomy conventions as `claude/skills/` (see `claude/README.md`) apply where a
Codex mirror exists, minus any Claude-Code-specific tool syntax. Every mirror carries a
**source-version stamp** referencing the Claude skill and version it was mirrored from, so
`skill-parity-guard` / `/audit-skills` can flag staleness (charter §5). `/audit-skills`
reports the Claude↔Codex gap **informationally** — an incomplete mirror set is expected, not
a failure.

## `instructions/`

**Mirror policy: TBD (OQ4).** Codex currently has 3 agent instructions, undocumented in any
count table prior to this effort. The mirroring rule for instructions (on-demand like skills,
frozen like Gemini, or something else) has not been ruled on — see
`docs/requirements/canonical-repo.md` OQ4. Do not invent a policy here; catalog generation
must still include these files once `CATALOG.md` ships (T6).

## Conventions

- Never move, rename, or delete anything under `skills/` outside the reorg charter process.
- Do not hand-maintain a mirror-coverage count in this file — `/audit-skills` reports the gap
  informationally at runtime.
- A mirror is stale content the moment its source-version stamp falls behind the Claude
  original; re-mirror on demand rather than eagerly.
