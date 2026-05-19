#Requires -Version 5.1
param([string]$Root = '.', [int]$StaleHours = 24)

. "$PSScriptRoot/ProjectManager.Common.ps1"
$state = Get-PmState -Root (Get-PmRoot $Root) -StaleHours $StaleHours
$rows = @($state.Plans | ForEach-Object { $_.Rows } | ForEach-Object { $_ })
$done = @($rows | Where-Object Status -eq 'done').Count
$total = $rows.Count
$pct = if ($total -gt 0) { [math]::Round(($done / $total) * 100, 1) } else { 0 }

"# Project Manager Status"
""
"Root: $($state.Root)"
"Generated: $((Get-Date).ToString('s'))"
""
"| Metric | Value |"
"|---|---:|"
"| Feature specs | $($state.Specs.Count) |"
"| Plans | $($state.Plans.Count) |"
"| Tasks total | $total |"
"| Tasks done | $done |"
"| Completion | $pct% |"
"| Active tasks | $($state.ActiveTasks.Count) |"
"| Open issues | $($state.Issues.Count) |"
""
"## Spec Statuses"
$specRows = @($state.Specs | Group-Object Status | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ Status = if ($_.Name) { $_.Name } else { 'malformed' }; Count = $_.Count }
})
Write-PmTable $specRows @('Status', 'Count')
""
"## Plan Progress"
$planRows = @($state.Plans | Sort-Object Feature | ForEach-Object {
    $r = @($_.Rows)
    [pscustomobject]@{
        Feature = $_.Feature
        Todo = @($r | Where-Object Status -eq 'todo').Count
        InProgress = @($r | Where-Object Status -eq 'in-progress').Count
        Done = @($r | Where-Object Status -eq 'done').Count
        Blocked = @($r | Where-Object Status -eq 'blocked').Count
    }
})
Write-PmTable $planRows @('Feature', 'Todo', 'InProgress', 'Done', 'Blocked')
