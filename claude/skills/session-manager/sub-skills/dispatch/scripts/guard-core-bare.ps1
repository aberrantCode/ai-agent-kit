<#
.SYNOPSIS
    Detect, log, and repair a working repo that has wrongly been flipped to core.bare=true.

.DESCRIPTION
    Twice on 2026-10-23 the ai-agent-kit primary checkout had `core.bare` flipped to `true` during
    the dispatch/worktree/merge flow, making git refuse all work-tree operations ("must be run in a
    work tree"). Three controlled repros (serial worktree churn, 48-way concurrent churn, the real
    new-task-worktree.ps1 + merge cleanup) could NOT reproduce it, and no script/hook sets it — the
    trigger is unidentified. Until it is, this guard does two jobs:

      1. **Self-heal** — a working repo (one that has a real HEAD / tracked files) must not be bare.
         If it is found bare, set `core.bare false` so the checkout keeps working.
      2. **Instrument** — append one JSON line per *detected* flip to the event log, recording the
         op, phase, cwd and PID that observed it. The next live flip therefore records which
         operation's window it happened in — turning an unreproducible bug into evidence.

    Call it at the START (phase pre) and END (phase post) of any worktree/merge/dispatch op on the
    primary repo. A `pre` hit means a *previous* op left it bare; a `post` hit means *this* op did.

.PARAMETER RepoPath
    Any path inside the repo to check. The guard resolves the repo's main root from it.

.PARAMETER Op
    Short operation label, e.g. 'new-task-worktree', 'launch-claude-session', 'merge'.

.PARAMETER Phase
    'pre' or 'post'. Which side of the operation this check runs on.

.PARAMETER LogPath
    Event log (JSONL). Defaults to ~/.claude/telemetry/core-bare-events.jsonl.

.PARAMETER NoRepair
    Only detect and log; do not set core.bare=false. (Default is to repair.)

.OUTPUTS
    PSCustomObject { WasBare; Repaired; RepoRoot }. Also prints a one-line status.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$Op,
    [ValidateSet('pre', 'post')][string]$Phase = 'pre',
    [string]$LogPath = (Join-Path $env:USERPROFILE '.claude\telemetry\core-bare-events.jsonl'),
    [switch]$NoRepair
)

$ErrorActionPreference = 'Stop'

# core.bare is a repo-wide config value, so read it from any path inside the repo. We deliberately
# do NOT call `rev-parse --show-toplevel` first: once bare, that very call fails, which is the
# symptom we are here to catch.
$bare = (& git -C $RepoPath config --get core.bare 2>$null)
$isBare = ($bare -eq 'true')

# The common dir is the shared .git even when bare; use it to label the event with a stable root.
$repoRoot = (& git -C $RepoPath rev-parse --path-format=absolute --git-common-dir 2>$null)
if ($repoRoot) { $repoRoot = (Split-Path -Parent ($repoRoot.Trim())) } else { $repoRoot = $RepoPath }

$repaired = $false
if ($isBare) {
    # Record the flip BEFORE repairing, so the evidence survives even if the repair throws.
    $event = [ordered]@{
        ts       = (Get-Date).ToUniversalTime().ToString('o')
        repo     = $repoRoot
        op       = $Op
        phase    = $Phase
        cwd      = (Get-Location).Path
        pid      = $PID
        detected = 'core.bare=true'
    }
    try {
        $dir = Split-Path -Parent $LogPath
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        ($event | ConvertTo-Json -Compress) | Add-Content -LiteralPath $LogPath -Encoding UTF8
    }
    catch {
        Write-Warning "guard-core-bare: failed to write event log '$LogPath': $_"
    }

    if (-not $NoRepair) {
        & git -C $RepoPath config core.bare false 2>$null
        $repaired = $true
    }
    Write-Host "guard-core-bare[$Op/$Phase]: FOUND core.bare=true at '$repoRoot' — $(if ($repaired) { 'repaired (set false)' } else { 'logged only (NoRepair)' }). Event -> $LogPath"
}

[pscustomobject]@{ WasBare = $isBare; Repaired = $repaired; RepoRoot = $repoRoot }
