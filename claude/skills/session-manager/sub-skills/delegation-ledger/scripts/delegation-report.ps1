<#
.SYNOPSIS
    Summarise the delegation ledger and flag work categories that should stop going to a cheap model.

.DESCRIPTION
    Turns the append-only ledger into the only number that matters per category: the share of
    delegations that had to be escalated, redone, or abandoned. A category with a high failure
    share is one where the cheap model is costing more than it saves — every escalation pays for
    the small model's attempt, the parent's review, and the retry.

    Recommendations require a minimum sample size, because the temptation with three data points
    is to conclude something. Categories below the threshold are reported as "insufficient data"
    rather than quietly omitted; not knowing is a finding too.

.PARAMETER LedgerPath
    JSONL ledger written by log-delegation-outcome.ps1.

.PARAMETER MinSample
    Dispatches a category+model pair needs before a recommendation is offered.

.PARAMETER FailureThreshold
    Failure share above which the pair is flagged. 0.2 = one in five delegations went wrong.

.PARAMETER Since
    Only consider records at or after this UTC date (yyyy-MM-dd). Useful after a model upgrade,
    when older evidence describes a model that no longer exists.
#>
[CmdletBinding()]
param(
    [string]$LedgerPath = (Join-Path $env:USERPROFILE '.claude\telemetry\delegation-outcomes.jsonl'),
    [int]$MinSample = 10,
    [double]$FailureThreshold = 0.2,
    [string]$Since
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LedgerPath)) {
    Write-Host "No ledger yet at $LedgerPath — nothing has been delegated-and-logged."
    return
}

$records = Get-Content -LiteralPath $LedgerPath | Where-Object { $_.Trim() } | ForEach-Object {
    try { $_ | ConvertFrom-Json } catch { Write-Warning "Skipping unparseable line: $_" }
}
if ($Since) {
    $cutoff = [datetime]::Parse($Since).ToUniversalTime()
    $records = $records | Where-Object { [datetime]::Parse($_.timestamp) -ge $cutoff }
}
if (-not $records) { Write-Host 'No records in range.'; return }

$failureOutcomes = @('escalated', 'redone-by-parent', 'failed')

Write-Host "Delegation ledger: $($records.Count) record(s)$(if ($Since) { " since $Since" })`n"

$rows = $records | Group-Object category, model | ForEach-Object {
    $group = $_.Group
    # Dispatch counts live on every row, so 'ok' tally rows and failure rows both contribute to
    # the denominator — a failure row implies at least one dispatch of its own.
    $dispatched = ($group | Measure-Object -Property dispatches -Sum).Sum
    $failed = ($group | Where-Object { $_.outcome -in $failureOutcomes } |
        Measure-Object -Property dispatches -Sum).Sum
    [pscustomobject]@{
        Category   = $group[0].category
        Model      = $group[0].model
        # Measure-Object sums as double; these are counts and read wrong as 13.00.
        Dispatched = [int]$dispatched
        Failed     = [int]$failed
        Rate       = if ($dispatched) { [math]::Round($failed / $dispatched, 3) } else { 0 }
    }
}

$rows | Sort-Object -Property Rate -Descending |
    Format-Table Category, Model, Dispatched, Failed, @{ n = 'FailureShare'; e = { '{0:P1}' -f $_.Rate } } -AutoSize

$modes = $records | Where-Object { $_.failure_mode } | Group-Object failure_mode |
    Sort-Object Count -Descending
if ($modes) {
    Write-Host 'Failure modes:'
    foreach ($m in $modes) { Write-Host ("  {0,-24} {1}" -f $m.Name, $m.Count) }
    Write-Host ''
}

Write-Host 'Recommendations:'
$flagged = $false
foreach ($row in $rows | Sort-Object Rate -Descending) {
    if ($row.Dispatched -lt $MinSample) {
        Write-Host ("  {0}/{1}: insufficient data ({2} dispatch(es), need {3})" -f $row.Category, $row.Model, $row.Dispatched, $MinSample)
        continue
    }
    if ($row.Rate -gt $FailureThreshold) {
        $flagged = $true
        $common = $records |
            Where-Object { $_.category -eq $row.Category -and $_.model -eq $row.Model -and $_.failure_mode } |
            Group-Object failure_mode | Sort-Object Count -Descending | Select-Object -First 1
        $because = if ($common) { " — mostly $($common.Name)" } else { '' }
        Write-Host ("  STOP sending '{0}' to {1}: {2:P1} failure share over {3} dispatches{4}" -f $row.Category, $row.Model, $row.Rate, $row.Dispatched, $because) -ForegroundColor Yellow
    }
    else {
        Write-Host ("  '{0}' on {1} is holding up ({2:P1} over {3})" -f $row.Category, $row.Model, $row.Rate, $row.Dispatched)
    }
}
if (-not $flagged) { Write-Host '  Nothing exceeds the threshold. The cheap default is paying off.' }

$examples = $records | Where-Object { $_.outcome -in $failureOutcomes -and $_.evidence } |
    Select-Object -Last 3
if ($examples) {
    Write-Host "`nMost recent failures:"
    foreach ($e in $examples) {
        # ConvertFrom-Json turns the ISO string into a DateTime and would otherwise print it in
        # local culture format, which does not match what is actually stored in the ledger.
        $stamp = if ($e.timestamp -is [datetime]) { $e.timestamp.ToUniversalTime().ToString('yyyy-MM-dd HH:mmZ') } else { $e.timestamp }
        Write-Host ("  [{0}] {1}/{2} {3}: {4}" -f $stamp, $e.category, $e.model, $e.failure_mode, $e.evidence)
    }
}
