# Handoff prompt rubric — v2

Supersedes [`rubric.v1.md`](rubric.v1.md) (kept as the historical baseline). v2 changes **scoring and
scoping**, not the underlying list of load-bearing elements — the source of truth is still
[`../../handoff/SKILL.md`](../../handoff/SKILL.md). Driven by the first `handoff-tuner` run
(2026-10-23); see [`tuning-log.md`](tuning-log.md) for the evidence and the before/after numbers.

## What changed from v1 and why

### 1. Floor items no longer drown the craft signal

The v1 composite put ~33% of its weight on three checks that **≈100% of the corpus failed** —
`correlation` (92/92), the YAML frontmatter fields + `frontmatter_complete` (88/92), and `dead_ends`
(88/92). All three are **post-convention requirements newer than almost the entire corpus**, so they
flag a real *universal gap* but do **not** discriminate one prompt from another. A composite they
dominate measures prompt *recency*, not craft: in v1 78 of 92 prompts landed "poor" purely for
lacking conventions that didn't exist when they were written.

v2 marks these items `"floor": true`. The scorer now reports **two** numbers:

- **`composite`** (the band driver) — computed over **non-floor** weight only. This ranks prompts by
  craft the author controlled.
- **`convention_composite`** — computed over everything, including floors. This is the v1-equivalent
  "did it follow the current conventions" number, kept for continuity.

Floor failures are reported in a separate `floor_gaps` list, not folded into the craft failures.

**Effect (same 92 prompts):** average craft composite rose 40.6 → **65.8**; the band distribution
went from poor=78/weak=10/adequate=4 to **poor=13/weak=44/adequate=31/strong=4** — a usable ranking
instead of a wall of "poor". The 3 fully-modern prompts reach craft=100; non-handoff spec/plan docs
sink to ~27.

**Return path:** a floor is temporary. When adoption of a convention rises (say >50% of recent
prompts carry it), drop its `floor` flag so it re-enters the craft composite and starts
discriminating again. Record that flip in the tuning log.

### 2. `no_bare_cross_bundle_script_paths` is scoped to non-home-repo handoffs

v1 flagged the 4 launcher-era prompts for referencing `…/sub-skills/.../cc_transcripts.py` without an
absolute root. But those are handoffs **into the ai-agent-kit archive itself**, where the scripts are
repo-local and a repo-relative path resolves correctly — a false positive. v2 adds
`"skip_if_home_repo": true` and a top-level `"home_repo_markers": ["ai-agent-kit"]`; the check is
skipped when the prompt path or its frontmatter `repo` names a home repo. For handoffs into *other*
repos (the case the rule actually targets) it still fires.

**Limitation (honest):** the home-repo test is a path/`repo`-field substring match, not a
per-reference resolution of which bundle each script belongs to. It removes the observed false
positives without claiming to be a full module resolver. Revisit if a home-repo handoff ever
legitimately references a *different* repo's scripts bare.

## Everything else is unchanged from v1

Same frontmatter fields, same required sections, same `state_claims_tagged` /
`worktree_already_exists_warning` checks, same band thresholds (now applied to the craft composite).
See [`rubric.v1.md`](rubric.v1.md) for the full element list and weights.
