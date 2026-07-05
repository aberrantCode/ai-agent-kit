---
name: side-effect-free-helper-library
description: Use when centralizing duplicated presentation/logging helpers (log, ok, fail, section, etc.) scattered across many shell scripts in a fleet, so consumers can safely source the shared module regardless of their own validation or exit-code conventions.
status: active
version: 2026-07-05
---

# Side-Effect-Free Helper Library

## When to use

You're consolidating duplicated helper functions (output formatting, logging,
success/fail markers) that are copy-pasted across dozens to hundreds of scripts in
a fleet, and different consumers currently validate inputs or handle exit codes
differently. Also applies to any shared shell library being adopted incrementally
across a large, heterogeneous set of existing scripts.

## Method

1. **Make the shared module silent on source** — sourcing it must never validate
   arguments, check for required keys/env vars, or exit/return non-zero as a side
   effect of being loaded. All of that stays in the consumer (`common.sh`,
   `sops/_lib.sh`, or whatever each script already uses for its own init checks).
   This decouples "initialization validation" from "presentation formatting" so
   scripts with different validation needs can all adopt the same output helpers
   without conflict.

2. **Provide a small, composable function set**: `log`, `ok`, `fail`, `die`,
   `section`, `warn`, `info`. Document the exit-code contract precisely and
   distinguish them clearly:
   - `fail()` prints an error-style message **and returns 0** (non-fatal — caller
     decides what happens next).
   - `die()` is the only function that actually exits the process.
   This distinction has to be explicit in the docs, since the two look similar at
   a glance but have opposite control-flow implications.

3. **Use ASCII-only glyphs** (`*`, `!`, `x`) instead of Unicode symbols (`✓`, `✗`)
   to avoid encoding/mojibake issues across terminals and CI log viewers.

4. **Gate color on TTY detection**: `[ -t 2 ]` (checking fd 2, since output goes to
   stderr) before emitting ANSI color codes, so piped/CI output stays clean.

5. **Route all presentation output to stderr**, keeping stdout reserved for
   machine-parseable data. This lets consumers pipe stdout for parsing while still
   seeing human-readable logs.

6. **Provide a migration recipe for consumers**: drop the local helper
   definitions, then source the centralized module — path depends on depth:
   `source ../phases/output.sh` for subdirectory scripts, `phases/output.sh` for
   top-level ones.

7. **Migrate mechanically to avoid corruption**: use a content-agnostic `awk`
   replacement that operates by line range with the source line passed in as an
   env var, rather than pattern-matching text — this sidesteps mojibake/encoding
   corruption during bulk find-and-replace across many files.

8. **Verify each migration batch in three ways**: `bash -n <file>` per file
   (syntax check), a repo-wide parse sweep confirming all consumers still parse
   (e.g. all 240+ scripts), and a render-preview comparison to confirm output
   formatting is visually unchanged.

## Gotchas

- If the shared module validates anything on load, some consumer that intentionally
  skips that validation will break — silence-on-source is the whole point.
- Conflating `fail()` (non-fatal, returns 0) with `die()` (exits) in either the
  implementation or the docs will cause scripts to either exit when they shouldn't
  or silently continue when they should have stopped.
- Unicode glyphs look fine locally but corrupt in some CI log viewers and legacy
  terminals — ASCII-only is a deliberate constraint, not an aesthetic choice.
- Bulk text substitution across hundreds of scripts via naive `sed`/pattern-match
  risks mojibake; use line-range-based, content-agnostic replacement instead, and
  verify with a full parse sweep after each batch, not just a sample.
