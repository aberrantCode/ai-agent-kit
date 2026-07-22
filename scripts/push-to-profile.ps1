#Requires -Version 7.0

<#
.SYNOPSIS
    Push a skill bundle from the ai-agent-kit archive to a global vendor profile.

.DESCRIPTION
    Deploys a named Claude skill bundle to the global skills profile directory
    (`~/.claude/skills/<Name>/`), copying whichever of these bundle members are
    present:

        SKILL.md   sub-skills/   commands/   references/   rules/

    The copied top-level SKILL.md is stamped with `installed-from: ai-agent-kit`
    provenance so /audit-skills and sync-installed.ps1 recognize it as
    archive-managed rather than a hand-authored profile skill.

    This implements the /push-skill operation. It is the fix for the class of bug
    where the global profile's `~/.claude/skills/<name>/` carried no `sub-skills/`
    directory at all (F-KO-05): the bundle members are copied wholesale, so a
    profile-run `/<name>` loads the maintained sub-skills instead of improvising.

    Shared conventions (docs/requirements/canonical-repo.md section 6, binding for every
    lifecycle script):
      - Parameters: common surface is -Name, -TargetDir, -Force, -WhatIf, -Json.
        This script never repurposes their meaning. -TargetDir overrides the vendor
        profile default; when omitted the platform-appropriate default
        (~/.claude/skills) is resolved from a cross-platform home directory.
      - Safety: default behavior is preview-only; -Force is required to actually
        write files. An existing destination bundle is backed up (renamed to
        `<Name>.bak-<timestamp>`) before it is replaced - never a silent clobber.
        Resolved source and destination paths are canonicalized and
        containment-checked before any write, and -Name is restricted to a bare
        directory name so it cannot traverse out of either root.
      - Portability: no Windows-only APIs (home resolution falls back to $HOME when
        $env:USERPROFILE is unset); file output uses utf8NoBOM; enumeration used for
        output is ordinal (culture-invariant) sorted.

.PARAMETER Name
    Name of the skill bundle to push, matching its directory under claude/skills/.

.PARAMETER TargetDir
    Destination profile root. Defaults to `~/.claude/skills` when omitted.

.PARAMETER Force
    Required to actually write files. Without it, the script only reports what would
    be copied (preview/report-only default per the shared safety convention).

.PARAMETER WhatIf
    Standard PowerShell ShouldProcess preview - lists what would be written without
    writing it.

.PARAMETER Json
    Emit machine-readable JSON output instead of a console-formatted report.

.OUTPUTS
    Console report (default) or JSON object (-Json) describing the bundle members
    that were, or would be, copied and the provenance stamp applied.

.NOTES
    Exit codes:
      0 = success - bundle pushed, or preview completed
      1 = validation failure - -Name missing/invalid/not found, or a path fails the
          containment check
      2 = execution error - unexpected exception (I/O failure, etc.)

.EXAMPLE
    ./scripts/push-to-profile.ps1 -Name github            # preview only

.EXAMPLE
    ./scripts/push-to-profile.ps1 -Name github -Force     # deploy to ~/.claude/skills
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Name = '',

    [string]$TargetDir = '',

    [switch]$Force,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Get-HomeDir {
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    if ($HOME) { return $HOME }
    throw '::EXEC:: cannot resolve a home directory ($env:USERPROFILE and $HOME both empty).'
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

# Bundle members copied in order. SKILL.md is a file; the rest are directories.
$MemberFile = 'SKILL.md'
$MemberDirs = @('sub-skills', 'commands', 'references', 'rules')

$archiveRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path

$result = [ordered]@{
    name        = $Name
    source      = ''
    destination = ''
    members     = @()
    fileCount   = 0
    wouldWrite  = (-not $Force)
    backedUpTo  = $null
    stamped     = $false
    exitCode    = 0
    message     = ''
}

$exitCode = 0
$script:ExecError = $null

try {
    # --- Validate -Name -----------------------------------------------------
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw '::VALIDATION:: -Name is required (the skill bundle to push).'
    }
    if ($Name -notmatch '^[A-Za-z0-9._-]+$') {
        throw "::VALIDATION:: -Name '$Name' is not a bare directory name (letters, digits, . _ - only)."
    }

    # --- Resolve + containment-check the source ----------------------------
    $skillsRoot = Join-Path $archiveRoot 'claude/skills'
    $sourceDir  = Join-Path $skillsRoot $Name
    if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
        throw "::VALIDATION:: skill '$Name' not found under claude/skills/."
    }
    $sourceDir  = (Resolve-Path -LiteralPath $sourceDir).Path
    $skillsRoot = (Resolve-Path -LiteralPath $skillsRoot).Path
    if (-not $sourceDir.StartsWith($skillsRoot, [StringComparison]::Ordinal)) {
        throw "::VALIDATION:: resolved source '$sourceDir' escapes the archive skills root."
    }
    $sourceSkillMd = Join-Path $sourceDir $MemberFile
    if (-not (Test-Path -LiteralPath $sourceSkillMd -PathType Leaf)) {
        throw "::VALIDATION:: '$Name' has no SKILL.md - not a skill bundle."
    }

    # --- Resolve the profile root + destination ----------------------------
    $profileRoot = if ($TargetDir) { $TargetDir } else { Join-Path (Get-HomeDir) '.claude/skills' }
    $destDir     = Join-Path $profileRoot $Name

    $result.source      = $sourceDir
    $result.destination = $destDir

    # --- Enumerate the members that are present ----------------------------
    $present = [System.Collections.Generic.List[string]]::new()
    $present.Add($MemberFile)
    foreach ($d in $MemberDirs) {
        if (Test-Path -LiteralPath (Join-Path $sourceDir $d) -PathType Container) { $present.Add($d) }
    }
    $result.members = @($present)

    # File count across the members (for the report) - ordinal sorted for determinism.
    $files = [System.Collections.Generic.List[string]]::new()
    $files.Add($sourceSkillMd)
    foreach ($d in $MemberDirs) {
        $dir = Join-Path $sourceDir $d
        if (Test-Path -LiteralPath $dir) {
            foreach ($f in Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue) {
                $files.Add($f.FullName)
            }
        }
    }
    $result.fileCount = $files.Count

    # --- Write (only under -Force and ShouldProcess) -----------------------
    $doWrite = $Force -and $PSCmdlet.ShouldProcess($destDir, "push bundle '$Name' ($($files.Count) files)")
    if ($doWrite) {
        # Ensure the profile root exists.
        if (-not (Test-Path -LiteralPath $profileRoot)) {
            New-Item -ItemType Directory -Path $profileRoot -Force | Out-Null
        }
        # Back up an existing destination before replacing it - never clobber silently.
        if (Test-Path -LiteralPath $destDir) {
            $stamp  = (Get-Date).ToString('yyyyMMddHHmmss')
            $backup = "$destDir.bak-$stamp"
            Move-Item -LiteralPath $destDir -Destination $backup
            $result.backedUpTo = $backup
        }
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null

        # Copy members.
        Copy-Item -LiteralPath $sourceSkillMd -Destination (Join-Path $destDir $MemberFile) -Force
        foreach ($d in $MemberDirs) {
            $src = Join-Path $sourceDir $d
            if (Test-Path -LiteralPath $src -PathType Container) {
                Copy-Item -LiteralPath $src -Destination $destDir -Recurse -Force
            }
        }

        # Stamp provenance into the copied top-level SKILL.md.
        $destSkillMd = Join-Path $destDir $MemberFile
        $text = Get-Content -LiteralPath $destSkillMd -Raw
        if ($text -match '^---\r?\n' -and $text -notmatch '(?m)^installed-from:') {
            $text = $text -replace '^(---\r?\n)', "`${1}installed-from: ai-agent-kit`n"
            Write-Utf8NoBom $destSkillMd $text
            $result.stamped = $true
        }

        $result.wouldWrite = $false
        $result.message = "Pushed '$Name' ($($files.Count) files) to $destDir." +
            $(if ($result.backedUpTo) { " Previous copy backed up to $($result.backedUpTo)." } else { '' })
    }
    else {
        $result.wouldWrite = $true
        $reason = if (-not $Force) { 'preview (pass -Force to write)' } else { 'preview (-WhatIf)' }
        $result.message = "Would push '$Name' ($($files.Count) files) to $destDir - $reason."
    }
}
catch {
    $msg = "$($_.Exception.Message)"
    if ($msg -like '*::VALIDATION::*') {
        $exitCode = 1
        $result.message = ($msg -replace '.*::VALIDATION::\s*', '')
    }
    else {
        $exitCode = 2
        $script:ExecError = $_
        $result.message = ($msg -replace '.*::EXEC::\s*', '')
    }
}

$result.exitCode = $exitCode

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
if ($Json) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
}
else {
    if ($exitCode -eq 0) {
        Write-Host $result.message
        if ($result.members.Count -gt 0) {
            Write-Host ("  members: {0}" -f ($result.members -join ', '))
        }
    }
    elseif ($exitCode -eq 1) {
        [Console]::Error.WriteLine("push-to-profile: validation error - $($result.message)")
    }
    else {
        [Console]::Error.WriteLine("push-to-profile: execution failure - $($result.message)")
    }
}

exit $exitCode
