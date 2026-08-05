<#
.SYNOPSIS
    Inspect and edit the per-repo Windows Terminal tab-color registry (~/.claude/repo-colors.json).

.DESCRIPTION
    A companion to resolve-repo-color.ps1 (which it dot-sources for the palette, key normalization,
    and registry I/O). Actions:

        list                Print every repo → color assignment.
        set    -Repo <x> -Color <#hex>   Pin a color. <x> is a repo directory, a remote URL, or an
                            already-normalized key; it is normalized the same way the launcher does.
        remove -Repo <x>    Delete an assignment.
        reset-top [-Count N]  Clear the whole registry, then assign the palette (in order) to the N
                            most active repos, ranked by total transcript volume in ~/.claude/projects.
                            Worktrees of a repo are aggregated, since they share one remote.

    All mutating actions take the same 'Global\claude-repo-colors' mutex the launcher uses, so they
    are safe to run while sessions are launching.

.EXAMPLE
    pwsh -File manage-repo-colors.ps1 -Action list

.EXAMPLE
    pwsh -File manage-repo-colors.ps1 -Action set -Repo C:\development\AC_DESIGN -Color '#43F68A'

.EXAMPLE
    pwsh -File manage-repo-colors.ps1 -Action reset-top -Count 5
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('list', 'set', 'remove', 'reset-top')][string]$Action,
    [string]$Repo,
    [string]$Color,
    [int]$Count = 5,
    [string]$ProjectsRoot = (Join-Path $HOME '.claude/projects')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'resolve-repo-color.ps1')   # palette, Get-RepoKey, ConvertTo-TabHex, map I/O

function Resolve-KeyArg {
    # Accept a directory, a remote URL, or an already-normalized key; return the canonical key.
    param([string]$Value)
    if (-not $Value) { throw 'This action requires -Repo.' }
    if ($Value -match '^(remote|path):') { return $Value }
    if (Test-Path -LiteralPath $Value) { return Get-RepoKey $Value }
    # Treat as a remote URL: reuse the launcher's normalization by faking the remote branch.
    $k = $Value.Trim().ToLower()
    $k = $k -replace '^[a-z][a-z0-9+.-]*://', '' -replace '^[^/@]+@', '' -replace ':', '/' -replace '\.git$', ''
    return 'remote:' + $k.TrimEnd('/')
}

function Get-CwdFromProjectDir {
    # The launcher's transcript store encodes cwd inside each session's jsonl. Stream the newest one
    # and return the first cwd found — no full parse, so a 100 MB transcript costs one line read.
    param([string]$Dir)
    $newest = Get-ChildItem -LiteralPath $Dir -Filter *.jsonl -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $newest) { return $null }
    $reader = [System.IO.StreamReader]::new($newest.FullName)
    try {
        while (-not $reader.EndOfStream) {
            $m = [regex]::Match($reader.ReadLine(), '"cwd"\s*:\s*"([^"]+)"')
            if ($m.Success) { return ($m.Groups[1].Value -replace '\\\\', '\') }
        }
    }
    finally { $reader.Dispose() }
    return $null
}

function Get-TopRepos {
    # Rank repos by aggregate transcript bytes. Score every project dir cheaply (filesystem only),
    # then resolve only the strongest candidates to a repo key — bounding the git/jsonl work.
    param([int]$Count)
    if (-not (Test-Path -LiteralPath $ProjectsRoot)) { throw "Projects root not found: $ProjectsRoot" }

    $scored = foreach ($d in (Get-ChildItem -LiteralPath $ProjectsRoot -Directory)) {
        $bytes = (Get-ChildItem -LiteralPath $d.FullName -Filter *.jsonl -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        if ($bytes) { [pscustomobject]@{ Dir = $d.FullName; Bytes = [long]$bytes } }
    }
    $candidates = $scored | Sort-Object Bytes -Descending | Select-Object -First ([Math]::Max($Count * 3, 15))

    $byRepo = @{}
    foreach ($c in $candidates) {
        $cwd = Get-CwdFromProjectDir $c.Dir
        if (-not $cwd -or -not (Test-Path -LiteralPath $cwd)) { continue }
        & git -C $cwd rev-parse --is-inside-work-tree *> $null 2>&1
        if ($LASTEXITCODE -ne 0) { continue }          # skip non-repos (container dirs)
        $key = Get-RepoKey $cwd
        if (-not $byRepo.ContainsKey($key)) {
            $byRepo[$key] = [pscustomobject]@{ Key = $key; Cwd = $cwd; Bytes = [long]0 }
        }
        $byRepo[$key].Bytes += $c.Bytes
    }
    $byRepo.Values | Sort-Object Bytes -Descending | Select-Object -First $Count
}

function Format-Registry {
    param([hashtable]$Map)
    if ($Map.Count -eq 0) { Write-Host '(registry is empty)'; return }
    $Map.GetEnumerator() | Sort-Object Value | ForEach-Object {
        [pscustomobject]@{ Color = $_.Value; Repo = $_.Key }
    } | Format-Table -AutoSize | Out-String | Write-Host
}

$mutex = [System.Threading.Mutex]::new($false, 'Global\claude-repo-colors')
[void]$mutex.WaitOne()
try {
    switch ($Action) {
        'list' {
            Format-Registry (Get-ColorMap)
        }
        'set' {
            $hex = ConvertTo-TabHex $Color
            if (-not $hex) { throw "Invalid -Color '$Color' (expected #RGB or #RRGGBB)." }
            $key = Resolve-KeyArg $Repo
            $map = Get-ColorMap
            $map[$key] = $hex
            Save-ColorMap $map
            Write-Host "set  $key  ->  $hex"
        }
        'remove' {
            $key = Resolve-KeyArg $Repo
            $map = Get-ColorMap
            if ($map.ContainsKey($key)) { $map.Remove($key); Save-ColorMap $map; Write-Host "removed  $key" }
            else { Write-Host "no entry for  $key" }
        }
        'reset-top' {
            $top = @(Get-TopRepos -Count $Count)
            if ($top.Count -eq 0) { throw 'No active repos found to seed.' }
            $map = @{}
            for ($i = 0; $i -lt $top.Count; $i++) {
                $map[$top[$i].Key] = $script:AcPalette[$i % $script:AcPalette.Count]
            }
            Save-ColorMap $map
            Write-Host "Cleared registry and seeded the top $($top.Count) active repos:`n"
            for ($i = 0; $i -lt $top.Count; $i++) {
                $mb = [Math]::Round($top[$i].Bytes / 1MB, 1)
                '{0}  {1,-9}  {2,7} MB  {3}' -f $script:AcPalette[$i], $top[$i].Key.Split('/')[-1], $mb, $top[$i].Cwd | Write-Host
            }
        }
    }
}
finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
