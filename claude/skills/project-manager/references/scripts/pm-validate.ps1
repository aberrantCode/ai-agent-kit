#Requires -Version 5.1
param([string]$Root = '.', [int]$StaleHours = 24)

. "$PSScriptRoot/ProjectManager.Common.ps1"
$state = Get-PmState -Root (Get-PmRoot $Root) -StaleHours $StaleHours
$script:PmValidationErrors = New-Object System.Collections.Generic.List[object]
$script:PmValidationWarnings = New-Object System.Collections.Generic.List[object]

function Add-Issue($severity, $code, $path, $message) {
    if ($severity -eq 'error') {
        $target = $script:PmValidationErrors
    } else {
        $target = $script:PmValidationWarnings
    }
    $target.Add([pscustomobject]@{ Severity = $severity; Code = $code; Path = $path; Message = $message })
}

$allowedSpecStatus = @('draft', 'approved', 'implemented', 'deprecated')
$allowedPriority = @('p0', 'p1', 'p2', 'p3')
$allowedPlanStatus = @('todo', 'in-progress', 'done', 'blocked')
$slugs = @{}

foreach ($spec in $state.Specs) {
    if ($slugs[$spec.Slug]) { Add-Issue error 'duplicate-spec-slug' $spec.Path "Duplicate feature slug '$($spec.Slug)'." }
    $slugs[$spec.Slug] = $true
    foreach ($field in @('feature', 'slug', 'status', 'priority', 'area', 'depends_on', 'last_updated')) {
        if (-not $spec.Frontmatter.Contains($field)) { Add-Issue error 'missing-spec-field' $spec.Path "Missing frontmatter field '$field'." }
    }
    if ($spec.Status -notin $allowedSpecStatus) { Add-Issue error 'invalid-spec-status' $spec.Path "Invalid status '$($spec.Status)'." }
    if ($spec.Priority -and $spec.Priority -notin $allowedPriority) { Add-Issue error 'invalid-priority' $spec.Path "Invalid priority '$($spec.Priority)'." }
    foreach ($cap in $spec.Capabilities) {
        if ($cap -notmatch '^[A-Z]{2}-CAP-\d{2,}$') { Add-Issue error 'invalid-cap-id' $spec.Path "Invalid CAP-ID '$cap'." }
    }
}

foreach ($spec in $state.Specs) {
    foreach ($dep in @($spec.DependsOn)) {
        if (-not $slugs[$dep]) { Add-Issue error 'missing-dependency' $spec.Path "Missing dependency slug '$dep'." }
    }
}
foreach ($cycle in $state.Cycles) { Add-Issue error 'dependency-cycle' '' $cycle }

foreach ($plan in $state.Plans) {
    foreach ($field in @('feature', 'status', 'failures', 'last_updated')) {
        if (-not $plan.Frontmatter.Contains($field)) { Add-Issue warning 'missing-plan-field' $plan.Path "Missing frontmatter field '$field'." }
    }
    $spec = @($state.Specs | Where-Object Slug -eq $plan.Feature | Select-Object -First 1)
    if (-not $spec) { Add-Issue error 'plan-without-spec' $plan.Path "No matching feature spec for '$($plan.Feature)'." }
    elseif ($spec.Status -eq 'draft') { Add-Issue error 'draft-spec-has-plan' $plan.Path "Plan exists for draft spec '$($spec.Slug)'." }
    foreach ($row in @($plan.Rows)) {
        if ($row.Status -notin $allowedPlanStatus) { Add-Issue error 'invalid-task-status' $plan.Path "Task $($row.Phase).$($row.Task) has invalid status '$($row.Status)'." }
        foreach ($cap in @($row.Covers)) {
            if ($spec -and $spec.Capabilities -notcontains $cap) { Add-Issue warning 'unregistered-cap-coverage' $plan.Path "Task covers '$cap' not found in spec '$($spec.Slug)'." }
        }
    }
    if ($spec) {
        foreach ($cap in @($spec.Capabilities)) {
            if (@($plan.Rows | Where-Object { $_.Covers -contains $cap }).Count -eq 0) {
                Add-Issue error 'missing-cap-coverage' $plan.Path "No plan task covers '$cap'."
            }
        }
    }
    $verificationBacklog = @($plan.Rows | Where-Object {
        $_.Notes -match 'verification pending' -or (($_.Role -match 'implementation|feature|api|build|security|ui|frontend|backend|database|migration|refactor|cleanup') -and $_.Status -eq 'done' -and $_.Notes -notmatch 'verified')
    })
    foreach ($row in $verificationBacklog) {
        Add-Issue warning 'verification-backlog' $plan.Path "Task $($row.Phase).$($row.Task) may need verification for $($row.Covers -join ',')."
    }
}

foreach ($task in $state.ActiveTasks) {
    foreach ($field in @('feature', 'phase', 'task', 'covers', 'role', 'agent', 'status', 'created', 'claimed_by', 'claimed_at', 'lease_expires_at')) {
        if (-not $task.Frontmatter.Contains($field)) { Add-Issue warning 'missing-task-field' $task.Path "Missing frontmatter field '$field'." }
    }
    if ($task.CompletionState -eq 'malformed') { Add-Issue error 'malformed-completion' $task.Path 'Final ## Completion block is missing a valid Status field.' }
    if ($task.CompletionState -eq 'stale') { Add-Issue warning 'stale-active-task' $task.Path "No valid sentinel after $($task.AgeHours) hours." }
    if ($task.LeaseExpiresAt) {
        try {
            if ([datetime]$task.LeaseExpiresAt -lt (Get-Date)) { Add-Issue warning 'expired-lease' $task.Path "Lease expired at $($task.LeaseExpiresAt)." }
        } catch {
            Add-Issue error 'invalid-lease-date' $task.Path "Invalid lease_expires_at '$($task.LeaseExpiresAt)'."
        }
    }
}

"# Project Manager Validation"
""
"Root: $($state.Root)"
""
"## Errors"
Write-PmTable @($script:PmValidationErrors.ToArray()) @('Severity', 'Code', 'Path', 'Message')
""
"## Warnings"
Write-PmTable @($script:PmValidationWarnings.ToArray()) @('Severity', 'Code', 'Path', 'Message')
""
"Result: " + $(if ($script:PmValidationErrors.Count -eq 0) { 'pass' } else { 'fail' })
if ($script:PmValidationErrors.Count -gt 0) { exit 1 }
