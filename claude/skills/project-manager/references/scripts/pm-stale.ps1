#Requires -Version 5.1
param([string]$Root = '.', [int]$StaleHours = 24)

. "$PSScriptRoot/ProjectManager.Common.ps1"
$state = Get-PmState -Root (Get-PmRoot $Root) -StaleHours $StaleHours

"# Project Manager Stale"
""
$rows = @($state.ActiveTasks | Where-Object { $_.CompletionState -in @('stale', 'malformed') -or ($_.LeaseExpiresAt -and ([datetime]$_.LeaseExpiresAt) -lt (Get-Date)) } |
    Sort-Object CompletionState, Name |
    Select-Object Name, Feature, CompletionState, CompletionStatus, AgeHours, ClaimedBy, LeaseExpiresAt)
Write-PmTable $rows @('Name', 'Feature', 'CompletionState', 'CompletionStatus', 'AgeHours', 'ClaimedBy', 'LeaseExpiresAt')
