<#
.SYNOPSIS
    Generates CHANGELOG.md from conventional-commit messages and release tags.

.DESCRIPTION
    Walks every release tag (`v*`) in semver order plus the commits since the
    latest tag (emitted as `[Unreleased]`). For each range, non-merge commits
    are grouped by their conventional-commit prefix and mapped to
    Keep-a-Changelog sections:

      feat              -> Added
      fix               -> Fixed
      refactor, perf    -> Changed
      docs              -> Documentation
      ci, build, chore  -> Internal
      test              -> Tests
      style             -> Style
      release           -> (skipped — the tag itself represents the release)

    Output is written to CHANGELOG.md at the repo root. The rebuild is
    deterministic: the file is derived entirely from git, so it is a cache of
    history, never a source of truth. If the repo has no `v*` tags yet, the
    entire history is emitted under `[Unreleased]`.

.EXAMPLE
    pwsh scripts/Generate-Changelog.ps1

.NOTES
    Intended to be re-runnable. When a new release tag is cut, re-run this
    script and commit the refreshed CHANGELOG.md — the `[Unreleased]` section
    will move into a proper version section automatically.
#>

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $repoRoot 'CHANGELOG.md'

# -- Map conventional-commit prefix -> Keep-a-Changelog section name ----------
$sectionMap = [ordered]@{
    'feat'     = 'Added'
    'fix'      = 'Fixed'
    'refactor' = 'Changed'
    'perf'     = 'Changed'
    'docs'     = 'Documentation'
    'ci'       = 'Internal'
    'build'    = 'Internal'
    'chore'    = 'Internal'
    'test'     = 'Tests'
    'style'    = 'Style'
}

# Order in which sections appear within a release
$sectionOrder = @('Added', 'Changed', 'Fixed', 'Documentation', 'Tests', 'Internal', 'Style', 'Other')

function Parse-CommitSubject {
    param([string]$Subject)

    if ($Subject -match '^(?<type>[a-z]+)(?:\([^)]+\))?(?<bang>!?):\s*(?<desc>.+)$') {
        return [pscustomobject]@{
            Type     = $Matches.type.ToLower()
            Breaking = [bool]$Matches.bang
            Desc     = $Matches.desc.Trim()
        }
    }
    return [pscustomobject]@{
        Type     = 'other'
        Breaking = $false
        Desc     = $Subject.Trim()
    }
}

function Get-CommitsInRange {
    param([string]$Range)

    $raw = git log $Range --no-merges --format='%H%x1f%s' 2>$null
    if (-not $raw) { return @() }

    $raw | ForEach-Object {
        $parts = $_ -split [char]0x1f, 2
        if ($parts.Count -ne 2) { return }
        $parsed = Parse-CommitSubject $parts[1]
        if ($parsed.Type -eq 'release') { return }  # skip the tag-bump commits themselves
        [pscustomobject]@{
            Sha      = $parts[0].Substring(0, 7)
            Type     = $parsed.Type
            Breaking = $parsed.Breaking
            Desc     = $parsed.Desc
        }
    }
}

function Format-Section {
    param(
        [string]$Heading,
        [string]$DateIso,
        [object[]]$Commits
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    if ($DateIso) {
        $lines.Add("## [$Heading] - $DateIso")
    }
    else {
        $lines.Add("## [$Heading]")
    }
    $lines.Add('')

    if (-not $Commits -or $Commits.Count -eq 0) {
        $lines.Add('_No user-facing changes recorded._')
        $lines.Add('')
        return $lines -join "`n"
    }

    # --- Breaking changes callout at top ---
    $breaking = $Commits | Where-Object Breaking
    if ($breaking) {
        $lines.Add('### ⚠ BREAKING CHANGES')
        $lines.Add('')
        foreach ($c in $breaking) {
            # Use -f formatter with a single-quoted template so the literal backticks
            # around $Sha aren't mangled by PowerShell double-quoted-string escapes.
            $lines.Add(('- {0} (`{1}`)' -f $c.Desc, $c.Sha))
        }
        $lines.Add('')
    }

    # --- Group remaining commits by section name ---
    $bySection = @{}
    foreach ($c in $Commits) {
        $section = if ($sectionMap.Contains($c.Type)) { $sectionMap[$c.Type] } else { 'Other' }
        if (-not $bySection.ContainsKey($section)) { $bySection[$section] = [System.Collections.Generic.List[object]]::new() }
        $bySection[$section].Add($c)
    }

    foreach ($section in $sectionOrder) {
        if (-not $bySection.ContainsKey($section)) { continue }
        $lines.Add("### $section")
        $lines.Add('')
        foreach ($c in $bySection[$section]) {
            $prefix = if ($c.Breaking) { '**BREAKING:** ' } else { '' }
            $lines.Add(('- {0}{1} (`{2}`)' -f $prefix, $c.Desc, $c.Sha))
        }
        $lines.Add('')
    }

    return $lines -join "`n"
}

# -- Collect tags, oldest first -----------------------------------------------
$tags = @(git tag -l 'v*' --sort=v:refname 2>$null)

# -- Build the output ---------------------------------------------------------
$header = @'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

This file is generated from `git log` via `scripts/Generate-Changelog.ps1`.
Re-run after cutting a release tag to move the `[Unreleased]` section into its
proper version header.


'@

$sections = [System.Collections.Generic.List[string]]::new()

# Unreleased: latest tag -> HEAD (entire history if the repo has no tags yet)
$latestTag = if ($tags.Count -gt 0) { $tags | Select-Object -Last 1 } else { $null }
$unreleasedRange = if ($latestTag) { "$latestTag..HEAD" } else { 'HEAD' }
$unreleased = Get-CommitsInRange $unreleasedRange
$sections.Add((Format-Section -Heading 'Unreleased' -DateIso '' -Commits $unreleased))

# Walk tags newest-first so the changelog reads top-down like a blog feed
$reversed = $tags | Sort-Object -Property @{Expression = { [version]($_.TrimStart('v')) }} -Descending

for ($i = 0; $i -lt $reversed.Count; $i++) {
    $current = $reversed[$i]
    $previous = if ($i + 1 -lt $reversed.Count) { $reversed[$i + 1] } else { $null }

    $range = if ($previous) { "$previous..$current" } else { $current }
    $commits = Get-CommitsInRange $range

    $date = (git log -1 --format='%ad' --date=short $current).Trim()
    $sections.Add((Format-Section -Heading $current.TrimStart('v') -DateIso $date -Commits $commits))
}

$body = $header + ($sections -join "`n")
$body | Set-Content -Path $outputPath -Encoding UTF8

Write-Host "CHANGELOG.md written: $outputPath"
Write-Host "Tags documented: $($tags.Count)"
Write-Host "Unreleased commits: $($unreleased.Count)"
