#Requires -Version 5.1
# pm-test-runners.ps1
# Report the project's confirmed test runners, or — if no confirmed list exists —
# walk the repo and propose candidates so the orchestrator can ask the user.
#
# Output is markdown so /continue-tasks (and humans) can read it directly.
# Confirmed source of truth: docs/workflow/runners.md.

param(
    [string]$Root = '.',
    [int]$MaxDepth = 4,
    [switch]$DiscoverOnly,   # ignore docs/workflow/runners.md and always re-walk
    [switch]$Json
)

. "$PSScriptRoot/ProjectManager.Common.ps1"

$rootPath = Get-PmRoot $Root
$confirmedPath = Join-Path $rootPath 'docs/workflow/runners.md'

# --- Discovery ---------------------------------------------------------------

$IgnoreDirs = @(
    '.git', 'node_modules', 'vendor', 'target', 'dist', 'build', 'out',
    '__pycache__', '.venv', 'venv', '.next', '.nuxt', '.turbo', '.cache',
    '.idea', '.vscode', '.pytest_cache', '.tox', '.mypy_cache', '.ruff_cache',
    'coverage', '.coverage', '.gradle', '.mvn', 'bin', 'obj',
    '.claude'
)

function Test-HasPytest([string]$Dir) {
    if (Test-Path -LiteralPath (Join-Path $Dir 'pytest.ini')) { return $true }
    if (Test-Path -LiteralPath (Join-Path $Dir 'tox.ini')) { return $true }
    $pp = Join-Path $Dir 'pyproject.toml'
    if (Test-Path -LiteralPath $pp) {
        $c = Get-Content -LiteralPath $pp -Raw
        if ($c -match '(?m)^\[tool\.pytest' -or $c -match '(?m)pytest' -or (Test-Path -LiteralPath (Join-Path $Dir 'tests'))) { return $true }
    }
    return $false
}

function Test-HasNodeTest([string]$Dir) {
    $pj = Join-Path $Dir 'package.json'
    if (-not (Test-Path -LiteralPath $pj)) { return $false }
    try {
        $j = Get-Content -LiteralPath $pj -Raw | ConvertFrom-Json
        if ($j.scripts -and $j.scripts.test) { return $true }
    } catch { return $false }
    return $false
}

function Test-HasMakefileTest([string]$Dir) {
    $mk = Join-Path $Dir 'Makefile'
    if (-not (Test-Path -LiteralPath $mk)) { return $false }
    return ((Get-Content -LiteralPath $mk -Raw) -match '(?m)^test\s*:')
}

function Get-RelativeSubtree([string]$Dir) {
    $full = (Resolve-Path -LiteralPath $Dir).Path
    if ($full -eq $rootPath) { return '.' }
    $prefix = $rootPath
    if (-not $prefix.EndsWith([IO.Path]::DirectorySeparatorChar)) { $prefix += [IO.Path]::DirectorySeparatorChar }
    if ($full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ($full.Substring($prefix.Length) -replace '\\', '/')
    }
    return ($full -replace '\\', '/')
}

function Get-RunnerCandidates([string]$Dir) {
    $hits = New-Object System.Collections.Generic.List[object]
    $rel = Get-RelativeSubtree $Dir

    if (Test-HasPytest $Dir) {
        $cmd = if ($rel -eq '.') { 'pytest' } else { "cd $rel; pytest" }
        $hits.Add([pscustomobject]@{ Subtree = $rel; Runner = 'pytest'; Command = $cmd; Evidence = 'pyproject.toml/pytest.ini/tests/' })
    }
    if (Test-HasNodeTest $Dir) {
        $cmd = if ($rel -eq '.') { 'npm test' } else { "cd $rel; npm test" }
        $hits.Add([pscustomobject]@{ Subtree = $rel; Runner = 'npm'; Command = $cmd; Evidence = 'package.json scripts.test' })
    }
    if (Test-Path -LiteralPath (Join-Path $Dir 'Cargo.toml')) {
        $cmd = if ($rel -eq '.') { 'cargo test' } else { "cd $rel; cargo test" }
        $hits.Add([pscustomobject]@{ Subtree = $rel; Runner = 'cargo'; Command = $cmd; Evidence = 'Cargo.toml' })
    }
    if (Test-Path -LiteralPath (Join-Path $Dir 'go.mod')) {
        $cmd = if ($rel -eq '.') { 'go test ./...' } else { "cd $rel; go test ./..." }
        $hits.Add([pscustomobject]@{ Subtree = $rel; Runner = 'go'; Command = $cmd; Evidence = 'go.mod' })
    }
    if (Test-HasMakefileTest $Dir) {
        $cmd = if ($rel -eq '.') { 'make test' } else { "cd $rel; make test" }
        $hits.Add([pscustomobject]@{ Subtree = $rel; Runner = 'make'; Command = $cmd; Evidence = 'Makefile test target' })
    }
    return $hits
}

function Walk-Repo([string]$Dir, [int]$Depth) {
    $found = New-Object System.Collections.Generic.List[object]
    foreach ($c in Get-RunnerCandidates $Dir) { $found.Add($c) }
    if ($Depth -le 0) { return $found }
    Get-ChildItem -LiteralPath $Dir -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $IgnoreDirs -and -not $_.Name.StartsWith('.') } |
        ForEach-Object {
            foreach ($c in (Walk-Repo $_.FullName ($Depth - 1))) { $found.Add($c) }
        }
    return $found
}

# --- Confirmed list reader ---------------------------------------------------

function Read-ConfirmedRunners([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    $content = Get-Content -LiteralPath $Path -Raw
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($line in ($content -split "\r?\n")) {
        # Skip header and separator rows. Match real data rows only.
        if ($line -match '^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*(yes|no)\s*\|$') {
            $sub = $Matches[1].Trim()
            if ($sub -eq 'Subtree' -or $sub -match '^[-: ]+$') { continue }
            $rows.Add([pscustomobject]@{
                Subtree = $sub
                Runner = $Matches[2].Trim()
                Command = $Matches[3].Trim().Trim('`')
                Confirmed = ($Matches[4].Trim().ToLower() -eq 'yes')
            })
        }
    }
    return $rows
}

# --- Main --------------------------------------------------------------------

$confirmed = if ($DiscoverOnly) { @() } else { Read-ConfirmedRunners $confirmedPath }
$source = if ($confirmed.Count -gt 0) { 'confirmed' } else { 'discovery' }

$result = @{
    Root = $rootPath
    Source = $source
    ConfirmedPath = $confirmedPath
    Runners = if ($source -eq 'confirmed') {
        @($confirmed | Where-Object { $_.Confirmed })
    } else {
        @(Walk-Repo $rootPath $MaxDepth | Sort-Object Subtree, Runner -Unique)
    }
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
    return
}

"# Project Manager Test Runners"
""
"Root: $($result.Root)"
"Source: $($result.Source)  (confirmed list: $confirmedPath)"
""
if ($result.Runners.Count -eq 0) {
    "_No test runners detected. Either none exist yet, or extend the discovery list in pm-test-runners.ps1._"
    return
}

$rows = @($result.Runners | ForEach-Object {
    [pscustomobject]@{
        Subtree = $_.Subtree
        Runner = $_.Runner
        Command = '`' + $_.Command + '`'
        Source = if ($source -eq 'confirmed') { 'confirmed' } else { $_.Evidence }
    }
})
Write-PmTable $rows @('Subtree', 'Runner', 'Command', 'Source')
""
if ($source -eq 'discovery') {
    "_Run /init-project or /reinit Runner Discovery to confirm this list and persist it to docs/workflow/runners.md._"
}
