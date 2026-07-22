<#
.SYNOPSIS
    Launch a fresh Claude Code session in a new Windows Terminal tab with a prompt file injected.

.DESCRIPTION
    The prompt is read from disk inside this script rather than passed inline, because inline text
    has to survive both the `wt` argument parser and the `pwsh -Command` parser. A single space in
    a title is enough to make `wt` treat the rest of the line as a command and fail with
    "the system cannot find the file specified". Reading from a file removes that whole class of
    failure.

    Falls back to a plain pwsh console window when Windows Terminal is unavailable.

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
    $script:DefaultEnvironment: a key overrides that default, and a bare KEY= drops it. Windows
    Terminal has no mechanism for this — the variables are set inside the runner script, and
    claude inherits them as a child process.

    KEY=VALUE rather than a hashtable because `pwsh -File` passes every argument as a string, so
    a hashtable literal fails type conversion at the parameter binder. Strings work under both
    -File and -Command.

.PARAMETER DryRun
    Write the runner script and print it without launching anything. Useful for inspecting what
    the new session will actually execute.

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

# `pwsh -File` hands every argument through as a literal string, so `-SetEnv A=1,B=2` arrives as
# one element with the commas and any quote characters intact rather than as an array. Split on
# commas that introduce a new KEY= pair, which leaves commas inside a value alone.
$pairs = foreach ($raw in $SetEnv) {
    ($raw -replace '"', '') -split ',(?=[^=,]+=)' | Where-Object { $_.Trim() }
}

# Caller values win over defaults; a bare KEY= drops a default entirely.
$environment = $script:DefaultEnvironment.Clone()
foreach ($pair in $pairs) {
    if ($pair -notmatch '^([^=]+)=(.*)$') {
        throw "Invalid -SetEnv entry '$pair'. Expected KEY=VALUE (or KEY= to unset)."
    }
    $key, $value = $Matches[1].Trim(), $Matches[2]
    if ([string]::IsNullOrEmpty($value)) { $environment.Remove($key) }
    else { $environment[$key] = $value }
}

# Single-quoted PowerShell strings only need doubled single quotes to be literal, which keeps
# values with spaces, backticks, or $ signs from being re-interpreted in the runner.
$envLines = $environment.Keys | Sort-Object | ForEach-Object {
    "`$env:$_ = '" + ($environment[$_] -replace "'", "''") + "'"
}

# The inner script is what the new tab actually runs. Writing it to a temp file keeps the
# outer command line free of anything a parser could split.
$flags = if ($NoSkipPermissions) { '' } else { '--dangerously-skip-permissions' }
$runner = Join-Path ([System.IO.Path]::GetTempPath()) "claude-session-$Title-$PID.ps1"
@"
Set-Location -LiteralPath '$WorkingDirectory'
$($envLines -join "`n")
`$prompt = Get-Content -Raw -LiteralPath '$PromptPath'
claude $flags `$prompt
"@ | Set-Content -LiteralPath $runner -Encoding UTF8

if ($DryRun) {
    Write-Host "Runner script (not launched): $runner`n"
    Get-Content -LiteralPath $runner | ForEach-Object { Write-Host "  $_" }
    return
}

$before = @(Get-Process -Name claude -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)

$launchArgs = @(
    'new-tab', '--title', $Title, '-d', $WorkingDirectory,
    'pwsh', '-NoExit', '-ExecutionPolicy', 'Bypass', '-File', $runner
)

$usedFallback = $false
if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
    try {
        Start-Process wt.exe -ArgumentList $launchArgs
    }
    catch {
        Write-Warning "Windows Terminal launch failed ($($_.Exception.Message)); falling back to a console window."
        $usedFallback = $true
    }
}
else {
    Write-Warning 'Windows Terminal (wt.exe) not found; falling back to a console window.'
    $usedFallback = $true
}

if ($usedFallback) {
    Start-Process pwsh -ArgumentList @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', $runner) `
        -WorkingDirectory $WorkingDirectory
}

# Confirm the session actually came up. A tab that opens and dies immediately is
# indistinguishable from success at the Start-Process call site, so poll for the process.
$deadline = (Get-Date).AddSeconds(20)
$launched = $null
while ((Get-Date) -lt $deadline -and -not $launched) {
    Start-Sleep -Milliseconds 750
    $launched = Get-Process -Name claude -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -notin $before } |
        Select-Object -First 1
}

if ($launched) {
    Write-Host "Claude session started: PID $($launched.Id)  title '$Title'  cwd $WorkingDirectory"
    Write-Host "Prompt: $PromptPath"
}
else {
    Write-Host "No new claude process detected within 20s. Check the terminal tab for errors." -ForegroundColor Yellow
    Write-Host "Run it manually with:  pwsh -File `"$runner`""
    exit 1
}
