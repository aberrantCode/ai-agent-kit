---
name: ui-redesign-with-snapshot-regeneration
category: Frontend
description: Use when performing a multi-phase UI redesign (e.g. a Next.js/React 19 reskin) that has existing snapshot tests, or any time `vitest -u`/snapshot regeneration is needed after intentional visual changes — to avoid masking real regressions as "just snapshot drift."
status: active
version: 2026-07-05
---

# UI Redesign with Snapshot Regeneration

## When to use

Any multi-phase UI redesign or reskin of an app that has existing snapshot/visual
tests — especially when the underlying framework has behavioral constraints (e.g.
React 19's no-setState-in-effect rule) that make silent regressions easy to
introduce. Also use any time you're about to run `vitest -u` (or an equivalent
snapshot-update flag) after a deliberate visual change, since regeneration can hide
non-snapshot failures if done carelessly.

## Method

1. **Separate the data layer from the presentation layer before redesigning.**
   Extract existing data flow (actions, hooks, query keys) into a presentation-
   agnostic layer first, then mount new component trees on top of that same shared
   state. This means "does the redesign break behavior" and "does the redesign
   change appearance" become two separable questions instead of one tangled one.

2. **Structure the work as staged phases on feature branches targeting `dev`**, each
   phase gated by the full check sequence (`tsc`, `eslint`, `vitest`) before moving
   to the next phase. Don't let visual-only changes skip type/lint/test gates.

3. **Regenerate snapshots deliberately, only at merge-ready time**, using
   `vitest -u` (or equivalent). This flag updates only the snapshots that actually
   mismatch — passing snapshots are left untouched — so it's safe to run once you've
   confirmed the visual change is intentional.

4. **Run the suite again after regeneration, unmodified.** This is the critical
   two-pass pattern: pass 1 (`-u`) absorbs legitimate visual drift; pass 2 (plain
   run, no `-u`) surfaces whatever still fails. Anything failing after regeneration
   is a real bug — not a snapshot issue — because snapshot mismatches were already
   absorbed in pass 1. Treat any remaining failure as a genuine defect requiring
   investigation, not something else to "just regenerate away."

5. **Verify snapshot changes are deliberate, not silent regressions**, by reviewing
   the diff of what changed in each updated snapshot against what phase intended to
   change. A snapshot updating in a file unrelated to the current phase's stated
   scope is a signal something leaked.

6. **Run a code-review pass on every phase**, specifically looking for high-severity
   semantic bugs that snapshot tests are known to miss — e.g. button activation
   logic, or measurement-cache keying bugs — since these can silently pass visual
   snapshot comparisons while being functionally broken.

7. **Respect the target framework's constraints throughout** (e.g. React 19 forbids
   `setState` calls inside effects) and keep all state transformations immutable,
   consistent with the rest of the redesign's code style.

## Gotchas

- Never treat "all failures are probably snapshot-related" as a default assumption
  after a redesign — always do the two-pass verification (regenerate, then re-run
  clean) before concluding that.
- Snapshot tests validate visual/markup shape, not semantic correctness — button
  activation state and cache-keying bugs routinely pass snapshot diffs while being
  functionally wrong; catch these in code review, not snapshot review.
- Keep "did this look right" (snapshot) and "did this behave right" (functional
  test / code review) as explicitly separate concerns in test design — conflating
  them is what allows behavioral regressions to hide behind an approved visual diff.
- Regenerating snapshots before confirming the visual change is actually intended
  can permanently bake a regression into the baseline — regenerate at merge-ready
  time, not reflexively whenever a test fails.

## Diagram

[View diagram](diagram.html)
