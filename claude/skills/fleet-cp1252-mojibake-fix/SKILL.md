---
name: fleet-cp1252-mojibake-fix
description: Use when shell scripts (bash/PowerShell) print non-ASCII glyphs like checkmarks, X marks, or box-drawing rules that render as mojibake under Git Bash / Windows cp1252 terminals — replace runtime output with ASCII equivalents while leaving comments and remote heredocs untouched.
status: active
version: 2026-07-05
---

# Fleet CP1252 Mojibake Fix

## When to use

A fleet of scripts (bash `.sh`, PowerShell `.ps1`) emits Unicode symbols — `✓ ✗ ══ ──` and similar — in runtime output (echo/printf/Write-Host statements, helper function bodies). Under Git Bash or any terminal defaulting to the Windows cp1252 code page, these bytes render as mojibake (garbled multi-byte sequences) instead of the intended glyph. Use this skill when auditing or migrating a script fleet's console output for cross-terminal safety, or when a pre-commit hook needs to enforce ASCII-only output going forward.

## Method

1. **Classify every non-ASCII byte before touching anything.** Non-ASCII is only a problem in *runtime-emitted* output. It is fine in:
   - Source comments (never printed)
   - Remote SSH heredocs (rendered on a remote host with its own encoding, not the local cp1252 shell)
   - String literals that are themselves data, not console decoration
2. **Detect offending bytes.** Use `cat -A <file>` to reveal non-printing/high-bit bytes inline, or `perl -ne 'print if /[^\x00-\x7F]/' <file>` to list only lines containing non-ASCII. Grep for the specific glyphs (`✓`, `✗`, `═`, `─`) to find helper function definitions that emit them.
3. **Replace runtime glyphs with ASCII equivalents:**
   - `✓` (success) → `*`
   - `✗` (fail) → `x`
   - warn indicator → `!`
   - `══` (heavy rule) → `==`
   - `──` (light rule) → `--`
4. **Remove entire offending helper blocks with `awk` line-range deletion** when consolidating or replacing helper function definitions — this is content-agnostic (deletes by line number, not by pattern match) so it won't accidentally strip adjacent comments or unrelated code.
5. **Verify with a residual-byte scan.** After edits, re-run the `cat -A` / `perl -ne` non-ASCII scan across the whole file (or diff) and confirm every remaining non-ASCII byte is one of the three acceptable categories from step 1 — not new output that slipped through.
6. **Enforce going forward, don't just fix in place:**
   - Add a pre-commit hook for `.ps1` files that blocks non-ASCII runtime output (PowerShell scripts are the easiest to lint automatically for this).
   - For `.sh` fleet code, fix manually during refactoring passes — no reliable static enforcement point was established, so treat every helper-consolidation touch as an opportunity to sweep for mojibake.

## Gotchas

- Don't blanket-strip all non-ASCII — comments and remote heredocs are legitimate and stripping them is unnecessary churn (and can break heredoc content meant for a UTF-8-aware remote host).
- `awk` line-range deletion is preferred over pattern-based deletion for removing whole helper blocks because it doesn't risk leaving orphaned braces/parens if the glyph pattern doesn't match every line of the block.
- The bug only manifests under cp1252 (Windows Git Bash, `cmd.exe`); the same script may look fine when tested from a UTF-8 Linux terminal, which is why manual `.sh` reviews are necessary rather than relying on "it looked right when I tested it."
- Always re-verify after cleanup — a partial glyph replacement (e.g., fixing `✓` but missing `══` in the same helper) is a common miss caught only by the residual-byte scan.

## Diagram

[View diagram](diagram.html)
