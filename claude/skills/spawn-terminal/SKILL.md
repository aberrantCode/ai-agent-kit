---
name: spawn-terminal
description: >
  Spawn a new Windows Terminal tab (or window) that runs an arbitrary command or PowerShell script —
  independent of the session that launches it, and not tied to Claude Code. Use this skill whenever
  the user wants to "open a new terminal running X", "spawn a terminal", "launch a script in a new
  window", "kick off <command> in its own tab", "open a wt tab in this worktree", "run this in a
  separate terminal", "/spawn-terminal", or otherwise asks for a command or script to start in a
  fresh terminal rather than the current one. The new tab starts in a folder you choose (a main
  checkout, a worktree, or an unrelated folder), is colored to match the repo of the invoking
  session, and can open full-screen or maximized. This is the generic terminal-launch core;
  `session-handoff:handoff` builds its Claude-session launch on top of it.
category: Foundations & Workflow
requires: []
---

# Spawn Terminal

Launch a new Windows Terminal tab that runs a command or script you supply, in a working directory
you choose, without any of it passing through shell quoting. This is the reusable core extracted
from the session-handoff launcher: the value is not the `wt` invocation — that part is a few lines —
it is that spawning a session reliably means solving tab-color grouping, environment injection,
Windows-Terminal-absent fallback, and *verifying the tab actually came up* every single time, and
this skill solves them once.

## When to use it

- You want a command or long-running process to run in **its own tab**, not block the current one.
- You want to open a terminal **in a specific folder** — a worktree, a sibling checkout, or a path
  unrelated to the current work.
- You want the new tab **colored to match its repo**, so several tabs for the same checkout are
  visually grouped.
- You are building a higher-level launcher (like a tool-specific session spawner) and want the
  `wt`/color/fallback/verify plumbing handled for you.

If what you actually want is to hand *this session's* open work to a fresh **Claude** session with
captured state, that is `session-handoff:handoff` — it uses this skill underneath but adds the
prompt authoring, worktree, and delegation ledger around it.

## The script

Everything runs through one script. Never hand-write a `wt` command — the quoting failure it
avoids (a space in a title makes `wt` treat the rest of the line as a command) is the whole reason
the script exists.

```powershell
pwsh -File <skill-dir>/scripts/spawn-terminal.ps1 -Command 'git status' `
    -WorkingDirectory 'C:\repo' -Title repo-status
```

> **`<skill-dir>`** is this bundle's directory — `~/.claude/skills/spawn-terminal` when installed to
> the global profile. Write `<skill-dir>/scripts/…` references as that resolved absolute path; a
> bare `scripts/…` path resolves against the *receiving* repo's root, where the script does not
> exist.

### Two ways to say what the tab runs

- **`-Command '<command line>'`** — an inline command, e.g. `'npm run dev'` or `'git log --oneline'`.
- **`-ScriptPath '<path.ps1>'`** (with optional `-ScriptArgs`) — run a prepared PowerShell script.
  This is the path a higher-level launcher uses to inject a runner it built itself.

Exactly one of the two is required.

### The options that matter

- **`-WorkingDirectory`** — the folder the tab starts in. Defaults to the current location. Point it
  at a worktree to open a tab already inside an isolated checkout.
- **`-Title`** — the tab title. Spaces are collapsed to hyphens automatically; keep titles
  hyphenated anyway.
- **Tab color** — omit `-TabColor` and the script auto-resolves one stable color per repo from the
  registry at `~/.claude/repo-colors.json`, keyed by the repo's `origin` remote (so every worktree
  of a repo shares a color). Pass `-TabColor '#RRGGBB'` to override for one launch, `-ColorScheme
  '<name>'` (a scheme defined in your WT settings, e.g. `AC Phosphor`) to also recolor the palette
  the tab renders against, or `-NoColor` to skip color resolution entirely. Resolution never blocks
  a launch — on failure the tab is simply uncolored. Manage assignments with `/repo-color` (see
  below).
- **Window mode** — `-Fullscreen`, `-Maximized`, or `-Focus` open the window in that mode (Windows
  Terminal global flags). Long-form flags are used deliberately; the short aliases differ between WT
  versions.
- **`-CloseOnExit`** — by default the tab is launched with `-NoExit` and stays open after the
  command finishes, so you can read its output. Pass `-CloseOnExit` for fire-and-forget commands
  whose tab should vanish when they complete.
- **Environment** — a spawned tab inherits nothing from the shell you launched it from. Add
  variables with `-SetEnv "KEY=VALUE","OTHER=VALUE"`, and drop one you set earlier with a bare
  `KEY=`. The generic core carries **no** default environment — it stays neutral; tool-specific
  launchers layer their own defaults on top.
- **`-VerifyProcess '<name>'`** — poll for a new process of that name to confirm the launch came up
  (a tab that opens and dies immediately looks identical to success otherwise). Omit it to just
  confirm the terminal itself started.
- **`-DryRun`** — write the runner script and print it without launching. Worth doing after changing
  the environment or command to see exactly what the new tab will execute.

## Verify the launch, don't assume it

The script prints what started — either a confirmed PID (with `-VerifyProcess`) or a note that the
terminal was launched. Confirm from that output, not from the fact that the call returned: the
failure mode is a tab that opens and immediately dies, which is invisible to the caller.

## If Windows Terminal is unavailable

`wt` ships with Windows 11 but can be absent on stripped-down or server installs. The script falls
back to launching `pwsh` in a plain console window automatically. If even that fails, it reports the
runner-script path so the user can run it themselves.

## The `/repo-color` companion

The per-repo tab-color registry this skill uses is inspected and edited with `/repo-color`
(`commands/repo-color.md`): no arguments shows the current repo's color, a hex value pins one,
`list` prints the whole registry, `reset-top [N]` re-seeds the N most active repos from the AC
palette, and `preview` opens a window with a colored tab per registered repo. Always go through that
command rather than editing `~/.claude/repo-colors.json` by hand, so the mutex and key normalization
are honored.

## Diagram

[View diagram](diagram.html)
