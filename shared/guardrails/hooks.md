---
name: hooks
description: PreToolUse/PostToolUse/Stop hook types, what's actually live in ~/.claude/settings.json vs. the template catalogue of hooks not currently installed, auto-accept permission guidance, and TodoWrite best practices
category: Foundations & Workflow
kind: snippet
scope: global
applies-to: [claude]
targets: hooks
source: ~/.claude/rules/hooks.md, archived 2026-08-09
status: active
version: 2026-08-09
---

## Hook Types

- **PreToolUse**: Before tool execution (validation, parameter modification)
- **PostToolUse**: After tool execution (auto-format, checks)
- **Stop**: When session ends (final verification)

## Installed hooks (live in ~/.claude/settings.json)

This is the current truth — verify against `settings.json` before relying on it:

- **PreToolUse `worktree-guard.py`** (matcher `Write|Edit`) — the only tool-gating
  hook actually installed.
- **SessionStart** — two `command` echoes: the AskUserQuestion reminder and the
  Honcho GUI-URL patch.

That is the whole set. Nothing auto-formats, blocks docs, or audits `console.log`
today.

## Template hooks (NOT currently installed)

The hooks below are **not in the live config** — they are a catalogue of what has
been enabled before and may be reinstated. Do not treat them as live enforcement, and
do not wait on them to fire. **When reinstating any of them, apply the stack
carve-outs noted inline.**

### PreToolUse (template)
- **tmux reminder**: Suggests tmux for long-running commands (npm, pnpm, yarn, cargo, etc.)
- **git push review**: Opens Zed for review before push
- **doc blocker**: Blocks creation of *unnecessary* .md/.txt files.
  **Carve-out — docs-as-product repos:** where markdown *is* the deliverable
  (design systems, docs sites, spec repos — e.g. `AC_DESIGN`, whose workflow
  **requires** creating `docs/<surface>-design-system.md` from a template), spec
  and template-derived docs are legitimate work, not junk. If reinstated, scope it so
  it targets stray scratch/summary files, not the repo's canonical documents.

### PostToolUse (template) — JS/TS-only, no-op elsewhere
These fire on JS/TS files and do nothing in a Python / PowerShell / CSS repo. Do not
port their intent by hand outside a JS/TS stack:
- **PR creation**: Logs PR URL and GitHub Actions status
- **Prettier**: Auto-formats JS/TS files after edit *(JS/TS only)*
- **TypeScript check**: Runs tsc after editing .ts/.tsx files *(TS only)*
- **console.log warning**: Warns about console.log in edited files *(JS/TS only — see
  the "No console.log" note in `coding-style.md`; a CLI's real stdout is not a
  violation)*

### Stop (template)
- **console.log audit**: Checks all modified files for console.log before session ends
  *(JS/TS grep — does not match Python `print()` / PowerShell `Write-Host`, which are
  intended output in CLI/build artifacts)*

## Auto-Accept Permissions

Use with caution — this governs the permission mode of **interactive sessions you
drive**, not purpose-built unattended-agent skills:
- Enable for trusted, well-defined plans
- Disable for exploratory work
- Don't reach for `--dangerously-skip-permissions` as a blanket bypass; prefer a
  scoped `allowedTools` allowlist. A purpose-built unattended-agent skill MAY skip
  permissions when its design requires it AND the workspace is trusted/isolated —
  this bullet does not forbid that.
- Configure `allowedTools` in `~/.claude.json` instead

## TodoWrite Best Practices

Use TodoWrite tool to:
- Track progress on multi-step tasks
- Verify understanding of instructions
- Enable real-time steering
- Show granular implementation steps

Todo list reveals:
- Out of order steps
- Missing items
- Extra unnecessary items
- Wrong granularity
- Misinterpreted requirements
