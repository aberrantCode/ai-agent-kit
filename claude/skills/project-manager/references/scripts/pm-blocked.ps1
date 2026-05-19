#Requires -Version 5.1
param([string]$Root = '.', [int]$StaleHours = 24)

. "$PSScriptRoot/ProjectManager.Common.ps1"
$state = Get-PmState -Root (Get-PmRoot $Root) -StaleHours $StaleHours

"# Project Manager Blocked"
""
$blockedRows = @($state.Plans | ForEach-Object { $_.Rows } | Where-Object Status -eq 'blocked' | Sort-Object Feature, Phase, Task)
"## Blocked Plan Tasks"
Write-PmTable $blockedRows @('Feature', 'Phase', 'Task', 'Role', 'Covers', 'Notes')
""
"## Dependency Problems"
$missing = @()
$slugs = @{}
foreach ($spec in $state.Specs) { $slugs[$spec.Slug] = $true }
foreach ($spec in $state.Specs) {
    foreach ($dep in @($spec.DependsOn)) {
        if (-not $slugs[$dep]) {
            $missing += [pscustomobject]@{ Feature = $spec.Slug; MissingDependency = $dep }
        }
    }
}
Write-PmTable $missing @('Feature', 'MissingDependency')
""
"## Dependency Cycles"
if ($state.Cycles.Count -eq 0) { "_none_" } else { $state.Cycles | ForEach-Object { "- $_" } }
""
"## Open Issues"
$issueRows = @($state.Issues | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Path = $_.FullName } })
Write-PmTable $issueRows @('Name', 'Path')
