#Requires -Version 7.0

<#
.SYNOPSIS
    Changelog-staleness gate: every release tag (v*) must have a matching
    ## [<version>] section in CHANGELOG.md.

.DESCRIPTION
    The third artifact of the Release-Automation Standard, deployed by the
    github:release-init operation alongside the changelog generator and the
    tag-triggered workflow. Registered in the repo's pre-push hook so a release
    tag can never be pushed while its CHANGELOG.md section is missing - the
    "silently fell a release behind" failure mode this gate exists to prevent.

    Read-only. It asserts only that each RELEASED section is present; the volatile
    [Unreleased] section is ignored (it is expected to churn, and the very commit
    that refreshes it invalidates any byte-equality check). An untagged repo passes
    - its whole history lives under [Unreleased] by design.

    Self-contained and portable: no dependency on the archive. Resolve a git
    top-level from the current directory when -RepoRoot is omitted so it runs
    identically from a pre-push hook, a CI step, or the command line.

.PARAMETER RepoRoot
    Repository to check. Defaults to the git top-level of the current directory.

.PARAMETER Json
    Emit a machine-readable JSON result instead of a console line.

.NOTES
    Exit codes:
      0 = all released tags documented (or the repo has no tags)
      1 = STALE CHANGELOG - one or more tags have no ## [<version>] section
      2 = execution failure (not a git repo, unreadable CHANGELOG, etc.)
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$exitCode  = 0
$missing   = @()
$message   = ''
$execError = $null

try {
    if (-not $RepoRoot) {
        $RepoRoot = (git rev-parse --show-toplevel 2>$null)
        if (-not $RepoRoot) { throw 'not a git repository (and no -RepoRoot given).' }
    }
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $changelogPath = Join-Path $RepoRoot 'CHANGELOG.md'

    $tags = @(git -C $RepoRoot tag -l 'v*' --sort=v:refname 2>$null | Where-Object { $_.Trim() -ne '' })

    if ($tags.Count -eq 0) {
        # Untagged repo: the whole history lives under [Unreleased] by design.
        $message = 'No release tags - nothing to assert.'
    }
    elseif (-not (Test-Path -LiteralPath $changelogPath)) {
        $missing = $tags
        $exitCode = 1
        $message = 'CHANGELOG.md is missing - run the changelog generator.'
    }
    else {
        $text = [System.IO.File]::ReadAllText($changelogPath)
        # Ordinal, culture-invariant containment - section headers are literal.
        $missing = @($tags | Where-Object {
            -not $text.Contains(("## [{0}]" -f $_.TrimStart('v')), [StringComparison]::Ordinal)
        })
        if ($missing.Count -gt 0) {
            $exitCode = 1
            $message = "STALE CHANGELOG - no section for: $($missing -join ', ') - run the changelog generator."
        }
        else {
            $message = "All $($tags.Count) release tag(s) documented."
        }
    }
}
catch {
    $exitCode = 2
    $execError = "$_"
    $message = "check failed: $execError"
}

if ($Json) {
    [pscustomobject]@{
        exitCode       = $exitCode
        stale          = ($exitCode -eq 1)
        missing        = @($missing)
        message        = $message
        executionError = $execError
    } | ConvertTo-Json -Depth 4
}
else {
    if ($exitCode -eq 0) {
        Write-Output "changelog-staleness: PASS - $message"
    }
    elseif ($exitCode -eq 1) {
        [Console]::Error.WriteLine("changelog-staleness: FAIL - $message")
    }
    else {
        [Console]::Error.WriteLine("changelog-staleness: ERROR - $message")
    }
}

exit $exitCode
