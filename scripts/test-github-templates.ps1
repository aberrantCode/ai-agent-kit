#Requires -Version 7.0

<#
.SYNOPSIS
    Deploy-and-run smoke test for the github bundle's shipped templates.

.DESCRIPTION
    The github:repo-init and github:release-init operations deploy templates into
    OTHER repositories - git hooks, a changelog generator, a staleness gate. A whole
    class of bug in those templates is invisible in this archive because nothing here
    executes them: a CRLF shebang that breaks `sh`, mojibake emitted only under
    `pwsh -NoProfile`, a hook that hard-fails when its tool is absent. Only deploying
    the templates into a throwaway repo and running them catches these.

    This test does exactly that: it creates a temporary git repo (plus a bare remote),
    installs the hook templates via core.hooksPath, drops the release templates into
    scripts/, then exercises them the way a real repo would - a real `git commit`
    (fires pre-commit + commit-msg) and `git push` (fires pre-push), the changelog
    generator under `-NoProfile`, and the staleness gate. It asserts every step exits
    0, the hooks degrade rather than hard-fail with no tools installed, and the
    generated changelog is non-empty and free of non-ASCII (mojibake) bytes.

    It writes only under a bounded temp directory, removes it on exit (unless
    -KeepTemp), and never touches the archive working tree. It is opt-in from the
    pre-PR gate (validate.ps1 -IncludeSmoke) because it needs git + pwsh and runs
    real subprocesses.

.PARAMETER KeepTemp
    Leave the temporary repo on disk (prints its path) for debugging a failure.

.PARAMETER Json
    Emit a JSON result document instead of a console table.

.NOTES
    Exit codes:
      0 = every assertion passed
      1 = one or more assertions failed
      2 = execution failure (missing prerequisite tool/template, unexpected error)
#>

[CmdletBinding()]
param(
    [switch]$KeepTemp,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$archiveRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$hooksSrc = Join-Path $archiveRoot 'claude/skills/github/sub-skills/repo-init/templates/hooks'
$genSrc   = Join-Path $archiveRoot 'claude/skills/github/sub-skills/release-init/templates/Generate-Changelog.ps1'
$staleSrc = Join-Path $archiveRoot 'claude/skills/github/sub-skills/release-init/templates/check-changelog-staleness.ps1'

$results = [System.Collections.Generic.List[object]]::new()
function Add-Result {
    param([string]$Check, [bool]$Ok, [string]$Detail)
    $results.Add([pscustomobject]@{ check = $Check; ok = $Ok; detail = $Detail })
}

$exitCode  = 0
$execError = $null
$temp      = $null

try {
    foreach ($t in 'git', 'pwsh') {
        if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { throw "required tool '$t' is not on PATH." }
    }
    foreach ($p in $hooksSrc, $genSrc, $staleSrc) {
        if (-not (Test-Path -LiteralPath $p)) { throw "template not found: $p" }
    }
    $pwshExe = (Get-Command pwsh).Source

    $temp   = Join-Path ([System.IO.Path]::GetTempPath()) ("aak-smoke-" + [guid]::NewGuid().ToString('N'))
    $work   = Join-Path $temp 'work'
    $remote = Join-Path $temp 'remote.git'
    New-Item -ItemType Directory -Path $work -Force   | Out-Null
    New-Item -ItemType Directory -Path $remote -Force | Out-Null

    git -C $remote init --bare -q
    git -C $work init -q
    git -C $work config user.email 'smoke@test.local'
    git -C $work config user.name  'Smoke Test'
    git -C $work config commit.gpgsign false

    # Install the hook templates exactly as repo-init would (versioned dir + hooksPath).
    $hooksDst = Join-Path $work '.githooks'
    New-Item -ItemType Directory -Path $hooksDst -Force | Out-Null
    foreach ($h in 'commit-msg', 'pre-commit', 'pre-push') {
        $dst = Join-Path $hooksDst $h
        Copy-Item -LiteralPath (Join-Path $hooksSrc $h) -Destination $dst -Force
        if (Get-Command chmod -ErrorAction SilentlyContinue) { & chmod +x $dst 2>$null }
    }
    git -C $work config core.hooksPath .githooks

    # Drop the release templates into scripts/ (NOT validate.ps1 - the hooks must find
    # no validator and degrade, which is part of what we are testing).
    $scriptsDst = Join-Path $work 'scripts'
    New-Item -ItemType Directory -Path $scriptsDst -Force | Out-Null
    Copy-Item -LiteralPath $genSrc   -Destination (Join-Path $scriptsDst 'Generate-Changelog.ps1') -Force
    Copy-Item -LiteralPath $staleSrc -Destination (Join-Path $scriptsDst 'check-changelog-staleness.ps1') -Force

    # Real commit -> fires pre-commit (gitleaks absent -> warn) + commit-msg (conventional).
    Set-Content -LiteralPath (Join-Path $work 'README.md') -Value "# Smoke test repo`n" -Encoding utf8NoBOM
    git -C $work add -A | Out-Null
    git -C $work commit -m "chore: smoke test baseline" 2>&1 | Out-Null
    Add-Result 'git-commit (pre-commit + commit-msg fire, degrade)' ($LASTEXITCODE -eq 0) "exit $LASTEXITCODE"

    # Real push -> fires pre-push (no validator present -> warn + exit 0).
    git -C $work remote add origin $remote
    $branch = (git -C $work rev-parse --abbrev-ref HEAD).Trim()
    git -C $work push -u origin $branch 2>&1 | Out-Null
    Add-Result 'git-push (pre-push fires, degrades)' ($LASTEXITCODE -eq 0) "exit $LASTEXITCODE"

    # Changelog generator under -NoProfile (the mojibake scenario).
    Push-Location $work
    try {
        & $pwshExe @('-NoProfile', '-File', (Join-Path $scriptsDst 'Generate-Changelog.ps1')) 2>&1 | Out-Null
        $genExit = $LASTEXITCODE
    }
    finally { Pop-Location }
    Add-Result 'Generate-Changelog.ps1 -NoProfile exit 0' ($genExit -eq 0) "exit $genExit"

    $clPath  = Join-Path $work 'CHANGELOG.md'
    $clBytes = if (Test-Path -LiteralPath $clPath) { [System.IO.File]::ReadAllBytes($clPath) } else { $null }
    Add-Result 'CHANGELOG.md non-empty' ($null -ne $clBytes -and $clBytes.Length -gt 0) `
        $(if ($null -ne $clBytes) { "$($clBytes.Length) bytes" } else { 'missing' })

    if ($null -ne $clBytes) {
        $firstNon = -1
        for ($i = 0; $i -lt $clBytes.Length; $i++) { if ($clBytes[$i] -gt 127) { $firstNon = $i; break } }
        Add-Result 'CHANGELOG.md ASCII (no mojibake bytes)' ($firstNon -lt 0) `
            $(if ($firstNon -ge 0) { "non-ASCII byte at offset $firstNon" } else { 'pure ASCII' })
    }
    else {
        Add-Result 'CHANGELOG.md ASCII (no mojibake bytes)' $false 'changelog missing'
    }

    # Staleness gate on an untagged repo -> pass (exit 0).
    Push-Location $work
    try {
        & $pwshExe @('-NoProfile', '-File', (Join-Path $scriptsDst 'check-changelog-staleness.ps1')) *> $null
        $staleExit = $LASTEXITCODE
    }
    finally { Pop-Location }
    Add-Result 'check-changelog-staleness.ps1 (untagged) exit 0' ($staleExit -eq 0) "exit $staleExit"

    if (@($results | Where-Object { -not $_.ok }).Count -gt 0) { $exitCode = 1 }
}
catch {
    $exitCode  = 2
    $execError = "$_"
}
finally {
    if ($temp -and (Test-Path -LiteralPath $temp)) {
        if ($KeepTemp) { Write-Host "smoke: temp repo kept at $temp" }
        else { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$passCount = @($results | Where-Object { $_.ok }).Count
$failCount = @($results | Where-Object { -not $_.ok }).Count

if ($Json) {
    [pscustomobject]@{
        exitCode       = $exitCode
        passed         = $passCount
        failed         = $failCount
        results        = @($results)
        executionError = $execError
    } | ConvertTo-Json -Depth 5
}
else {
    if ($results.Count -gt 0) {
        $results | ForEach-Object {
            "{0}  {1}  ({2})" -f $(if ($_.ok) { 'PASS' } else { 'FAIL' }), $_.check, $_.detail
        } | Out-String | Write-Host
    }
    Write-Host ("smoke: {0} passed, {1} failed; exit {2}" -f $passCount, $failCount, $exitCode)
    if ($exitCode -eq 2) { [Console]::Error.WriteLine("smoke: execution failure - $execError") }
}

exit $exitCode
