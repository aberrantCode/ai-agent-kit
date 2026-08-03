<#
.SYNOPSIS
    Resolve a stable Windows Terminal tab color for a repository.

.DESCRIPTION
    Every repository gets one color, and every session launched for that repository reuses it, so
    concurrent tabs for the same repo are visually grouped. The mapping is persisted in a global
    registry at ~/.claude/repo-colors.json:

        1. The repo is identified by its normalized `origin` remote URL — NOT its path — so every
           worktree of a repo (this project keeps them under .worktrees/) resolves to the same key
           and therefore the same color. Repos with no remote fall back to the normalized toplevel
           path.
        2. On a registry hit, the stored color is returned unchanged.
        3. On a miss, the color is seeded ONCE: from a `tabColor:` key in the repo's pm-profile.yml
           if present, otherwise the next unused color from the AC brand palette. After that first
           write the registry is authoritative — editing pm-profile.yml later does not move a repo
           that already has an entry (seed-once, map-wins).

    Reads and writes are guarded by a named system mutex so two sessions launching at the same
    moment cannot both grab "next free" and clobber each other's write.

    Windows Terminal exposes no way to read back a tab's applied color, which is exactly why this
    registry exists: it is the queryable record that `wt` itself will not give us.

    This file is designed to be dot-sourced (it only defines `Resolve-RepoColor` in that case) or
    run directly, in which case it prints the resolved hex color to stdout and nothing else.

.PARAMETER WorkingDirectory
    A directory inside the repository whose color is being resolved. Defaults to the current path.

.EXAMPLE
    pwsh -File resolve-repo-color.ps1 -WorkingDirectory C:\repo\.worktrees\my-task
    #43F68A
#>
[CmdletBinding()]
param(
    [string]$WorkingDirectory = (Get-Location).Path
)

# Curated from the AC / phosphor identity (AC_DESIGN tokens + the "AC Phosphor" WT scheme).
# Ordered so the first entries are maximally distinct — a workstation with a handful of repos
# gets green / sky / amber / coral before any near-hues appear. All are mid-bright enough to read
# as a tab-strip fill without glare.
$script:AcPalette = @(
    '#43F68A',  # phosphor green (signature)
    '#7DD3FC',  # sky blue
    '#FFD866',  # amber
    '#FF6B6B',  # coral
    '#C792EA',  # lavender
    '#67E8D3',  # teal
    '#0B8A45',  # deep green
    '#7B3FBF',  # violet
    '#EFBD24',  # gold
    '#79E0A8',  # mint
    '#C62828',  # crimson
    '#B2C2B6'   # sage
)

$script:MapPath = Join-Path $HOME '.claude/repo-colors.json'

function ConvertTo-TabHex {
    # Normalize a user-supplied color to `#RRGGBB` (or `#RGB`), or return $null if it isn't one.
    param([string]$Value)
    if (-not $Value) { return $null }
    $v = $Value.Trim().TrimStart('#')
    if ($v -notmatch '^[0-9A-Fa-f]{3}$' -and $v -notmatch '^[0-9A-Fa-f]{6}$') { return $null }
    return '#' + $v.ToUpper()
}

function Get-RepoKey {
    # Stable identity for the repo. Remote URL wins so all worktrees collapse to one key.
    param([string]$Directory)
    $url = & git -C $Directory remote get-url origin 2>$null
    if ($LASTEXITCODE -eq 0 -and $url) {
        $k = $url.Trim().ToLower()
        $k = $k -replace '^[a-z][a-z0-9+.-]*://', ''   # strip scheme (https://, ssh://, git://)
        $k = $k -replace '^[^/@]+@', ''                # strip user@ (git@, ssh user)
        $k = $k -replace ':', '/'                       # host:owner/repo -> host/owner/repo
        $k = $k -replace '\.git$', ''                   # drop trailing .git
        $k = $k.TrimEnd('/')
        return "remote:$k"
    }
    # No remote — fall back to the git toplevel, or the raw directory if it isn't a repo.
    $top = & git -C $Directory rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $top) { $top = (Resolve-Path -LiteralPath $Directory).Path }
    return 'path:' + (($top.Trim().ToLower()) -replace '\\', '/').TrimEnd('/')
}

function Get-ProfileColor {
    # A `tabColor:` key in the repo's pm-profile.yml, checked at the worktree root AND the main
    # worktree root (a linked worktree may not carry its own copy). No YAML dependency — a single
    # scalar line is all we need, so a scoped regex is more robust than pulling in a parser.
    param([string]$Directory)
    $candidates = [System.Collections.Generic.List[string]]::new()
    $top = & git -C $Directory rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $top) { $candidates.Add($top.Trim()) }
    $mainLine = (& git -C $Directory worktree list 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -eq 0 -and $mainLine) { $candidates.Add((($mainLine -split '\s{2,}|\s')[0]).Trim()) }
    $candidates.Add((Resolve-Path -LiteralPath $Directory).Path)

    foreach ($c in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        $profile = Join-Path $c 'pm-profile.yml'
        if (Test-Path -LiteralPath $profile) {
            $m = Select-String -LiteralPath $profile -Pattern '^\s*tabColor\s*:\s*["'']?(#?[0-9A-Fa-f]{3,6})' |
                Select-Object -First 1
            if ($m) {
                $hex = ConvertTo-TabHex $m.Matches[0].Groups[1].Value
                if ($hex) { return $hex }
            }
        }
    }
    return $null
}

# Registry I/O is factored out so the management command shares one implementation. Neither of
# these locks — callers that read-modify-write hold the 'Global\claude-repo-colors' mutex around
# the pair (see Resolve-RepoColor and manage-repo-colors.ps1).
function Get-ColorMap {
    $map = @{}
    if (Test-Path -LiteralPath $script:MapPath) {
        $raw = Get-Content -Raw -LiteralPath $script:MapPath -ErrorAction SilentlyContinue
        if ($raw -and $raw.Trim()) {
            try {
                ($raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $map[$_.Name] = $_.Value }
            }
            catch {
                Write-Warning "repo-colors.json is corrupt; starting a fresh registry. ($($_.Exception.Message))"
            }
        }
    }
    return $map
}

function Save-ColorMap {
    param([hashtable]$Map)
    $dir = Split-Path -Parent $script:MapPath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $ordered = [ordered]@{}
    foreach ($k in ($Map.Keys | Sort-Object)) { $ordered[$k] = $Map[$k] }
    ($ordered | ConvertTo-Json -Depth 3) | Set-Content -LiteralPath $script:MapPath -Encoding UTF8
}

function Resolve-RepoColor {
    <#
    .SYNOPSIS
        Return the persisted tab color for the repo containing $WorkingDirectory, assigning and
        persisting one on first sight.
    #>
    [CmdletBinding()]
    param([string]$WorkingDirectory = (Get-Location).Path)

    $key = Get-RepoKey $WorkingDirectory

    # Cross-process guard: parallel launches must serialize their read-modify-write of the registry.
    $mutex = [System.Threading.Mutex]::new($false, 'Global\claude-repo-colors')
    [void]$mutex.WaitOne()
    try {
        $map = Get-ColorMap

        if ($map.ContainsKey($key)) { return $map[$key] }

        # First sight of this repo — seed the color exactly once.
        $color = Get-ProfileColor $WorkingDirectory
        if (-not $color) {
            $used = @($map.Values)
            $color = $script:AcPalette | Where-Object { $_ -notin $used } | Select-Object -First 1
            if (-not $color) { $color = $script:AcPalette[$map.Count % $script:AcPalette.Count] }  # palette exhausted: wrap
        }
        $map[$key] = $color
        Save-ColorMap $map
        return $color
    }
    finally {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
}

# Direct invocation prints the resolved color and nothing else, so a caller can capture stdout.
# Dot-sourcing ($MyInvocation.InvocationName -eq '.') skips this and only defines the function.
if ($MyInvocation.InvocationName -ne '.') {
    Write-Output (Resolve-RepoColor -WorkingDirectory $WorkingDirectory)
}
