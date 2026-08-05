<#
.SYNOPSIS
    Spawn a new Windows Terminal tab that runs an arbitrary command or script — not tied to Claude
    Code, or to any particular tool.

.DESCRIPTION
    The generic core behind session-launching. It owns the fiddly parts that every spawn shares:

      - Writing what the new tab runs to a temp *runner script* rather than passing it inline,
        because inline text has to survive both the `wt` argument parser and the `pwsh` parser. A
        single space in a title is enough to make `wt` treat the rest of the line as a command and
        fail with "the system cannot find the file specified". Reading everything from a file
        removes that whole class of quoting failure.
      - Auto-resolving a stable per-repo tab color (see resolve-repo-color.ps1), so every tab
        spawned for the same checkout is visually grouped.
      - Falling back to a plain pwsh console window when Windows Terminal is unavailable.
      - Confirming the launch actually came up, rather than trusting that Start-Process returned.

    It carries NO default environment and knows nothing about any specific CLI. Callers that need a
    tool-specific default set (e.g. launch-claude-session.ps1) layer that on top via -SetEnv.

.PARAMETER Command
    A command line to run in the new tab, e.g. 'git status' or 'npm run dev'. Mutually exclusive
    with -ScriptPath.

.PARAMETER ScriptPath
    Path to a .ps1 to run in the new tab. Mutually exclusive with -Command. Use -ScriptArgs to pass
    arguments. This is the path callers use to inject a prepared runner (the claude launcher does).

.PARAMETER ScriptArgs
    Arguments forwarded to -ScriptPath, as a string array. Ignored when -Command is used.

.PARAMETER WorkingDirectory
    Directory the new tab starts in — a main checkout, a worktree, or a folder unrelated to the
    current work. Defaults to the current location.

.PARAMETER Title
    Tab title. Spaces are collapsed to hyphens — see the quoting failure documented above.

.PARAMETER SetEnv
    Environment variables for the new session, as KEY=VALUE strings. A spawned session inherits
    nothing from the shell you launched it from, so anything that matters has to be stated. Windows
    Terminal has no mechanism for this — the variables are set inside the runner script, and the
    command inherits them as a child process.

    KEY=VALUE rather than a hashtable because `pwsh -File` passes every argument as a string, so a
    hashtable literal fails type conversion at the parameter binder. Strings work under both -File
    and -Command.

.PARAMETER TabColor
    Windows Terminal tab color as #RGB or #RRGGBB. Omit it to auto-resolve a stable per-repo color
    via resolve-repo-color.ps1 (registry at ~/.claude/repo-colors.json). Pass a value to override
    for a single launch. Resolution failure is non-fatal — the tab still launches, uncolored.

.PARAMETER ColorScheme
    Windows Terminal color scheme name for the tab (must already be defined in your WT settings),
    e.g. 'AC Phosphor'. Recolors the palette the tab renders against. Optional.

.PARAMETER NoColor
    Skip per-repo color resolution entirely and launch an uncolored tab. Overrides -TabColor.

.PARAMETER Fullscreen
    Open the Windows Terminal window in full-screen mode (wt global flag --fullscreen).

.PARAMETER Maximized
    Open the Windows Terminal window maximized (wt global flag --maximized).

.PARAMETER Focus
    Open the Windows Terminal window in focus mode (wt global flag --focus).

.PARAMETER CloseOnExit
    Close the tab as soon as the command finishes. By default the tab is launched with pwsh
    -NoExit so it stays open (the common case: you want to see output and keep working). Pass this
    for fire-and-forget commands whose tab should disappear when they are done.

.PARAMETER VerifyProcess
    Poll for a new process of this name to confirm the launch came up (e.g. 'claude'). A tab that
    opens and dies immediately is indistinguishable from success at the Start-Process call site, so
    a caller that knows what process should appear can have it verified. Omit to only confirm that
    the terminal itself started.

.PARAMETER DryRun
    Write the runner script and print it (plus the resolved tab color / scheme) without launching
    anything. Useful for inspecting exactly what the new tab will execute.

.EXAMPLE
    pwsh -File spawn-terminal.ps1 -Command 'git status' -WorkingDirectory C:\repo -Title repo-status

.EXAMPLE
    pwsh -File spawn-terminal.ps1 -ScriptPath C:\tools\deploy.ps1 -Fullscreen -CloseOnExit `
        -Title deploy-run
#>
[CmdletBinding(DefaultParameterSetName = 'Command')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Command')][string]$Command,
    [Parameter(Mandatory = $true, ParameterSetName = 'Script')][string]$ScriptPath,
    [Parameter(ParameterSetName = 'Script')][string[]]$ScriptArgs = @(),
    [string]$WorkingDirectory = (Get-Location).Path,
    [string]$Title = 'spawn-terminal',
    [string[]]$SetEnv = @(),
    [string]$TabColor,
    [string]$ColorScheme,
    [switch]$NoColor,
    [switch]$Fullscreen,
    [switch]$Maximized,
    [switch]$Focus,
    [switch]$CloseOnExit,
    [string]$VerifyProcess,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $WorkingDirectory)) {
    throw "Working directory not found: $WorkingDirectory"
}
if ($PSCmdlet.ParameterSetName -eq 'Script') {
    if (-not (Test-Path -LiteralPath $ScriptPath)) { throw "Script not found: $ScriptPath" }
    $ScriptPath = (Resolve-Path -LiteralPath $ScriptPath).Path
}

$WorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory).Path
$Title = $Title -replace '\s+', '-'

# Tab color: one stable color per repo so concurrent tabs for the same checkout are grouped. An
# explicit -TabColor always wins; otherwise resolve (and persist) from the repo registry. -NoColor
# skips the whole step. A resolution failure is never fatal — the tab still launches, uncolored.
if ($NoColor) {
    $TabColor = $null
}
elseif (-not $TabColor) {
    $resolver = Join-Path $PSScriptRoot 'resolve-repo-color.ps1'
    if (Test-Path -LiteralPath $resolver) {
        try { $TabColor = (& $resolver -WorkingDirectory $WorkingDirectory 2>$null | Select-Object -Last 1) }
        catch { Write-Warning "Tab-color resolution failed ($($_.Exception.Message)); launching without one." }
    }
}
if ($TabColor -and $TabColor.Trim() -notmatch '^#?[0-9A-Fa-f]{3}([0-9A-Fa-f]{3})?$') {
    Write-Warning "Ignoring invalid -TabColor '$TabColor' (expected #RGB or #RRGGBB)."
    $TabColor = $null
}
elseif ($TabColor) {
    $TabColor = '#' + $TabColor.Trim().TrimStart('#').ToUpper()
}

# `pwsh -File` hands every argument through as a literal string, so `-SetEnv A=1,B=2` arrives as one
# element with the commas intact rather than as an array. Split on commas that introduce a new KEY=
# pair, which leaves commas inside a value alone.
$pairs = foreach ($raw in $SetEnv) {
    ($raw -replace '"', '') -split ',(?=[^=,]+=)' | Where-Object { $_.Trim() }
}

$environment = @{}
foreach ($pair in $pairs) {
    if ($pair -notmatch '^([^=]+)=(.*)$') {
        throw "Invalid -SetEnv entry '$pair'. Expected KEY=VALUE (or KEY= to unset)."
    }
    $key, $value = $Matches[1].Trim(), $Matches[2]
    if ([string]::IsNullOrEmpty($value)) { $environment.Remove($key) }
    else { $environment[$key] = $value }
}

# Single-quoted PowerShell strings only need doubled single quotes to be literal, which keeps values
# with spaces, backticks, or $ signs from being re-interpreted in the runner.
$envLines = $environment.Keys | Sort-Object | ForEach-Object {
    "`$env:$_ = '" + ($environment[$_] -replace "'", "''") + "'"
}

# The command line the runner ultimately executes. For -ScriptPath we use the call operator so the
# script runs in the runner's own process (env vars set above stay in scope); args are single-quoted
# individually. For -Command the caller's line is emitted verbatim.
if ($PSCmdlet.ParameterSetName -eq 'Script') {
    $argList = ($ScriptArgs | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ' '
    $invocation = "& '" + ($ScriptPath -replace "'", "''") + "' $argList".TrimEnd()
}
else {
    $invocation = $Command
}

# The inner script is what the new tab actually runs. Writing it to a temp file keeps the outer
# command line free of anything a parser could split.
$runner = Join-Path ([System.IO.Path]::GetTempPath()) "spawn-terminal-$Title-$PID.ps1"
@"
Set-Location -LiteralPath '$WorkingDirectory'
$($envLines -join "`n")
$invocation
"@ | Set-Content -LiteralPath $runner -Encoding UTF8

if ($DryRun) {
    $tab = if ($TabColor) { $TabColor } else { '(none)' }
    $scheme = if ($ColorScheme) { $ColorScheme } else { '(none)' }
    $windowMode = @(
        if ($Fullscreen) { 'fullscreen' }
        if ($Maximized) { 'maximized' }
        if ($Focus) { 'focus' }
    ) -join '+'
    if (-not $windowMode) { $windowMode = 'normal' }
    $exitMode = if ($CloseOnExit) { 'close-on-exit' } else { 'keep-open (-NoExit)' }
    Write-Host "Tab color: $tab   Color scheme: $scheme   Window: $windowMode   On exit: $exitMode"
    Write-Host "Runner script (not launched): $runner`n"
    Get-Content -LiteralPath $runner | ForEach-Object { Write-Host "  $_" }
    return
}

# pwsh -NoExit keeps the tab open after the command finishes (the default); -CloseOnExit drops it.
$pwshArgs = @('-ExecutionPolicy', 'Bypass', '-File', $runner)
if (-not $CloseOnExit) { $pwshArgs = @('-NoExit') + $pwshArgs }

$before = if ($VerifyProcess) {
    @(Get-Process -Name $VerifyProcess -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
}
else { @() }

# wt reads window-level global options BEFORE the command token, and tab styling as options to the
# `new-tab` subcommand. Long-form global flags are used deliberately — the short aliases (-F / -f /
# -M) differ subtly between WT versions, the long names do not.
$windowFlags = @()
if ($Fullscreen) { $windowFlags += '--fullscreen' }
if ($Maximized) { $windowFlags += '--maximized' }
if ($Focus) { $windowFlags += '--focus' }

$tabStyle = @()
if ($TabColor) { $tabStyle += @('--tabColor', $TabColor) }
if ($ColorScheme) { $tabStyle += @('--colorScheme', $ColorScheme) }

$launchArgs = $windowFlags + @('new-tab', '--title', $Title) + $tabStyle + @(
    '-d', $WorkingDirectory, 'pwsh') + $pwshArgs

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
    Start-Process pwsh -ArgumentList $pwshArgs -WorkingDirectory $WorkingDirectory
}

# Confirm the launch actually came up. Without a -VerifyProcess to watch for, we can only report
# that the terminal was asked to start; with one, poll for the new process.
if ($VerifyProcess) {
    $deadline = (Get-Date).AddSeconds(20)
    $launched = $null
    while ((Get-Date) -lt $deadline -and -not $launched) {
        Start-Sleep -Milliseconds 750
        $launched = Get-Process -Name $VerifyProcess -ErrorAction SilentlyContinue |
            Where-Object { $_.Id -notin $before } |
            Select-Object -First 1
    }
    if ($launched) {
        Write-Host "Started: $VerifyProcess PID $($launched.Id)  title '$Title'  cwd $WorkingDirectory"
    }
    else {
        Write-Host "No new '$VerifyProcess' process detected within 20s. Check the terminal tab for errors." -ForegroundColor Yellow
        Write-Host "Run it manually with:  pwsh -File `"$runner`""
        exit 1
    }
}
else {
    Write-Host "Terminal launched: title '$Title'  cwd $WorkingDirectory"
    Write-Host "Runner: $runner"
}
