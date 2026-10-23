---
name: sm-dispatch
description: >
  Sub-skill of `session-manager`. Launch any prompt file in a fresh Claude Code session: create
  or reuse a per-task git worktree, open a new Windows Terminal tab through spawn-terminal (repo
  tab colour, -SetEnv model pinning, WT-absent fallback), and verify the launch by PID. Use for
  "/dispatch-session", "launch this prompt in a new session", "run this prompt file in its own
  worktree".
---

# dispatch

Launch a prompt file in a fresh Claude Code session, inside its own isolated worktree, in a new
Windows Terminal tab -- then confirm the session actually started.

This sub-skill is invoked two ways: by [`handoff`](../handoff/SKILL.md) launch mode after it has
written a prompt, and directly by `/dispatch-session <prompt-file>`. In the direct case the prompt
file can be **any** markdown file -- one `handoff` wrote, one you wrote by hand, or one pulled from
another repo. Dispatch does not inspect or rewrite it.

## Inputs

| Input | Required | Notes |
|---|---|---|
| Prompt file | yes | Absolute path to an existing file. Keep it in the main checkout (e.g. `docs/PROMPTS/`), never inside the worktree -- a prompt in the worktree lands in the branch diff. |
| Repo | yes | The repository to work in (default: the current one). |
| Worktree / branch | no | An existing worktree path to reuse, or a `-Slug`/`-Type` to create a new one. If none is given, derive a hyphenated slug from the prompt filename. |
| Model | no | Pinned via `-SetEnv "ANTHROPIC_MODEL=<id>"`. |

`<skill-dir>` below is this sub-skill's directory:
`~/.claude/skills/session-manager/sub-skills/dispatch` when installed globally. Write every
`<skill-dir>/scripts/...` reference as that **resolved absolute path** -- including any you copy
into a prompt. A bare `scripts/...` path resolves against the receiving session's repo root, where
the script does not exist.

If the prompt file is missing or empty, say so and stop; do not invent one (use
[`handoff`](../handoff/SKILL.md) to author a prompt).

## Step 1 -- Create (or reuse) the worktree

Reuse the worktree if the caller supplied one. Otherwise:

```powershell
pwsh -File <skill-dir>/scripts/new-task-worktree.ps1 `
    -RepoPath 'C:\path\to\repo' -Slug 'reset-move-queue' -Type refactor -SyncDeps
```

It fetches, fast-forwards the local base branch to `origin/<base>`, branches the worktree from
**`origin/<base>`** (not the local ref, which may be a week stale), and syncs dependencies. The
sync is fast-forward only: if the local base has diverged the script stops rather than resetting
-- divergence means unpushed commits, which is a person's problem. Surface it and ask.

The script prints `WorktreePath` and `Branch`. Keep both: the launch needs the path, and cleanup
(see [`retire`](../retire/SKILL.md)) needs the branch. Tell the new session that its worktree and
branch already exist, so it works there instead of creating a second one.

## Step 2 -- Launch

Point `-WorkingDirectory` at the worktree, not the repo root, so the session starts inside its own
checkout:

```powershell
pwsh -File <skill-dir>/scripts/launch-claude-session.ps1 `
    -PromptPath 'C:\repo\docs\PROMPTS\2026-07-21-thing.md' `
    -WorkingDirectory 'C:\repo\.worktrees\reset-move-queue' `
    -Title 'repo-reset-move-queue' `
    -HandoffId 'd1-corr-26a'
```

The prompt is read from a file inside a `-File` script, so no prompt text crosses a shell-quoting
layer. (Passing it inline through `wt` -> `pwsh -Command` crosses two parsers, and a title with a
space makes `wt` treat the remainder as a command.) Keep titles hyphenated anyway.

**Correlation.** Pass `-HandoffId` with the same id the generated prompt's frontmatter carries
(`handoff` mints it in Step 3 of its own flow) -- the launcher appends a dispatch-time row to the
[handoff registry](../handoff/references/handoff-registry.md) (`~/.claude/telemetry/handoffs.jsonl`,
`source: live`, `child_sid: null` until the child's own first-turn self-report completes it).
Omitting it still works -- the launcher mints its own id -- but then nothing in the prompt can
reference it, so the self-report step has no id to reuse. Always pass it when launching from
`handoff`.

The launcher is a thin Claude-specific layer over the generic `spawn-terminal` skill, which owns
the tab spawn, colour, WT fallback and PID verification. It finds `spawn-terminal.ps1` with the
`$PSScriptRoot`-relative path `..\..\..\..\spawn-terminal\scripts\spawn-terminal.ps1` -- four
levels up from `session-manager/sub-skills/dispatch/scripts` to `skills/`. The archive and the
installed profile share that layout, so one relative path works in both. If the `spawn-terminal`
skill is not installed alongside, the launcher throws `spawn-terminal.ps1 not found at '...'` and
names where it must be installed. Report that error; do not work around it.

**Permissions.** Spawned sessions run with `--dangerously-skip-permissions` by default (nobody is
there to answer approval dialogs). `-NoSkipPermissions` opts out for a run you will babysit. With
the guardrail off, the prompt's hard-constraints section is the only protection left.

**Environment.** A script-launched session inherits nothing from your shell. The defaults (see
`$script:DefaultEnvironment` in the script) cover terminal colour, anchoring bash to the project
root, long bash and subagent-stall timeouts, and silencing nonessential traffic. The opposite also
holds: a new `wt` window *does* inherit the launching process's environment, so the launcher's own
identity variables (`CLAUDECODE`, `CLAUDE_PID`, `CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_CHILD_SESSION`,
`CLAUDE_CODE_MESSAGING_SOCKET`/`_TOKEN`) can leak into the spawned claude and make it start up as a
child of the handing-off session instead of a session of its own — the runner always clears them
first (`$script:InheritedSessionVariables`, passed through to `spawn-terminal -ClearEnv`). Change the
defaults with `-SetEnv` `KEY=VALUE` pairs; a bare `KEY=` drops a default:

```powershell
-SetEnv "ANTHROPIC_LOG=debug","FORCE_COLOR="
```

`KEY=VALUE` strings rather than a hashtable because `pwsh -File` passes every argument as a literal
string; the script re-splits them, so `-File` and `-Command` both work and commas in values survive.

**Model pinning.** Choosing the model is part of writing the prompt, not a launcher setting: weigh
the *hardest* task in the prompt, not the average. Pass it as `-SetEnv "ANTHROPIC_MODEL=<id>"` and
state in the prompt which model you picked and why, so the session can sensibly `/model` away. For
a split task mix, prefer the stronger model and delegate mechanical parts to `model: "haiku"`
subagents.

**Tab colour.** One stable colour per repo, so sessions for the same checkout group visually. It is
resolved from the global registry `~/.claude/repo-colors.json`, keyed by the normalized `origin`
remote (every worktree of a repo shares it); first launch seeds it from `tabColor:` in
`pm-profile.yml` or the next unused AC palette colour. Override one launch with
`-TabColor '#RRGGBB'`, or `-ColorScheme '<name>'` to also recolour the TUI palette. Resolution never
blocks a launch -- on failure the tab is just uncoloured. The registry and `/repo-color` command
belong to `spawn-terminal` (`resolve-repo-color.ps1`, `manage-repo-colors.ps1`).

**Dry run.** `-DryRun` writes the runner script and prints it without launching. Use it after
changing the environment or the prompt path to see exactly what the new tab will execute.

### If Windows Terminal is unavailable

`wt` ships with Windows 11 but can be absent on stripped-down or server installs. The launcher
falls back to `pwsh` in a plain console window automatically. If even that fails, do not give up
silently: report the prompt file path and the exact command the user can run themselves -- the
prompt, the expensive part, is already written.

## Step 3 -- Verify the launch and report

The script prints the PID of the launched `claude` process, or an error if it never started.
Confirm from that output, not from `Start-Process` returning -- the failure mode is a tab that
opens and immediately dies, which looks identical to success from the caller's side.

Report in one short block: worktree path and branch, prompt file path, PID, pinned model and why
(and the task order, if `handoff` supplied one). Record the prompt path and branch -- cleanup
needs both and they are otherwise lost after a context compaction.

## Related

- [`handoff`](../handoff/SKILL.md) -- writes the prompt, then calls this sub-skill (launch mode).
- [`retire`](../retire/SKILL.md) -- gated cleanup of the prompt, worktree and branch once the
  session finishes.
