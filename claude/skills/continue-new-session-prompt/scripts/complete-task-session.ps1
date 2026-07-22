<#
.SYNOPSIS
    Verify a handoff session finished cleanly, then retire its prompt file and worktree.

.DESCRIPTION
    The prompt file is the only durable record of what a spawned session was asked to do. Deleting
    it while the work is unverified destroys the ability to re-run, audit, or hand the task to
    someone else — so this refuses to delete until four conditions hold:

      1. The task branch is merged into the base branch on the remote.
      2. The local base branch matches origin exactly (no unpushed or unpulled commits).
      3. The repo's tests pass.
      4. A human has confirmed the work is what they wanted (-Confirmed).

    The first three are mechanical and checked here. The fourth cannot be inferred from the repo:
    a merged branch with green tests can still be the wrong solution, which is precisely what a
    human review catches. An agent may only pass -Confirmed after the user has actually said so.

    Reports every check and exits non-zero if any fail, deleting nothing.

.PARAMETER RepoPath
    Any path inside the repository. Defaults to the current location.

.PARAMETER PromptPath
    The handoff prompt file to retire once every gate passes.

.PARAMETER Branch
    The task branch that should have been merged.

.PARAMETER BaseBranch
    Branch the work merges into. Defaults to dev.

.PARAMETER TestCommand
    Command to run for the test gate. Auto-detected from the repo when omitted
    (uv/pytest for Python, npm test for Node).

.PARAMETER SkipTests
    Record the test gate as skipped rather than running it. Use when tests were already run and
    reported in this session; the reason is printed so the skip is never silent.

.PARAMETER Confirmed
    The human sign-off gate. Without it nothing is deleted, regardless of the other checks.

.PARAMETER KeepWorktree
    Verify and delete the prompt, but leave the worktree and branch in place.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$PromptPath,
    [Parameter(Mandatory = $true)][string]$Branch,
    [string]$BaseBranch = 'dev',
    [string]$TestCommand,
    [switch]$SkipTests,
    [switch]$Confirmed,
    [switch]$KeepWorktree
)

$ErrorActionPreference = 'Stop'

$repoRoot = (& git -C $RepoPath rev-parse --show-toplevel 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Not a git repository: $RepoPath" }
$repoRoot = $repoRoot.Trim()

function Invoke-Git {
    param([string[]]$Arguments, [switch]$AllowFailure)
    $output = & git -C $repoRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) { throw "git $($Arguments -join ' ') failed:`n$output" }
    return ($output | Out-String).Trim()
}

$results = [System.Collections.Generic.List[object]]::new()
function Add-Check {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    $results.Add([pscustomobject]@{ Check = $Name; Passed = $Passed; Detail = $Detail })
}

Invoke-Git @('fetch', 'origin', '--prune') | Out-Null

# 1. Branch merged into the remote base.
$merged = $false
$detail = "branch '$Branch' not found locally or on origin"
$tip = Invoke-Git @('rev-parse', '--verify', '--quiet', "refs/heads/$Branch") -AllowFailure
if (-not $tip) { $tip = Invoke-Git @('rev-parse', '--verify', '--quiet', "refs/remotes/origin/$Branch") -AllowFailure }
if ($tip) {
    $baseTip = Invoke-Git @('rev-parse', "origin/$BaseBranch")
    if ($tip -eq $baseTip) {
        # A branch that never committed is trivially an ancestor of its base. Treating that as
        # "merged" would let the gate retire a session that did nothing at all.
        $detail = "$Branch has no commits of its own — nothing was merged"
    }
    else {
        Invoke-Git @('merge-base', '--is-ancestor', $tip, "origin/$BaseBranch") -AllowFailure | Out-Null
        $merged = ($LASTEXITCODE -eq 0)
        $detail = if ($merged) { "$Branch is an ancestor of origin/$BaseBranch" } else { "$Branch has commits not in origin/$BaseBranch" }
    }
}
Add-Check "branch merged into origin/$BaseBranch" $merged $detail

# 2. Local base identical to origin.
$localTip = Invoke-Git @('rev-parse', '--verify', '--quiet', "refs/heads/$BaseBranch") -AllowFailure
$remoteTip = Invoke-Git @('rev-parse', '--verify', '--quiet', "refs/remotes/origin/$BaseBranch") -AllowFailure
$synced = ($localTip -and $remoteTip -and $localTip -eq $remoteTip)
$syncDetail = if ($synced) { "both at $($localTip.Substring(0,7))" }
              elseif (-not $localTip) { "local $BaseBranch does not exist" }
              else { "local $($localTip.Substring(0,7)) vs origin $($remoteTip.Substring(0,7))" }
Add-Check "local $BaseBranch synced to origin" $synced $syncDetail

# 3. Tests.
if ($SkipTests) {
    Add-Check 'tests' $true 'skipped by caller (-SkipTests)'
}
else {
    if (-not $TestCommand) {
        if (Test-Path (Join-Path $repoRoot 'pyproject.toml')) {
            $TestCommand = if (Get-Command uv -ErrorAction SilentlyContinue) { 'uv run pytest -q' } else { 'pytest -q' }
        }
        elseif (Test-Path (Join-Path $repoRoot 'package.json')) { $TestCommand = 'npm test' }
    }
    if (-not $TestCommand) {
        Add-Check 'tests' $false 'no test command detected; pass -TestCommand or -SkipTests'
    }
    else {
        Write-Host "Running: $TestCommand"
        Push-Location $repoRoot
        try { Invoke-Expression $TestCommand; $testExit = $LASTEXITCODE } finally { Pop-Location }
        Add-Check 'tests' ($testExit -eq 0) "$TestCommand exited $testExit"
    }
}

# 4. Human sign-off.
Add-Check 'user confirmed the work' ([bool]$Confirmed) $(if ($Confirmed) { 'confirmed by caller' } else { 'not confirmed — rerun with -Confirmed once the user has signed off' })

Write-Host ''
foreach ($r in $results) {
    $mark = if ($r.Passed) { 'PASS' } else { 'FAIL' }
    Write-Host ("  [{0}] {1} — {2}" -f $mark, $r.Check, $r.Detail)
}

if ($results | Where-Object { -not $_.Passed }) {
    Write-Host "`nGates failed. Nothing deleted; the prompt and worktree are intact." -ForegroundColor Yellow
    exit 1
}

if (Test-Path -LiteralPath $PromptPath) {
    Remove-Item -LiteralPath $PromptPath -Force
    Write-Host "`nDeleted prompt: $PromptPath"
}
else {
    Write-Host "`nPrompt already gone: $PromptPath"
}

if (-not $KeepWorktree) {
    # Split on \r?\n: git's porcelain output keeps CRLF on Windows, and a stray \r rides along
    # inside the captured path, quietly breaking any comparison made against it.
    $worktreeLines = (Invoke-Git @('worktree', 'list', '--porcelain')) -split '\r?\n'
    $branchRef = "refs/heads/$Branch"
    $worktree = $null
    $currentPath = $null
    foreach ($line in $worktreeLines) {
        $line = $line.Trim()
        if ($line -match '^worktree (.+)$') { $currentPath = $Matches[1] }
        elseif ($line -match '^branch (.+)$' -and $Matches[1] -eq $branchRef) {
            $worktree = $currentPath
            break
        }
    }

    if ($worktree) {
        # Unforced on purpose: it refuses on a dirty tree, which is the outcome you want if the
        # session left uncommitted work behind.
        Invoke-Git @('worktree', 'remove', $worktree) -AllowFailure | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host "Removed worktree: $worktree" }
        else { Write-Warning "Worktree $worktree not removed (likely uncommitted changes). Inspect it, then remove it yourself." }
    }
    else {
        Write-Host "No worktree is checked out on $Branch; nothing to remove."
    }

    Invoke-Git @('branch', '-d', $Branch) -AllowFailure | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "Deleted local branch: $Branch" }
    else { Write-Warning "Local branch $Branch not deleted — it may still be checked out in a worktree." }
}

Write-Host 'Session retired cleanly.'
