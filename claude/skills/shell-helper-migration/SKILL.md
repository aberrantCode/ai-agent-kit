---
name: shell-helper-migration
description: Use when refactoring bash scripts to delegate to a centralized helper library (e.g. output.sh) — extracting local log/ok/fail/die/section/info/warn helper definitions, replacing them with a single source line, and preserving exact exit-code and output-contract semantics across a batch of scripts.
status: active
version: 2026-07-05
---

# Shell Helper Migration

## When to use

When consolidating duplicated shell helper functions (`log`, `ok`, `fail`, `die`, `section`, `info`, `warn`, `head0`, `step`, `milestone`, `sub`, colour variables) scattered across many bash scripts into one shared module, without breaking any script's exit codes, captured output, or execution semantics. Applies to batch migrations across tens or hundreds of scripts.

## Method

1. **Identify by canonical name.** Scan each script's header block for the standard helper names. Delete only those; keep custom helpers (`ssh_devops`, `hr`, `kv`, bespoke prompt logic) untouched.
2. **Add exactly one source line**, placed immediately after `set -euo pipefail`:
   - If the script defines `SCRIPT_DIR=`, anchor on it.
   - Otherwise use `$(dirname "${BASH_SOURCE[0]}")` — this form doesn't depend on `SCRIPT_DIR` being computed yet, so it's also the safe default when source-line placement is ambiguous.
   - For scripts one directory below the shared module, use the relative form (e.g. `../phases/output.sh`).
3. **Forensically determine each helper's contract before touching it** — visually identical defs behave differently at call sites:
   - Inspect the def body: does it `exit 1`? `return N`? plain `echo` with no exit?
   - Examine each call site: is it followed by an explicit `exit`/`die`, or is it bare inside a loop (record-then-continue)?
   - Check context: is `set -e` active, which would absorb a `return N` as an abort?
   - Rule: `fail` + explicit `exit N` where N≠1 stays exactly as-is (exit codes are load-bearing, never collapse them into `die`). `fail` + `exit 1`, or `... || die`, becomes `die`. Bare non-fatal `fail` (record-then-continue, e.g. in a fleet loop iterating over hosts) stays `fail`.
4. **Judge per-file, not per-repo, on three axes**: execution context (repo checkout vs. remote/on-host payload — see the shell-migration-skip-taxonomy skill for exclusions), contract (non-standard exit codes or shared state with retained siblings), and semantics (fatal vs. non-fatal call sites). A file that mixes one exit-2 `die()` with six migratable helpers should migrate the six and redefine just `die()` locally after sourcing — don't skip the whole file over one exception.
5. **Clean up orphaned state.** Grep changed files for now-unused color vars (`$GREEN`, `$RED`, `_ts`, `colour*`) and remove references — but only if nothing else in the file still uses them.
6. **Guard against use-before-source.** `bash -n` only checks syntax, not execution order, so it won't catch a helper called before the source line is evaluated (common in `while`/`getopts` arg-parsing loops or early error paths). Grep each migrated script for calls to sourced helper names that appear above the source line; if found, move the source line earlier (the `$(dirname ...)` form is safe to move without dependency issues).
7. **Verify.**
   - `bash -n` on every changed file.
   - A no-color render preview to confirm output formatting is unchanged.
   - Smoke-test the arg-parse path specifically (e.g. `./script.sh --bogus` should fail cleanly via the sourced `fail()`, not `command not found`).
8. **Batch coherently.** Group changes per filename prefix or subsystem rather than migrating the whole repo in one commit — makes review and revert tractable across 100+ files.

## Gotchas

- A `fail()` that returns 1 under `set -e` aborts immediately — `fail; fail; exit 1` with a return-based `fail()` will never print the second message. This is a latent bug worth flagging, not silently preserving.
- Never blind-`sed` replace `fail`→`die` or vice versa; the semantics must be read from both the definition and every call site.
- Removing non-ASCII glyphs from helper bodies is fine for workstation-side code, but see the skip-taxonomy skill for cases (heredoc payloads) where this must NOT be touched.
- "Looks the same" is not "is the same" — three helpers named identically across files can have three different exit-code contracts.
