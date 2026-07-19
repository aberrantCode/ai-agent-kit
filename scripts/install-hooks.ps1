#Requires -Version 7.0
<#
.SYNOPSIS
    Opt-in installer for the local pre-push validation gate (P2, as modified).

.DESCRIPTION
    Points this repository's git `core.hooksPath` (a repo-local git config
    setting — never global, never applied to any other repo) at the committed
    `scripts/git-hooks/` directory, whose `pre-push` hook runs
    `scripts/validate.ps1` on every `git push` against this repo that carries
    commits, and rejects the push if it exits non-zero. Deletion-only pushes
    (`git push --delete <branch>`) skip the gate — they add no state to
    validate; see `scripts/git-hooks/pre-push` for the stdin mechanics.

    Strictly opt-in: a fresh clone has no hooksPath set and this hook does not
    run until someone explicitly invokes this script with -Force. Running the
    script without -Force only previews what would change (the shared
    preview-by-default safety convention, docs/requirements/canonical-repo.md
    §6) — it never writes git config on its own.

    Idempotent: if `core.hooksPath` already points at `scripts/git-hooks`
    (relative to the repo root, however git currently reports it — absolute or
    relative), running this script again — with or without -Force — is a
    reported no-op that writes nothing. Running it twice back to back is safe.

    See `scripts/git-hooks/pre-push` for the POSIX-sh mechanics (git invokes
    hooks via a shell using the file's shebang, never a .ps1 directly — even on
    Windows) and a plain-language explanation of how this hook interacts with
    erik's global "git-push-opens-Zed" PreToolUse hook (docs/reorg/charter.md
    §7): the two are independent and additive — the Zed hook is client-side
    (fires only inside Claude Code, before its `git push` tool call, for human
    review), this hook is git-side (fires for every `git push` from every
    client, once installed, as part of git's own push machinery) and can
    reject the push outright.

    To uninstall: `git config --unset core.hooksPath`.

    Applicable shared conventions (docs/requirements/canonical-repo.md §6):
      - Parameters: common surface is -TargetDir, -Force, -WhatIf, -Json.
        -Name is not applicable — there is nothing to name; this installs one
        fixed hook wiring for the whole repo.
      - Safety: preview-by-default; -Force is the explicit opt-in write. No
        existing file is overwritten — `git config core.hooksPath` is the only
        mutation, and it is fully reversible (see uninstall above). All target
        paths are canonicalized and containment-checked against -TargetDir.
      - Subprocess: `git` is invoked with an explicit executable + argument
        array (no shell string interpolation).
      - Portability: no Windows-only APIs; `core.hooksPath` is set to the
        repo-relative path `scripts/git-hooks` (forward slashes, as git itself
        expects) rather than an absolute path, so the same config value is
        valid on any machine or clone location.

.PARAMETER TargetDir
    Repository to install the hook into. Defaults to the current directory.
    Must be inside a git working tree.

.PARAMETER Force
    Apply the change: set `core.hooksPath` to `scripts/git-hooks`. Without it,
    the script only reports what it would do (preview/report-only default).

.PARAMETER WhatIf
    Standard PowerShell ShouldProcess preview — equivalent to omitting -Force.

.PARAMETER Json
    Emit a JSON status object instead of a console message.

.OUTPUTS
    Console status line (default) or JSON object (-Json): whether the hook was
    already installed, whether a change was applied, and the previous
    `core.hooksPath` value (if any).

.NOTES
    Exit codes:
      0 = success — already installed (no-op), previewed, or newly installed
      1 = validation failure — -TargetDir is not a git working tree, or the
          prerequisite `scripts/git-hooks/pre-push` file is missing
      2 = execution error — unexpected exception (git invocation failure, etc.)

.EXAMPLE
    ./scripts/install-hooks.ps1
    # Preview only — reports what would change, writes nothing.

.EXAMPLE
    ./scripts/install-hooks.ps1 -Force
    # Installs the hook (or confirms it is already installed).

.EXAMPLE
    ./scripts/install-hooks.ps1 -Force -Json
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Alias('RepoRoot')]
    [string]$TargetDir = '.',

    [switch]$Force,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:HooksPathValue = 'scripts/git-hooks'

function Get-GitExe {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "No git executable found on PATH."
}

$exitCode = 0
$script:ExecError = $null
$result = [ordered]@{
    targetDir       = $null
    hooksPathValue  = $script:HooksPathValue
    alreadyInstalled = $false
    applied         = $false
    previousValue   = $null
    message         = ''
}

# Single-exit-point design (mirrors audit.ps1): every branch below sets $exitCode
# and $result.message and falls through to the unified report block at the bottom,
# rather than calling `exit` mid-script — so -Json always gets a chance to emit,
# regardless of which branch was taken.
try {
    $resolvedTargetDir = (Resolve-Path -LiteralPath $TargetDir).Path
    $result.targetDir = $resolvedTargetDir
    $gitExe = Get-GitExe

    $isWorkTree = & $gitExe @('-C', $resolvedTargetDir, 'rev-parse', '--is-inside-work-tree') 2>$null
    if ($LASTEXITCODE -ne 0 -or $isWorkTree -ne 'true') {
        $result.message = "not a git working tree: $resolvedTargetDir"
        $exitCode = 1
    }
    else {
        $hooksDir = Join-Path $resolvedTargetDir 'scripts/git-hooks'
        $prePushHook = Join-Path $hooksDir 'pre-push'
        if (-not (Test-Path -LiteralPath $prePushHook)) {
            $result.message = "prerequisite missing: $prePushHook (expected a committed pre-push hook script)"
            $exitCode = 1
        }
        else {
            $repoRootForGit = (& $gitExe @('-C', $resolvedTargetDir, 'rev-parse', '--show-toplevel') 2>$null)
            if ($LASTEXITCODE -ne 0) { throw "git rev-parse --show-toplevel failed (exit $LASTEXITCODE)." }

            $currentValueRaw = & $gitExe @('-C', $resolvedTargetDir, 'config', '--get', 'core.hooksPath') 2>$null
            $currentGetExit = $LASTEXITCODE
            $currentValue = if ($currentGetExit -eq 0) { $currentValueRaw } else { $null }
            $result.previousValue = $currentValue

            # Idempotency check: treat the value as already-installed if it resolves
            # to the same directory we'd set it to, whether git reports it relative
            # or absolute.
            $alreadyInstalled = $false
            if ($currentValue) {
                $currentFull = if ([System.IO.Path]::IsPathRooted($currentValue)) {
                    [System.IO.Path]::GetFullPath($currentValue)
                } else {
                    [System.IO.Path]::GetFullPath((Join-Path $repoRootForGit $currentValue))
                }
                $targetFull = [System.IO.Path]::GetFullPath($hooksDir)
                $alreadyInstalled = ($currentFull -eq $targetFull)
            }
            $result.alreadyInstalled = $alreadyInstalled

            if ($alreadyInstalled) {
                $result.message = "already installed — core.hooksPath is '$currentValue'; no-op."
                $exitCode = 0
            }
            elseif (-not $Force) {
                $result.message = if ($currentValue) {
                    "preview only — would change core.hooksPath from '$currentValue' to '$($script:HooksPathValue)'. Re-run with -Force to apply."
                } else {
                    "preview only — would set core.hooksPath to '$($script:HooksPathValue)'. Re-run with -Force to apply."
                }
                $exitCode = 0
            }
            elseif (-not $PSCmdlet.ShouldProcess($resolvedTargetDir, "Set core.hooksPath = $($script:HooksPathValue)")) {
                $result.message = 'preview only (-WhatIf) — no change written.'
                $exitCode = 0
            }
            else {
                & $gitExe @('-C', $resolvedTargetDir, 'config', 'core.hooksPath', $script:HooksPathValue)
                if ($LASTEXITCODE -ne 0) { throw "git config core.hooksPath failed (exit $LASTEXITCODE)." }

                $result.applied = $true
                $result.message = if ($currentValue) {
                    "installed — core.hooksPath changed from '$currentValue' to '$($script:HooksPathValue)'."
                } else {
                    "installed — core.hooksPath set to '$($script:HooksPathValue)'."
                }
                $exitCode = 0
            }
        }
    }
}
catch {
    $script:ExecError = $_
    $exitCode = 2
    $result.message = "execution failure: $($script:ExecError)"
}

# ---------------------------------------------------------------------------
# Report (single exit point)
# ---------------------------------------------------------------------------
if ($Json) {
    $result | ConvertTo-Json -Depth 5
}
else {
    Write-Host "install-hooks: $($result.message)"
    if ($exitCode -eq 2) {
        [Console]::Error.WriteLine("install-hooks: $($result.message)")
    }
}

exit $exitCode
