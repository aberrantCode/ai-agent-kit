# scripts/guard-pm-flow.ps1
# Pre-commit guard: rejects commits that touch source files when there is no
# active task file authorizing the change.
#
# Installed by /init-project. Intended to be wired into Git's pre-commit hook
# and (optionally) Claude Code's PreToolUse hook for Edit/Write.
#
# Bypass: set $env:PM_GUARD_BYPASS = "1" before committing. Bypasses are logged
# to docs/issues/guard-bypass.log so they're not silent.

#requires -Version 5.1

$ErrorActionPreference = 'Stop'

function Get-StagedFiles {
    $output = git diff --cached --name-only --diff-filter=ACMR 2>$null
    if (-not $output) { return @() }
    return @($output -split "`n" | Where-Object { $_ })
}

function Test-IsDocsFile {
    param([string]$Path)
    return $Path -match '^(docs/|scripts/|\.github/|\.claude/|AGENTS\.md$|CLAUDE\.md$|README\.md$|ROADMAP\.md$)'
}

function Get-ActiveTaskScope {
    $taskDir = 'docs/tasks/active'
    if (-not (Test-Path $taskDir)) { return $null }

    $taskFiles = Get-ChildItem -Path $taskDir -Filter '*.md' -File -ErrorAction SilentlyContinue
    if (-not $taskFiles) { return $null }

    $covers = @()
    foreach ($f in $taskFiles) {
        $content = Get-Content -Path $f.FullName -Raw
        if ($content -match '(?ms)^covers:\s*\[(.*?)\]') {
            $covers += $Matches[1]
        }
    }
    return $covers
}

function Write-BypassLog {
    param([string]$Reason, [string[]]$Files)
    $logPath = 'docs/issues/guard-bypass.log'
    $dir = Split-Path $logPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $stamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
    $line = "$stamp | $Reason | $($Files -join ',')"
    Add-Content -Path $logPath -Value $line
}

# --- Chore-lane validation ---
#
# See docs/reports/2026-07-16-pm-lifecycle-redesign.review.md §2.5. For any staged commit whose
# active task has `feature: chore-*`, the guard fails closed unless ALL of the following hold:
#   1. backlog_ref is present and the row exists in docs/backlog.md or docs/backlog-archive.md.
#   2. The authorization is frozen at promotion (authz_snapshot.bl_type/bl_status) and is still
#      chore-class — an `idea` row can never back a chore task.
#   3. authz_snapshot.manifest_sha still matches the live docs/workflow/scope-manifest.md hash —
#      otherwise the task is stale and must be re-groomed to re-freeze.
#   4. files_allowed is non-empty and does not intersect product_scope under the frozen manifest.
#   5. No staged file may edit scope-manifest.md or the backlog_ref row's own type/status cell in
#      the same commit (same-commit self-authorization block).
#   6. Every staged source file falls inside some chore task's files_allowed, and is either
#      chore_safe, or unclassified-with-scope_confirmed:true. A product_scope hit is always a
#      hard FAIL — scope_confirmed can never override it.
# This is the security-critical path: prefer failing closed over guessing.

function Get-FrontmatterBlock {
    param([string]$Content)
    if ($Content -match '(?s)^---\r?\n(.*?)\r?\n---\s*(\r?\n|$)') {
        return $Matches[1]
    }
    return $null
}

function Get-YamlListField {
    param([string]$FrontmatterBlock, [string]$FieldName)
    $pattern = '(?m)^' + [regex]::Escape($FieldName) + ':\s*\[(.*?)\]'
    if ($FrontmatterBlock -match $pattern) {
        $raw = $Matches[1]
        if (-not $raw.Trim()) { return @() }
        return @($raw -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ })
    }
    return @()
}

function Get-YamlScalarField {
    param([string]$FrontmatterBlock, [string]$FieldName)
    $pattern = '(?m)^\s*' + [regex]::Escape($FieldName) + ':\s*"?([^"\r\n]*?)"?\s*$'
    if ($FrontmatterBlock -match $pattern) {
        return $Matches[1].Trim()
    }
    return $null
}

function Get-ActiveChoreTasks {
    $taskDir = 'docs/tasks/active'
    if (-not (Test-Path $taskDir)) { return @() }

    $taskFiles = Get-ChildItem -Path $taskDir -Filter '*.md' -File -ErrorAction SilentlyContinue
    if (-not $taskFiles) { return @() }

    $chores = @()
    foreach ($f in $taskFiles) {
        $content = Get-Content -Path $f.FullName -Raw
        $fm = Get-FrontmatterBlock $content
        if (-not $fm) { continue }

        $feature = Get-YamlScalarField -FrontmatterBlock $fm -FieldName 'feature'
        if (-not $feature -or $feature -notmatch '^chore-') { continue }

        $backlogRef = Get-YamlScalarField -FrontmatterBlock $fm -FieldName 'backlog_ref'
        $filesAllowed = Get-YamlListField -FrontmatterBlock $fm -FieldName 'files_allowed'
        $scopeConfirmedRaw = Get-YamlScalarField -FrontmatterBlock $fm -FieldName 'scope_confirmed'
        $scopeConfirmed = ($scopeConfirmedRaw -ieq 'true')

        $authzBlType = $null
        $authzBlStatus = $null
        $authzManifestSha = $null
        if ($fm -match '(?ms)^authz_snapshot:\s*$\r?\n((?:[ \t]+\S.*(?:\r?\n|$))+)') {
            $block = $Matches[1]
            $authzBlType = Get-YamlScalarField -FrontmatterBlock $block -FieldName 'bl_type'
            $authzBlStatus = Get-YamlScalarField -FrontmatterBlock $block -FieldName 'bl_status'
            $authzManifestSha = Get-YamlScalarField -FrontmatterBlock $block -FieldName 'manifest_sha'
        }

        $chores += [PSCustomObject]@{
            Path             = $f.FullName
            Feature          = $feature
            BacklogRef       = $backlogRef
            FilesAllowed     = $filesAllowed
            ScopeConfirmed   = $scopeConfirmed
            AuthzBlType      = $authzBlType
            AuthzBlStatus    = $authzBlStatus
            AuthzManifestSha = $authzManifestSha
        }
    }
    return $chores
}

function Test-GlobMatch {
    param([string]$Path, [string]$Glob)
    $escaped = [regex]::Escape($Glob)
    $escaped = $escaped -replace '\\\*\\\*', '@@GLOBSTAR@@'
    $escaped = $escaped -replace '\\\*', '[^/]*'
    $escaped = $escaped -replace '\\\?', '[^/]'
    $escaped = $escaped -replace '@@GLOBSTAR@@', '.*'
    $pattern = '^' + $escaped + '$'
    return [System.Text.RegularExpressions.Regex]::IsMatch($Path, $pattern)
}

function Test-SingleSegmentOverlap {
    # Do two single path-segment glob fragments (no '/', may contain '*'/'?') describe an
    # overlapping set of strings? Exact match, either side is a bare '*', or a wildcard sample
    # from one side satisfies the other side's pattern (checked both directions).
    param([string]$SegA, [string]$SegB)
    if ($SegA -eq $SegB) { return $true }
    if ($SegA -eq '*' -or $SegB -eq '*') { return $true }
    $regexA = '^' + (([regex]::Escape($SegA) -replace '\\\*', '.*') -replace '\\\?', '.') + '$'
    $regexB = '^' + (([regex]::Escape($SegB) -replace '\\\*', '.*') -replace '\\\?', '.') + '$'
    $sampleFromA = ($SegA -replace '\*', 'x' -replace '\?', 'x')
    if ($sampleFromA -match $regexB) { return $true }
    $sampleFromB = ($SegB -replace '\*', 'x' -replace '\?', 'x')
    if ($sampleFromB -match $regexA) { return $true }
    return $false
}

function Test-GlobSegmentsCanBeEmpty {
    # True if every remaining segment from Index onward is '**' (each can match zero segments).
    param([string[]]$Segments, [int]$Index)
    for ($i = $Index; $i -lt $Segments.Count; $i++) {
        if ($Segments[$i] -ne '**') { return $false }
    }
    return $true
}

function Test-GlobSegmentsIntersectRecursive {
    param([string[]]$SegsA, [int]$IndexA, [string[]]$SegsB, [int]$IndexB)

    if ($IndexA -ge $SegsA.Count -and $IndexB -ge $SegsB.Count) { return $true }
    if ($IndexA -ge $SegsA.Count) { return (Test-GlobSegmentsCanBeEmpty -Segments $SegsB -Index $IndexB) }
    if ($IndexB -ge $SegsB.Count) { return (Test-GlobSegmentsCanBeEmpty -Segments $SegsA -Index $IndexA) }

    $segA = $SegsA[$IndexA]
    $segB = $SegsB[$IndexB]

    if ($segA -eq '**') {
        # '**' may consume zero segments (advance past it) or one-more segment of B.
        if (Test-GlobSegmentsIntersectRecursive -SegsA $SegsA -IndexA ($IndexA + 1) -SegsB $SegsB -IndexB $IndexB) { return $true }
        return (Test-GlobSegmentsIntersectRecursive -SegsA $SegsA -IndexA $IndexA -SegsB $SegsB -IndexB ($IndexB + 1))
    }
    if ($segB -eq '**') {
        if (Test-GlobSegmentsIntersectRecursive -SegsA $SegsA -IndexA $IndexA -SegsB $SegsB -IndexB ($IndexB + 1)) { return $true }
        return (Test-GlobSegmentsIntersectRecursive -SegsA $SegsA -IndexA ($IndexA + 1) -SegsB $SegsB -IndexB $IndexB)
    }

    if (-not (Test-SingleSegmentOverlap -SegA $segA -SegB $segB)) { return $false }
    return (Test-GlobSegmentsIntersectRecursive -SegsA $SegsA -IndexA ($IndexA + 1) -SegsB $SegsB -IndexB ($IndexB + 1))
}

function Test-GlobsIntersect {
    # Segment-wise glob/glob intersection: could some real path match BOTH GlobA and GlobB?
    # '**' matches zero-or-more path segments; a single '*'/'?' is confined to one segment
    # (mirrors Test-GlobMatch's semantics). This is deliberately structural rather than a crude
    # string-prefix check, so root-anchored single-segment globs like '*.md' or '*.config.*'
    # (both listed in chore_safe by default) are not falsely flagged as intersecting
    # directory-rooted product_scope globs like 'src/**'.
    param([string]$GlobA, [string]$GlobB)
    if ($GlobA -eq $GlobB) { return $true }
    $segsA = @($GlobA -split '/')
    $segsB = @($GlobB -split '/')
    return (Test-GlobSegmentsIntersectRecursive -SegsA $segsA -IndexA 0 -SegsB $segsB -IndexB 0)
}

function Get-ManifestGlobs {
    param([string]$ManifestPath)
    $content = Get-Content -Path $ManifestPath -Raw
    $fm = Get-FrontmatterBlock $content
    if (-not $fm) { return $null }
    return [PSCustomObject]@{
        ProductScope = Get-YamlListField -FrontmatterBlock $fm -FieldName 'product_scope'
        ChoreSafe    = Get-YamlListField -FrontmatterBlock $fm -FieldName 'chore_safe'
    }
}

function Get-BacklogRow {
    param([string]$BacklogRef)
    foreach ($path in @('docs/backlog.md', 'docs/backlog-archive.md')) {
        if (-not (Test-Path $path)) { continue }
        $content = Get-Content -Path $path -Raw
        $stripped = [regex]::Replace($content, '(?s)<!--.*?-->', '')
        $pattern = '(?m)^\s*\|\s*' + [regex]::Escape($BacklogRef) + '\s*\|.*$'
        if ($stripped -match $pattern) {
            return [PSCustomObject]@{ File = $path; Line = $Matches[0] }
        }
    }
    return $null
}

function Test-BacklogRowAuthzFieldsChanged {
    # Detects whether the cached diff for a staged backlog file changes the Type or Status cell
    # of THIS backlog_ref's row. A row that is only added (new) or entirely unchanged is fine —
    # only a modification of an existing row's authorization cells trips this gate.
    param([string]$BacklogRef, [string[]]$StagedFiles)
    $normalizedStaged = @($StagedFiles | ForEach-Object { $_ -replace '\\', '/' })
    foreach ($path in @('docs/backlog.md', 'docs/backlog-archive.md')) {
        if ($normalizedStaged -notcontains $path) { continue }
        $diff = git diff --cached -- $path 2>$null
        if (-not $diff) { continue }
        $diffLines = @($diff -split "`n")
        $refPattern = '^-\s*\|\s*' + [regex]::Escape($BacklogRef) + '\s*\|'
        $addPattern = '^\+\s*\|\s*' + [regex]::Escape($BacklogRef) + '\s*\|'
        $removed = @($diffLines | Where-Object { $_ -match $refPattern })
        $added = @($diffLines | Where-Object { $_ -match $addPattern })
        if ($removed.Count -gt 0 -and $added.Count -gt 0) {
            $oldCells = ($removed[0] -replace '^-', '') -split '\|'
            $newCells = ($added[0] -replace '^\+', '') -split '\|'
            if ($oldCells.Count -gt 5 -and $newCells.Count -gt 5) {
                $oldType = $oldCells[2].Trim()
                $newType = $newCells[2].Trim()
                $oldStatus = $oldCells[5].Trim()
                $newStatus = $newCells[5].Trim()
                if ($oldType -ne $newType -or $oldStatus -ne $newStatus) {
                    return $true
                }
            }
        }
    }
    return $false
}

function Write-ChoreGuardFailure {
    param([string]$Reason, [string]$TaskPath)
    Write-Host ''
    Write-Host 'project-manager guard: commit blocked (chore lane).' -ForegroundColor Red
    Write-Host ''
    if ($TaskPath) {
        Write-Host "Task: $TaskPath" -ForegroundColor Red
    }
    Write-Host $Reason -ForegroundColor Red
    Write-Host ''
    Write-Host 'The chore lane is enforced, not honor-system. Fix the underlying authorization' -ForegroundColor Yellow
    Write-Host '(re-groom the task, correct the backlog row, or route the change through' -ForegroundColor Yellow
    Write-Host '/groom -> /add-feature) rather than working around this check.' -ForegroundColor Yellow
    Write-Host ''
}

function Invoke-ChoreLaneGuard {
    param([string[]]$Staged, [string[]]$SourceChanges, [object[]]$ChoreTasks)

    $manifestPath = 'docs/workflow/scope-manifest.md'

    if (-not (Test-Path $manifestPath)) {
        Write-ChoreGuardFailure "chore lane inert: $manifestPath missing. Run /init-project or /reinit to scaffold it."
        exit 1
    }

    $manifestGlobs = Get-ManifestGlobs -ManifestPath $manifestPath
    if ($null -eq $manifestGlobs) {
        Write-ChoreGuardFailure "$manifestPath is missing parseable product_scope/chore_safe frontmatter."
        exit 1
    }

    $liveManifestSha = (Get-FileHash -Path $manifestPath -Algorithm SHA256).Hash

    $normalizedStaged = @($Staged | ForEach-Object { $_ -replace '\\', '/' })
    if ($normalizedStaged -contains $manifestPath) {
        Write-ChoreGuardFailure 'self-authorization: a chore commit may not edit its own scope-manifest (docs/workflow/scope-manifest.md). Land manifest changes in a separate, normally-reviewed commit.'
        exit 1
    }

    $validTypes = @('bug', 'chore', 'debt')
    $validStatuses = @('triaged', 'promoted')

    foreach ($task in $ChoreTasks) {
        if ([string]::IsNullOrWhiteSpace($task.BacklogRef)) {
            Write-ChoreGuardFailure 'backlog_ref missing: a chore task must link to a backlog row.' -TaskPath $task.Path
            exit 1
        }

        $row = Get-BacklogRow -BacklogRef $task.BacklogRef
        if ($null -eq $row) {
            Write-ChoreGuardFailure "backlog_ref $($task.BacklogRef) not found in docs/backlog.md or docs/backlog-archive.md." -TaskPath $task.Path
            exit 1
        }

        if (-not $task.AuthzBlType -or ($validTypes -notcontains $task.AuthzBlType) -or
            -not $task.AuthzBlStatus -or ($validStatuses -notcontains $task.AuthzBlStatus)) {
            Write-ChoreGuardFailure "authz_snapshot invalid (bl_type='$($task.AuthzBlType)', bl_status='$($task.AuthzBlStatus)') — an idea row, or an untriaged/unpromoted row, can never back a chore task." -TaskPath $task.Path
            exit 1
        }

        if ([string]::IsNullOrWhiteSpace($task.AuthzManifestSha) -or $task.AuthzManifestSha -ine $liveManifestSha) {
            Write-ChoreGuardFailure 'stale: scope-manifest changed since promotion — re-groom to re-freeze.' -TaskPath $task.Path
            exit 1
        }

        if ($task.FilesAllowed.Count -eq 0) {
            Write-ChoreGuardFailure 'files_allowed is empty — a chore task must have a frozen reviewed scope.' -TaskPath $task.Path
            exit 1
        }

        $intersects = $false
        foreach ($fa in $task.FilesAllowed) {
            foreach ($ps in $manifestGlobs.ProductScope) {
                if (Test-GlobsIntersect -GlobA $fa -GlobB $ps) { $intersects = $true; break }
            }
            if ($intersects) { break }
        }
        if ($intersects) {
            Write-ChoreGuardFailure 'files_allowed intersects product_scope — reviewed scope must not overlap behaviour-bearing code.' -TaskPath $task.Path
            exit 1
        }

        if (Test-BacklogRowAuthzFieldsChanged -BacklogRef $task.BacklogRef -StagedFiles $Staged) {
            Write-ChoreGuardFailure "self-authorization: a chore commit may not edit its backlog_ref ($($task.BacklogRef)) row's type/status cell. Land classification changes separately." -TaskPath $task.Path
            exit 1
        }
    }

    foreach ($file in $SourceChanges) {
        $normalizedFile = $file -replace '\\', '/'

        $authorizingTask = $null
        foreach ($task in $ChoreTasks) {
            foreach ($fa in $task.FilesAllowed) {
                if (Test-GlobMatch -Path $normalizedFile -Glob $fa) { $authorizingTask = $task; break }
            }
            if ($authorizingTask) { break }
        }
        if (-not $authorizingTask) {
            Write-ChoreGuardFailure "staged file outside files_allowed: $normalizedFile"
            exit 1
        }

        $isProductScope = $false
        foreach ($ps in $manifestGlobs.ProductScope) {
            if (Test-GlobMatch -Path $normalizedFile -Glob $ps) { $isProductScope = $true; break }
        }
        if ($isProductScope) {
            Write-ChoreGuardFailure "product-scope file on chore lane: $normalizedFile — route through /groom -> feature (spec + plan). scope_confirmed cannot override this."
            exit 1
        }

        $isChoreSafe = $false
        foreach ($cs in $manifestGlobs.ChoreSafe) {
            if (Test-GlobMatch -Path $normalizedFile -Glob $cs) { $isChoreSafe = $true; break }
        }
        if (-not $isChoreSafe -and -not $authorizingTask.ScopeConfirmed) {
            Write-ChoreGuardFailure "unclassified file needs scope_confirmed: $normalizedFile is neither product_scope nor chore_safe, and its authorizing task ($($authorizingTask.Path)) has scope_confirmed: false."
            exit 1
        }
    }

    Write-Host 'project-manager guard: chore lane checks passed.' -ForegroundColor Green
    exit 0
}

# --- Main ---

$staged = Get-StagedFiles
if ($staged.Count -eq 0) { exit 0 }

$sourceChanges = @($staged | Where-Object { -not (Test-IsDocsFile $_) })
if ($sourceChanges.Count -eq 0) { exit 0 }

$activeScope = Get-ActiveTaskScope

if ($env:PM_GUARD_BYPASS -eq '1') {
    Write-BypassLog -Reason 'PM_GUARD_BYPASS=1' -Files $sourceChanges
    Write-Host 'project-manager guard: BYPASSED (logged to docs/issues/guard-bypass.log)' -ForegroundColor Yellow
    exit 0
}

# Chore-lane commits have an empty `covers:` list by design and must NOT fall through to the
# feature-lane "no active scope" check below — they are validated (and always exit) here instead.
$choreTasks = Get-ActiveChoreTasks
if ($choreTasks.Count -gt 0) {
    Invoke-ChoreLaneGuard -Staged $staged -SourceChanges $sourceChanges -ChoreTasks $choreTasks
}

if ($null -eq $activeScope -or $activeScope.Count -eq 0) {
    Write-Host ''
    Write-Host 'project-manager guard: commit blocked.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'You are committing changes to source files but there is no active task file' -ForegroundColor Red
    Write-Host 'in docs/tasks/active/.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Changed source files:' -ForegroundColor Red
    $sourceChanges | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'Options:' -ForegroundColor Yellow
    Write-Host '  1. Run /continue-tasks to enter the orchestration loop and have a task file generated' -ForegroundColor Yellow
    Write-Host '  2. Move the changes into docs/ if they are documentation only' -ForegroundColor Yellow
    Write-Host '  3. Set $env:PM_GUARD_BYPASS=1 to bypass (logged to docs/issues/guard-bypass.log)' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

exit 0
