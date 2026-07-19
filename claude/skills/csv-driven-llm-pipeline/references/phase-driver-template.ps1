#!/usr/bin/env pwsh
<#
.SYNOPSIS
Phase-by-phase CSV-driven pipeline template.

.DESCRIPTION
Replace YOUR-PIPELINE in the comments and the docs below with the actual purpose.
This template covers the four moving parts every CSV pipeline needs:
- Phase selection via [string[]]$Phase
- Per-row CSV writes for crash-resume
- Eligibility filtering on pipeline-state columns
- Optional dry-run + per-phase limit

Adapt by:
1. Setting the file paths in CONFIG.
2. Replacing the four phase function bodies (Discover, FetchA, ProcessB, ScoreC).
3. Tweaking the column names to match your schema.
#>

param(
    [string[]]$Phase            = @('all'),
    [switch]  $DryRun,
    [int]     $Limit            = 0,
    [int]     $RequestDelayMs   = 250,
    [int]     $MaxThrottleStreak = 5
)

$ErrorActionPreference = 'Stop'

# === CONFIG ===
$mainCsv     = 'data/pipeline.csv'
$artifactDir = 'data/artifacts'
$logsDir     = 'logs'
$logFile     = Join-Path $logsDir 'pipeline.jsonl'
if (-not (Test-Path $logsDir)) { $null = New-Item -ItemType Directory -Path $logsDir -Force }

# === PHASE SELECTION ===
$phaseList = @($Phase | ForEach-Object { $_ -split ',\s*' } |
    ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
if ($phaseList -contains 'all' -or -not $phaseList) {
    $phaseList = @('discover','fetch','process','score')
}
$runDiscover = $phaseList -contains 'discover'
$runFetch    = $phaseList -contains 'fetch'
$runProcess  = $phaseList -contains 'process'
$runScore    = $phaseList -contains 'score'

# === LOGGING ===
function Write-LogEvent {
    param(
        [string]$Phase, [string]$Step, [string]$Message,
        [ValidateSet('info','success','warn','error')] [string]$Status='info',
        [string]$Subject=''
    )
    $color  = switch ($Status) { 'success'{'Green'} 'warn'{'Yellow'} 'error'{'Red'} default{'White'} }
    $prefix = switch ($Status) { 'success'{'OK '} 'warn'{'!! '} 'error'{'XX '} default{'-- '} }
    Write-Host "[$Phase] $prefix$Message" -ForegroundColor $color
    [ordered]@{
        timestamp=(Get-Date -Format 'o'); phase=$Phase; step=$Step; subject=$Subject
        message=$Message; status=$Status
    } | ConvertTo-Json -Compress | Add-Content -Path $logFile
}

# === HELPERS ===
function Save-Csv {
    param([object[]]$Rows, [string]$Path)
    if ($DryRun) { return }
    $Rows | Export-Csv -Path $Path -NoTypeInformation -Encoding utf8
}

# === PHASE 0: DISCOVERY ===
function Invoke-DiscoverPhase {
    if (-not $runDiscover) { return }
    Write-LogEvent -Phase 'discover' -Step 'start' -Message 'Looking for new rows'
    # 1. Read upstream source (CSV, API, scrape)
    # 2. Build set of IDs already in $mainCsv
    # 3. For each new ID: build a default row with state columns at false/''
    # 4. Append to $mainCsv (Save-Csv)
    Write-LogEvent -Phase 'discover' -Step 'done' -Message 'Discovered N new row(s)' -Status 'success'
}

# === PHASE 1: FETCH (e.g., download a file from an external URL) ===
function Invoke-FetchPhase {
    if (-not $runFetch) { return }
    if (-not (Test-Path $mainCsv)) {
        Write-LogEvent -Phase 'fetch' -Step 'guard' -Message 'CSV not found, skipping' -Status 'warn'; return
    }
    $rows = @(Import-Csv $mainCsv)
    $eligible = @($rows | Where-Object { $_.fetch_done -ne 'true' })
    if ($Limit -gt 0) { $eligible = $eligible | Select-Object -First $Limit }
    Write-LogEvent -Phase 'fetch' -Step 'start' -Message "Eligible rows: $($eligible.Count)"

    $throttleStreak = 0
    foreach ($r in $eligible) {
        if ($DryRun) {
            Write-LogEvent -Phase 'fetch' -Step 'plan' -Message "Would fetch $($r.id)" -Subject $r.id
            continue
        }
        # See references/rate-limited-fetch.ps1 for the typed-status helper.
        # $result = Invoke-RateLimitedFetch -Url $r.url
        # switch ($result.status) {
        #     'ok' {
        #         # save artifact, flip state
        #         $r.fetch_done = 'true'
        #         $throttleStreak = 0
        #     }
        #     'throttle' {
        #         $throttleStreak++
        #         Start-Sleep -Seconds $result.retry_after
        #         if ($throttleStreak -ge $MaxThrottleStreak) {
        #             Save-Csv -Rows $rows -Path $mainCsv
        #             Write-LogEvent -Phase 'fetch' -Step 'circuit-break' -Message "Aborting after $MaxThrottleStreak throttles" -Status 'error'
        #             return
        #         }
        #     }
        #     default { $throttleStreak = 0 }
        # }
        Save-Csv -Rows $rows -Path $mainCsv
        if ($RequestDelayMs -gt 0) { Start-Sleep -Milliseconds $RequestDelayMs }
    }
}

# === PHASE 2: PROCESS (e.g., LLM-driven analysis) ===
function Invoke-ProcessPhase {
    if (-not $runProcess) { return }
    if (-not (Test-Path $mainCsv)) { return }
    $rows = @(Import-Csv $mainCsv)
    # Eligibility chains a prerequisite: must have fetched first
    $eligible = @($rows | Where-Object { $_.fetch_done -eq 'true' -and $_.process_done -ne 'true' })
    if ($Limit -gt 0) { $eligible = $eligible | Select-Object -First $Limit }
    Write-LogEvent -Phase 'process' -Step 'start' -Message "Eligible rows: $($eligible.Count)"

    foreach ($r in $eligible) {
        if ($DryRun) {
            Write-LogEvent -Phase 'process' -Step 'plan' -Message "Would process $($r.id)" -Subject $r.id
            continue
        }
        # Do the work (LLM call, parse, transform)
        # $result = Invoke-Analysis -Input $r
        # $r.process_result = $result.value
        # $r.process_done = 'true'
        # $r.process_done_by_model = 'ollama+mistral'
        Save-Csv -Rows $rows -Path $mainCsv
    }
}

# === PHASE 3: SCORE (e.g., subjective ranking) ===
function Invoke-ScorePhase {
    if (-not $runScore) { return }
    # Same shape: import, eligibility, loop, per-row save.
}

# === DRIVER ===
Write-LogEvent -Phase 'main' -Step 'start' -Message "Phases: $($phaseList -join ',') | DryRun: $DryRun | Limit: $Limit"
Invoke-DiscoverPhase
Invoke-FetchPhase
Invoke-ProcessPhase
Invoke-ScorePhase
Write-LogEvent -Phase 'main' -Step 'done' -Message 'Pipeline complete' -Status 'success'
