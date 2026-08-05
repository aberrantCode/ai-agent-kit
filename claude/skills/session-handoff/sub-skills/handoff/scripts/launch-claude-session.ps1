<#
.SYNOPSIS
    Launch a fresh Claude Code session in a new Windows Terminal tab with a prompt file injected.

.DESCRIPTION
    A thin Claude-specific specialization over the generic spawn-terminal.ps1 launcher (in the
    `spawn-terminal` bundle). This script owns everything that is specific to spawning *Claude*:

      - the default environment a headless Claude session needs ($script:DefaultEnvironment),
      - the --dangerously-skip-permissions default and the -NoSkipPermissions opt-out,
      - reading the prompt from a file rather than passing it inline (a single space in a title is
        enough to make `wt` treat the rest of the line as a command; reading from a file removes
        that whole class of failure),
      - verifying that a `claude` process actually came up.

    Everything generic — the Windows Terminal invocation, per-repo tab color, the pwsh-console
    fallback, and launch verification — is delegated to spawn-terminal.ps1. This script's public
    parameters are unchanged from when it did that work itself.

.PARAMETER PromptPath
    Path to the markdown prompt file. Its full contents become the new session's first message.

.PARAMETER WorkingDirectory
    Directory the new session starts in. Defaults to the current location.

.PARAMETER Title
    Tab title. Hyphenate it — spaces are the documented failure above.

.PARAMETER NoSkipPermissions
    Runs without --dangerously-skip-permissions. Spawned sessions pass it by default: nobody is
    sitting in the new tab to answer approval prompts, and a session blocked on a dialog is a
    stalled session. Opt out for a run you intend to babysit.

    With the flag on, the prompt's hard-constraints section is the only thing preventing an
    irreversible action, so it has to be written as the last line of defence.

.PARAMETER SetEnv
    Environment variables for the new session, as KEY=VALUE strings. Merged over the defaults in
    $script:DefaultEnvironment: a key overrides that default, and a bare KEY= drops it. The merged
    set is handed to spawn-terminal.ps1, which sets it inside the runner script so claude inherits
    it as a child process.

    KEY=VALUE rather than a hashtable because `pwsh -File` passes every argument as a string, so a
    hashtable literal fails type conversion at the parameter binder.

.PARAMETER TabColor
    Windows Terminal tab color as #RGB or #RRGGBB. Omit it to let spawn-terminal.ps1 auto-resolve a
    stable per-repo color. Pass a value to override for a single launch.

.PARAMETER ColorScheme
    Windows Terminal color scheme name for the tab (must already be defined in your WT settings),
    e.g. 'AC Phosphor'. Optional.

.PARAMETER DryRun
    Print the claude runner and the delegated launch plan without launching anything.

.EXAMPLE
    pwsh -File launch-claude-session.ps1 -PromptPath C:\repo\docs\PROMPTS\task.md `
        -WorkingDirectory C:\repo\.worktrees\my-task -Title repo-my-task

.EXAMPLE
    pwsh -File launch-claude-session.ps1 -PromptPath C:\repo\prompt.md `
        -SetEnv 'ANTHROPIC_LOG=debug', 'FORCE_COLOR='
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PromptPath,
    [string]$WorkingDirectory = (Get-Location).Path,
    [string]$Title = 'claude-session',
    [switch]$NoSkipPermissions,
    [string[]]$SetEnv = @(),
    [string]$TabColor,
    [string]$ColorScheme,
    [switch]$DryRun
)

# Defaults for a session that nobody is sitting in front of. A spawned session inherits nothing
# from the interactive shell, so anything that matters has to be stated here.
#
# Every name below was verified against the installed claude binary rather than taken from
# documentation, because several are easy to get subtly wrong (the stall timeout is
# ..._TIMEOUT_MS, not ..._TIMEOUT).
$script:DefaultEnvironment = @{
    # Terminal capability: without these the tab can degrade to 16-colour output even though
    # Windows Terminal renders 24-bit fine.
    COLORTERM                                = 'truecolor'
    FORCE_COLOR                              = '1'

    # Return to the project root after each bash call. Repos that keep code in worktrees and
    # data/credentials in the main checkout make silent cwd drift a real hazard.
    CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = '1'

    # The 2-minute default kills foreground work that legitimately takes longer — full-account
    # walks, re-encodes, bulk rebuilds. Raise the floor, and the ceiling for the deliberate ones.
    BASH_DEFAULT_TIMEOUT_MS                  = '300000'
    BASH_MAX_TIMEOUT_MS                      = '900000'

    # Fan-out work on long tasks otherwise trips the 10-minute subagent stall timeout.
    CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS      = '900000'

    # One switch covering telemetry, error reporting, surveys, and marketplace calls.
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'

    # Don't throw browser windows at someone who is working in a different window.
    CLAUDE_CODE_ARTIFACT_AUTO_OPEN           = '0'
}

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PromptPath)) {
    throw "Prompt file not found: $PromptPath"
}
if (-not (Test-Path -LiteralPath $WorkingDirectory)) {
    throw "Working directory not found: $WorkingDirectory"
}
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw 'claude CLI not found on PATH.'
}

$PromptPath = (Resolve-Path -LiteralPath $PromptPath).Path
$WorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory).Path
$Title = $Title -replace '\s+', '-'

# Locate the generic launcher. The installed global profile mirrors the archive's directory layout
# — spawn-terminal and session-handoff are siblings under skills/ in both — so one $PSScriptRoot-
# relative path resolves in dev and in production alike.
$spawnTerminal = Join-Path $PSScriptRoot '..\..\..\..\spawn-terminal\scripts\spawn-terminal.ps1'
if (-not (Test-Path -LiteralPath $spawnTerminal)) {
    throw "spawn-terminal.ps1 not found at '$spawnTerminal'. The 'spawn-terminal' skill must be " +
    "installed alongside this bundle (globally: ~/.claude/skills/spawn-terminal/)."
}
$spawnTerminal = (Resolve-Path -LiteralPath $spawnTerminal).Path

# Caller -SetEnv wins over defaults; a bare KEY= drops a default entirely. `pwsh -File` delivers
# `-SetEnv A=1,B=2` as one string with commas intact, so split on commas that introduce a new KEY=.
$pairs = foreach ($raw in $SetEnv) {
    ($raw -replace '"', '') -split ',(?=[^=,]+=)' | Where-Object { $_.Trim() }
}
$environment = $script:DefaultEnvironment.Clone()
foreach ($pair in $pairs) {
    if ($pair -notmatch '^([^=]+)=(.*)$') {
        throw "Invalid -SetEnv entry '$pair'. Expected KEY=VALUE (or KEY= to unset)."
    }
    $key, $value = $Matches[1].Trim(), $Matches[2]
    if ([string]::IsNullOrEmpty($value)) { $environment.Remove($key) }
    else { $environment[$key] = $value }
}
# Serialize the merged, unset-applied set back to KEY=VALUE for spawn-terminal. Every value here is
# non-empty (unsets already removed), so passing them as a native array keeps commas-in-values safe.
$mergedSetEnv = $environment.Keys | Sort-Object | ForEach-Object { "$_=$($environment[$_])" }

# The claude runner is what the new tab ultimately executes. spawn-terminal.ps1 sets the working
# directory and environment around it, then dot-invokes it in-process, so it only has to read the
# prompt from disk and hand it to claude — no inline prompt text ever crosses a shell parser.
$flags = if ($NoSkipPermissions) { '' } else { '--dangerously-skip-permissions' }
$claudeRunner = Join-Path ([System.IO.Path]::GetTempPath()) "claude-session-$Title-$PID.ps1"
@"
`$prompt = Get-Content -Raw -LiteralPath '$($PromptPath -replace "'", "''")'
claude $flags `$prompt
"@ | Set-Content -LiteralPath $claudeRunner -Encoding UTF8

# Build the delegated call. Only pass color flags the caller actually supplied, so an omitted
# -TabColor still lets spawn-terminal auto-resolve the per-repo color.
$spawnParams = @{
    ScriptPath       = $claudeRunner
    WorkingDirectory = $WorkingDirectory
    Title            = $Title
    SetEnv           = $mergedSetEnv
    VerifyProcess    = 'claude'
}
if ($TabColor) { $spawnParams.TabColor = $TabColor }
if ($ColorScheme) { $spawnParams.ColorScheme = $ColorScheme }
if ($DryRun) { $spawnParams.DryRun = $true }

if ($DryRun) {
    Write-Host "Claude runner (not launched): $claudeRunner"
    Get-Content -LiteralPath $claudeRunner | ForEach-Object { Write-Host "  $_" }
    Write-Host ''
}

& $spawnTerminal @spawnParams

if (-not $DryRun) {
    Write-Host "Prompt: $PromptPath"
}
