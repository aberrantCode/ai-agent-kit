<#
.SYNOPSIS
    Append one delegation outcome to the cross-session ledger.

.DESCRIPTION
    Cheap-model delegation is a bet: most tasks do not need a frontier model, so defaulting
    subagents to haiku saves real money. The bet is only checkable if the losses are recorded.
    Without a ledger, the evidence is anecdote — "haiku seemed flaky that one time" — which is not
    enough to change a policy in either direction.

    Two kinds of row go in here:

      * A per-session tally (-Dispatches N) recording how many subagents were sent to a model.
        This is the denominator. Escalations without it produce a scary-looking list of failures
        with no idea whether it is 5 out of 8 or 5 out of 400.
      * One row per escalation or redo, describing what the cheap model actually got wrong.

    Failure modes are a fixed vocabulary on purpose. Free-text descriptions cannot be aggregated,
    and the whole point is to answer "which *categories* of work should stop going to haiku",
    which requires the categories to be comparable across sessions.

.PARAMETER Category
    What kind of work was delegated. Aggregation happens along this axis.

.PARAMETER Model
    The model the work was originally dispatched to.

.PARAMETER Outcome
    ok            — completed acceptably (use with -Dispatches for tallies)
    escalated     — re-dispatched to a stronger model
    redone-by-parent — the main session gave up and did it itself
    failed        — nobody recovered it; the task was dropped or the session stalled

.PARAMETER FailureMode
    Required for anything other than 'ok'. What went wrong, from a fixed vocabulary.

.PARAMETER Evidence
    One line of concrete evidence: the wrong value returned, the invented path, the constraint
    ignored. Keep it short but specific — "was vague" helps nobody later.

.EXAMPLE
    # denominator row, once per session
    log-delegation-outcome.ps1 -Category search -Model haiku -Outcome ok -Dispatches 12

.EXAMPLE
    log-delegation-outcome.ps1 -Category extract -Model haiku -Outcome escalated `
        -FailureMode wrong-answer -EscalatedTo sonnet `
        -Evidence 'reported 46,929 approved rows; actual journal count was 55,644' `
        -Repo dropbox_audit -Branch refactor/reset-move-queue
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('search', 'extract', 'summarize', 'edit', 'test-run', 'verify', 'docs', 'other')]
    [string]$Category,

    [Parameter(Mandatory = $true)][string]$Model,

    [Parameter(Mandatory = $true)]
    [ValidateSet('ok', 'escalated', 'redone-by-parent', 'failed')]
    [string]$Outcome,

    [ValidateSet('wrong-answer', 'incomplete', 'hallucinated-reference', 'ignored-constraint',
        'format-violation', 'timeout', 'tool-misuse', 'other')]
    [string]$FailureMode,

    [string]$EscalatedTo,
    [string]$Evidence,
    [string]$Task,
    [string]$Repo,
    [string]$Branch,
    [string]$PromptPath,
    [int]$Dispatches = 1,
    [string]$LedgerPath = (Join-Path $env:USERPROFILE '.claude\telemetry\delegation-outcomes.jsonl')
)

$ErrorActionPreference = 'Stop'

if ($Outcome -ne 'ok' -and -not $FailureMode) {
    throw "-FailureMode is required when -Outcome is '$Outcome'. An unexplained failure cannot be aggregated, which defeats the purpose of logging it."
}
if ($Outcome -ne 'ok' -and -not $Evidence) {
    Write-Warning 'No -Evidence given. Future-you will not be able to tell whether this was a real model limitation or a bad prompt.'
}
if ($Outcome -eq 'ok' -and -not ($PromptPath -or $Branch -or $Task)) {
    Write-Warning 'This tally has no -PromptPath/-Branch/-Task tag, so complete-task-session.ps1 cannot correlate it to a session and the retirement gate will not credit it. Tag totals rows with -PromptPath (the handoff prompt).'
}

$dir = Split-Path -Parent $LedgerPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$record = [ordered]@{
    timestamp    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    category     = $Category
    model        = $Model
    outcome      = $Outcome
    dispatches   = $Dispatches
    failure_mode = $FailureMode
    escalated_to = $EscalatedTo
    evidence     = $Evidence
    task         = $Task
    repo         = $Repo
    branch       = $Branch
    prompt       = $PromptPath
}

# One JSON object per line: append-only, survives concurrent sessions, greppable without a parser.
($record | ConvertTo-Json -Compress -Depth 3) | Add-Content -LiteralPath $LedgerPath -Encoding UTF8
Write-Host "Logged $Outcome ($Category/$Model) to $LedgerPath"
