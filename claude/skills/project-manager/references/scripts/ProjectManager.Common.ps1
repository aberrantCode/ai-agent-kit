#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

function Get-PmRoot {
    param([string]$StartPath = (Get-Location).Path)

    $dir = Resolve-Path -LiteralPath $StartPath
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir 'docs/features') -PathType Container) {
            return $dir.Path
        }
        $parent = Split-Path -Parent $dir.Path
        if (-not $parent -or $parent -eq $dir.Path) { break }
        $dir = Resolve-Path -LiteralPath $parent
    }
    return (Resolve-Path -LiteralPath $StartPath).Path
}

function ConvertFrom-PmFrontmatter {
    param([string]$Content)

    $result = [ordered]@{}
    if ($Content -notmatch '(?s)^---\r?\n(.*?)\r?\n---') { return $result }
    $lines = $Matches[1] -split "\r?\n"
    foreach ($line in $lines) {
        if ($line -match '^\s*([A-Za-z0-9_-]+):\s*(.*)\s*$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            if ($value -match '^\[(.*)\]$') {
                $inner = $Matches[1].Trim()
                if ($inner.Length -eq 0) { $result[$key] = @() }
                else {
                    $result[$key] = @($inner -split ',' | ForEach-Object {
                        $_.Trim().Trim('"').Trim("'")
                    } | Where-Object { $_ })
                }
            } else {
                $result[$key] = $value.Trim('"').Trim("'")
            }
        }
    }
    return $result
}

function Get-PmMarkdownFiles {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $Path -Filter '*.md' -File |
        Where-Object { $_.Name -notin @('README.md', 'template.md') } |
        Sort-Object Name)
}

function Get-PmSpec {
    param([System.IO.FileInfo]$File)

    $content = Get-Content -LiteralPath $File.FullName -Raw
    $fm = ConvertFrom-PmFrontmatter $content
    $slug = if ($fm.slug) { [string]$fm.slug } else { [IO.Path]::GetFileNameWithoutExtension($File.Name) }
    $deps = @()
    if ($fm.depends_on -is [array]) { $deps = @($fm.depends_on) }
    elseif ($fm.depends_on) { $deps = @([string]$fm.depends_on) }
    $caps = @([regex]::Matches($content, '\[[A-Z]{2}-CAP-\d{2,}\]') | ForEach-Object { $_.Value.Trim('[', ']') } | Sort-Object -Unique)
    [pscustomobject]@{
        Path = $File.FullName
        Name = $File.Name
        Slug = $slug
        Status = if ($fm.status) { [string]$fm.status } else { '' }
        Priority = if ($fm.priority) { [string]$fm.priority } else { '' }
        DependsOn = $deps
        Capabilities = $caps
        Frontmatter = $fm
    }
}

function Get-PmPlanRows {
    param([System.IO.FileInfo]$File)

    $content = Get-Content -LiteralPath $File.FullName -Raw
    $fm = ConvertFrom-PmFrontmatter $content
    $feature = if ($fm.feature) { [string]$fm.feature } else { $File.BaseName -replace '-plan$', '' }
    $phase = 0
    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($line in ($content -split "\r?\n")) {
        if ($line -match '^##\s+Phase\s+(\d+)') { $phase = [int]$Matches[1] }
        if ($line -match '^\|\s*(\d+)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*`?([^|`]+)`?\s*\|\s*([A-Za-z-]+)\s*\|\s*(.*?)\s*\|$') {
            $covers = @([regex]::Matches($Matches[3], '[A-Z]{2}-CAP-\d{2,}') | ForEach-Object { $_.Value } | Sort-Object -Unique)
            $rows.Add([pscustomobject]@{
                Plan = $File.FullName
                Feature = $feature
                Phase = $phase
                Task = [int]$Matches[1]
                Description = ($Matches[2] -replace '<br\s*/?>', ' ').Trim()
                Covers = $covers
                Role = $Matches[4].Trim()
                Status = $Matches[5].Trim()
                Notes = $Matches[6].Trim()
            })
        }
    }

    [pscustomobject]@{
        Path = $File.FullName
        Name = $File.Name
        Feature = $feature
        Status = if ($fm.status) { [string]$fm.status } else { '' }
        Rows = @($rows.ToArray())
        Frontmatter = $fm
    }
}

function Get-PmCompletionState {
    param([string]$Content)

    $matches = [regex]::Matches($Content, '(?m)^## Completion\s*$')
    if ($matches.Count -eq 0) {
        return [pscustomobject]@{ State = 'none'; Status = ''; Block = '' }
    }
    $last = $matches[$matches.Count - 1]
    $block = $Content.Substring($last.Index)
    if ($block -match '(?im)^Status:\s*(success|failure|blocked)\s*$') {
        return [pscustomobject]@{ State = 'valid'; Status = $Matches[1].ToLowerInvariant(); Block = $block }
    }
    return [pscustomobject]@{ State = 'malformed'; Status = ''; Block = $block }
}

function Get-PmActiveTask {
    param([System.IO.FileInfo]$File, [int]$StaleHours = 24)

    $content = Get-Content -LiteralPath $File.FullName -Raw
    $fm = ConvertFrom-PmFrontmatter $content
    $completion = Get-PmCompletionState $content
    $created = [datetime]::MinValue
    $hasCreated = $false
    if ($fm.created) { $hasCreated = [datetime]::TryParse([string]$fm.created, [ref]$created) }
    $ageBase = if ($hasCreated) { $created } else { $File.LastWriteTime }
    $ageHours = ((Get-Date) - $ageBase).TotalHours
    $state = $completion.State
    if ($state -eq 'none' -and $ageHours -ge $StaleHours) { $state = 'stale' }
    [pscustomobject]@{
        Path = $File.FullName
        Name = $File.Name
        Feature = if ($fm.feature) { [string]$fm.feature } else { '' }
        Phase = if ($fm.phase) { [string]$fm.phase } else { '' }
        Task = if ($fm.task) { [string]$fm.task } else { '' }
        ClaimedBy = if ($fm.claimed_by) { [string]$fm.claimed_by } else { '' }
        LeaseExpiresAt = if ($fm.lease_expires_at) { [string]$fm.lease_expires_at } else { '' }
        CompletionState = $state
        CompletionStatus = $completion.Status
        AgeHours = [math]::Round($ageHours, 1)
        Frontmatter = $fm
    }
}

function Test-PmDependencyCycles {
    param([object[]]$Specs)

    $bySlug = @{}
    foreach ($spec in $Specs) { $bySlug[$spec.Slug] = $spec }
    $visiting = @{}
    $visited = @{}
    $cycles = New-Object System.Collections.Generic.List[string]

    function Visit([string]$slug, [string[]]$stack) {
        if ($visited[$slug]) { return }
        if ($visiting[$slug]) {
            $cycle = @($stack + $slug) -join ' -> '
            $cycles.Add($cycle)
            return
        }
        if (-not $bySlug.ContainsKey($slug)) { return }
        $visiting[$slug] = $true
        foreach ($dep in @($bySlug[$slug].DependsOn)) { Visit $dep @($stack + $slug) }
        $visiting.Remove($slug)
        $visited[$slug] = $true
    }

    foreach ($spec in $Specs) { Visit $spec.Slug @() }
    return @($cycles | Sort-Object -Unique)
}

function Get-PmState {
    param([string]$Root = (Get-PmRoot), [int]$StaleHours = 24)

    $features = Join-Path $Root 'docs/features'
    $plans = Join-Path $Root 'docs/plans'
    $active = Join-Path $Root 'docs/tasks/active'
    $issues = Join-Path $Root 'docs/issues'

    $specs = @(Get-PmMarkdownFiles $features | ForEach-Object { Get-PmSpec $_ })
    $planObjs = @(Get-PmMarkdownFiles $plans | ForEach-Object { Get-PmPlanRows $_ })
    $activeTasks = @()
    if (Test-Path -LiteralPath $active -PathType Container) {
        $activeTasks = @(Get-ChildItem -LiteralPath $active -Filter '*.md' -File | Sort-Object Name | ForEach-Object { Get-PmActiveTask $_ $StaleHours })
    }
    $issueFiles = @()
    if (Test-Path -LiteralPath $issues -PathType Container) {
        $issueFiles = @(Get-ChildItem -LiteralPath $issues -Filter '*.md' -File | Sort-Object Name)
    }
    [pscustomobject]@{
        Root = $Root
        Specs = $specs
        Plans = $planObjs
        ActiveTasks = $activeTasks
        Issues = $issueFiles
        Cycles = @(Test-PmDependencyCycles $specs)
    }
}

function Write-PmTable {
    param([object[]]$Rows, [string[]]$Columns)

    if (-not $Rows -or $Rows.Count -eq 0) {
        '_none_'
        return
    }
    '| ' + ($Columns -join ' | ') + ' |'
    '| ' + (($Columns | ForEach-Object { '---' }) -join ' | ') + ' |'
    foreach ($row in $Rows) {
        $values = foreach ($col in $Columns) {
            $value = $row.$col
            if ($null -eq $value -or $value -eq '') { '' }
            elseif ($value -is [array]) { ($value -join ', ') }
            else { ([string]$value).Replace('|', '\|') }
        }
        '| ' + ($values -join ' | ') + ' |'
    }
}
