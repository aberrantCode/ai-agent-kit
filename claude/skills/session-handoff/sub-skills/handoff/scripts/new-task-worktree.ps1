<#
.SYNOPSIS
    Sync the local base branch to its remote and create a dedicated worktree for a handoff session.

.DESCRIPTION
    A spawned session should never start by figuring out where to work. This creates the isolated
    checkout up front, branched off the *remote* base rather than whatever the local branch
    happens to be, so the new session cannot inherit stale commits from a checkout nobody has
    pulled in a week.

    The sync is fast-forward only. If the local base has diverged from the remote that is a real
    situation needing a human, and silently resetting it would destroy work.

.PARAMETER RepoPath
    Any path inside the target repository. Defaults to the current location.

.PARAMETER Slug
    Short hyphenated task name. Becomes both the worktree directory and the branch suffix.

.PARAMETER Type
    Conventional-commit branch prefix: feat, fix, refactor, docs, test, chore, perf, ci.

.PARAMETER BaseBranch
    Branch to build from. Defaults to dev, falling back to the remote's default branch.

.PARAMETER WorktreeRoot
    Directory holding worktrees, relative to the repo root. Defaults to .worktrees.

.PARAMETER SyncDeps
    Run the repo's dependency sync inside the new worktree (uv sync / npm ci) when detected.

.OUTPUTS
    PSCustomObject with WorktreePath, Branch, BaseBranch, BaseCommit, RepoRoot.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = (Get-Location).Path,
    [Parameter(Mandatory = $true)][string]$Slug,
    [ValidateSet('feat', 'fix', 'refactor', 'docs', 'test', 'chore', 'perf', 'ci')]
    [string]$Type = 'chore',
    [string]$BaseBranch = 'dev',
    [string]$WorktreeRoot = '.worktrees',
    [switch]$SyncDeps
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param([string[]]$Arguments, [switch]$AllowFailure)
    $output = & git -C $script:RepoRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        throw "git $($Arguments -join ' ') failed:`n$output"
    }
    return ($output | Out-String).Trim()
}

if (-not (Test-Path -LiteralPath $RepoPath)) { throw "Path not found: $RepoPath" }
$script:RepoRoot = (& git -C $RepoPath rev-parse --show-toplevel 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Not a git repository: $RepoPath" }
$script:RepoRoot = $script:RepoRoot.Trim()

$Slug = ($Slug -replace '[^\w\-]+', '-').Trim('-').ToLowerInvariant()
if (-not $Slug) { throw 'Slug reduced to empty after normalisation.' }
$branch = "$Type/$Slug"

Invoke-Git @('fetch', 'origin', '--prune') | Out-Null

# Fall back to the remote's default branch when the requested base does not exist upstream —
# not every repo uses dev.
if (-not (Invoke-Git @('ls-remote', '--heads', 'origin', $BaseBranch))) {
    $head = Invoke-Git @('symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD') -AllowFailure
    $fallback = if ($head) { $head -replace '^refs/remotes/origin/', '' } else { 'main' }
    Write-Warning "origin/$BaseBranch not found; using origin/$fallback as the base."
    $BaseBranch = $fallback
}

if (Invoke-Git @('rev-parse', '--verify', '--quiet', "refs/heads/$branch") -AllowFailure) {
    throw "Branch '$branch' already exists. Pick a different slug or clean up the previous run."
}

# Bring the local base branch up to the remote, fast-forward only.
$localBase = Invoke-Git @('rev-parse', '--verify', '--quiet', "refs/heads/$BaseBranch") -AllowFailure
if ($localBase) {
    $behind, $ahead = (Invoke-Git @('rev-list', '--left-right', '--count', "origin/$BaseBranch...$BaseBranch")) -split '\s+'
    if ([int]$ahead -gt 0) {
        throw "Local $BaseBranch is $ahead commit(s) ahead of origin/$BaseBranch. Resolve that before branching — fast-forwarding would lose them."
    }
    if ([int]$behind -gt 0) {
        $current = Invoke-Git @('rev-parse', '--abbrev-ref', 'HEAD')
        if ($current -eq $BaseBranch) {
            Invoke-Git @('merge', '--ff-only', "origin/$BaseBranch") | Out-Null
        }
        else {
            # Updating a ref we do not have checked out; refuses unless it is a fast-forward.
            Invoke-Git @('fetch', 'origin', "${BaseBranch}:${BaseBranch}") | Out-Null
        }
        Write-Host "Synced $BaseBranch to origin/$BaseBranch (+$behind commit(s))."
    }
    else {
        Write-Host "$BaseBranch already matches origin/$BaseBranch."
    }
}

$worktreePath = Join-Path $script:RepoRoot (Join-Path $WorktreeRoot $Slug)
if (Test-Path -LiteralPath $worktreePath) { throw "Worktree path already exists: $worktreePath" }

Invoke-Git @('worktree', 'add', $worktreePath, '-b', $branch, "origin/$BaseBranch") | Out-Null
$baseCommit = Invoke-Git @('rev-parse', '--short', "origin/$BaseBranch")
Write-Host "Created worktree $worktreePath on $branch (from origin/$BaseBranch @ $baseCommit)."

if ($SyncDeps) {
    if ((Test-Path (Join-Path $worktreePath 'pyproject.toml')) -and (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Host 'Running uv sync...'
        & uv sync --directory $worktreePath --quiet
        if ($LASTEXITCODE -ne 0) { Write-Warning 'uv sync failed; the new session will need to sort dependencies out itself.' }
    }
    elseif ((Test-Path (Join-Path $worktreePath 'package-lock.json')) -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host 'Running npm ci...'
        Push-Location $worktreePath
        try { & npm ci --silent } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { Write-Warning 'npm ci failed; the new session will need to sort dependencies out itself.' }
    }
}

[pscustomobject]@{
    WorktreePath = $worktreePath
    Branch       = $branch
    BaseBranch   = $BaseBranch
    BaseCommit   = $baseCommit
    RepoRoot     = $script:RepoRoot
}
