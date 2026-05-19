#Requires -Version 5.1
param([string]$Root = '.', [int]$StaleHours = 24)

. "$PSScriptRoot/ProjectManager.Common.ps1"
$state = Get-PmState -Root (Get-PmRoot $Root) -StaleHours $StaleHours

"# Project Manager Next"
""
if (@($state.ActiveTasks | Where-Object { $_.CompletionState -in @('none', 'stale', 'malformed') }).Count -gt 0) {
    "Active task files need reconciliation before new work:"
    $rows = @($state.ActiveTasks | Sort-Object Name | Select-Object Name, Feature, CompletionState, CompletionStatus, AgeHours, ClaimedBy, LeaseExpiresAt)
    Write-PmTable $rows @('Name', 'Feature', 'CompletionState', 'CompletionStatus', 'AgeHours', 'ClaimedBy', 'LeaseExpiresAt')
    exit 0
}

$implemented = @{}
foreach ($spec in $state.Specs) {
    if ($spec.Status -eq 'implemented') { $implemented[$spec.Slug] = $true }
}
foreach ($plan in $state.Plans) {
    if (@($plan.Rows | Where-Object { $_.Status -ne 'done' }).Count -eq 0) { $implemented[$plan.Feature] = $true }
}

$candidates = New-Object System.Collections.Generic.List[object]
foreach ($plan in ($state.Plans | Sort-Object Feature)) {
    $spec = @($state.Specs | Where-Object Slug -eq $plan.Feature | Select-Object -First 1)
    if (-not $spec -or $spec.Status -ne 'approved') { continue }
    $blockedBy = @($spec.DependsOn | Where-Object { -not $implemented[$_] })
    if ($blockedBy.Count -gt 0) { continue }
    foreach ($row in @($plan.Rows | Sort-Object Phase, Task)) {
        if ($row.Status -eq 'todo') {
            $candidates.Add([pscustomobject]@{
                Feature = $row.Feature
                Phase = $row.Phase
                Task = $row.Task
                Role = $row.Role
                Covers = $row.Covers
                Description = $row.Description
            })
            break
        }
    }
}

if ($candidates.Count -eq 0) {
    "No eligible todo task found."
} else {
    Write-PmTable @($candidates | Select-Object -First 10) @('Feature', 'Phase', 'Task', 'Role', 'Covers', 'Description')
}
