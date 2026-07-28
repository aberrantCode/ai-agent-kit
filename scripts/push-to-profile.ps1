#Requires -Version 7.0

<#
.SYNOPSIS
    Push a skill bundle from the ai-agent-kit archive to a global vendor profile.

.DESCRIPTION
    Deploys a named skill bundle from <Vendor>/skills/<Name> to the vendor's global
    profile, mirroring the archive layout:

        ~/.<vendor>/skills/<Name>/SKILL.md          (parent skill)
        ~/.<vendor>/skills/<Name>/sub-skills/**      (NESTED — see below)
        ~/.<vendor>/skills/<Name>/references/**
        ~/.<vendor>/skills/<Name>/rules/**
        ~/.<vendor>/skills/<Name>/scripts/**
        ~/.<vendor>/commands/<cmd>.md                (companion commands — top level)

    NESTED sub-skills, not flattened. Sub-skills stay INSIDE the bundle and are reached
    through the parent skill's relative `sub-skills/<sub>` path. Writing a sub-skill to a
    loose top-level `~/.<vendor>/skills/<sub>/` would shadow the bundle's own sub-skill
    (audit.ps1 Check 8, `profile-shadowing`) and break the parent's delegation. This also
    fixes F-KO-05, where the profile bundle carried no `sub-skills/` at all: the members
    are copied wholesale so a profile-run `/<name>` loads the maintained sub-skills.

    Companion commands are the exception — they are the top-level slash-command entry
    points and MUST land in `~/.<vendor>/commands/` to be discoverable, not nested under
    the bundle.

    PROVENANCE. Every copied SKILL.md — the parent and each nested sub-skill — is stamped
    `installed-from: ai-agent-kit` so /audit-skills, /find-skills, /sync-skill, and
    sync-installed.ps1 recognize the copy as an archive deployment (a downstream target,
    like /install-skill writing into a project) rather than a hand-authored profile
    source. Commands, references, rules, and scripts are copied verbatim (not stamped).

    `status: draft` bundles are skipped — drafts are not pushed to a global profile.

    Shared conventions (docs/requirements/canonical-repo.md section 6, binding for every
    lifecycle script):
      - Parameters: common surface is -Name, -TargetDir, -Force, -WhatIf, -Json. This
        script never repurposes their meaning. -TargetDir overrides the vendor skills
        root; when omitted the platform-appropriate default (~/.<vendor>/skills) is
        resolved from a cross-platform home directory. -Vendor (claude|codex|gemini) is
        an added specific selecting both the archive source tree and the default profile.
      - Safety: default behavior is preview-only; -Force is required to actually write
        files. An existing destination bundle is backed up to a sibling
        `<skillsRoot>-backups/<Name>.bak-<timestamp>` (outside the scanned skills root,
        so the backup is never loaded as a duplicate skill) before it is replaced —
        never a silent clobber. Resolved source and destination paths are canonicalized
        and containment-checked before any write, and -Name is restricted to a bare
        directory name so it cannot traverse out of either root.
      - Portability: no Windows-only APIs (home resolution falls back to $HOME when
        $env:USERPROFILE is unset); file output uses utf8NoBOM; enumeration used for
        output is ordinal (culture-invariant) sorted.

.PARAMETER Name
    Name of the skill bundle to push, matching its directory under <Vendor>/skills/.

.PARAMETER Vendor
    Which archive tree and default profile the bundle belongs to: claude (default),
    codex, or gemini. Selects source <Vendor>/skills/<Name> and default skills root
    ~/.<Vendor>/skills.

.PARAMETER TargetDir
    Destination skills root. Defaults to `~/.<vendor>/skills` when omitted. Companion
    commands are written to its sibling `commands/` directory.

.PARAMETER Force
    Required to actually write files. Without it, the script only reports what would be
    copied (preview/report-only default per the shared safety convention).

.PARAMETER WhatIf
    Standard PowerShell ShouldProcess preview — lists what would be written without
    writing it.

.PARAMETER Json
    Emit machine-readable JSON output instead of a console-formatted report.

.OUTPUTS
    Console report (default) or JSON object (-Json) describing the bundle members that
    were, or would be, copied; the sub-skill SKILL.md files stamped; the companion
    commands relocated; and any backup taken.

.NOTES
    Exit codes:
      0 = success — bundle pushed, preview completed, or draft skipped
      1 = validation failure — -Name missing/invalid/not found, or a path fails the
          containment check
      2 = execution error — unexpected exception (I/O failure, etc.)

.EXAMPLE
    ./scripts/push-to-profile.ps1 -Name github            # preview only

.EXAMPLE
    ./scripts/push-to-profile.ps1 -Name github -Force     # deploy to ~/.claude

.EXAMPLE
    ./scripts/push-to-profile.ps1 -Name project-manager -Force -Json
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Name = '',

    [ValidateSet('claude', 'codex', 'gemini')]
    [string]$Vendor = 'claude',

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

# Stamp `installed-from: ai-agent-kit` right after the opening frontmatter fence.
# Idempotent (no-op if already stamped or if there is no frontmatter). Returns $true
# when it wrote a stamp.
function Add-Provenance {
    param([string]$Path)
    $text = Get-Content -LiteralPath $Path -Raw
    if ($text -match '^---\r?\n' -and $text -notmatch '(?m)^installed-from:') {
        $text = $text -replace '^(---\r?\n)', "`${1}installed-from: ai-agent-kit`n"
        Write-Utf8NoBom $Path $text
        return $true
    }
    return $false
}

# Read the `status:` frontmatter value (lowercased), or '' if absent.
function Get-StatusField {
    param([string]$Path)
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line.Trim() -eq '---') { continue }
        if ($line -match '^\s*status\s*:\s*(\S+)') { return $Matches[1].ToLowerInvariant() }
        if ($line -match '^\s*$') { continue }
    }
    return ''
}

# Bundle members that live NESTED inside the deployed bundle. SKILL.md is a file; the
# rest are directories copied recursively. `commands` is deliberately NOT here — it is
# relocated to the profile's top-level commands/ dir (see below).
$MemberFile = 'SKILL.md'
$MemberDirs = @('sub-skills', 'references', 'rules', 'scripts')

$archiveRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path

$result = [ordered]@{
    name          = $Name
    vendor        = $Vendor
    source        = ''
    destination   = ''
    commandsDest  = ''
    members       = @()
    fileCount     = 0
    subSkillsNested = 0
    stampedCount  = 0
    commandCount  = 0
    wouldWrite    = (-not $Force)
    skippedDraft  = $false
    backedUpTo    = $null
    exitCode      = 0
    message       = ''
}

$exitCode = 0
$script:ExecError = $null

try {
    # --- Validate -Name -----------------------------------------------------
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw '::VALIDATION:: -Name is required (the skill bundle to push).'
    }
    if ($Name -notmatch '^[A-Za-z0-9._-]+$' -or $Name -match '\.\.') {
        throw "::VALIDATION:: -Name '$Name' is not a bare directory name (letters, digits, . _ - only; no '..')."
    }

    # --- Resolve + containment-check the source ----------------------------
    $skillsArchive = Join-Path $archiveRoot (Join-Path $Vendor 'skills')
    $sourceDir     = Join-Path $skillsArchive $Name
    if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
        throw "::VALIDATION:: skill '$Name' not found under $Vendor/skills/."
    }
    $sourceDir     = (Resolve-Path -LiteralPath $sourceDir).Path
    $skillsArchive = (Resolve-Path -LiteralPath $skillsArchive).Path
    if (-not $sourceDir.StartsWith($skillsArchive, [StringComparison]::Ordinal)) {
        throw "::VALIDATION:: resolved source '$sourceDir' escapes the archive skills root."
    }
    $sourceSkillMd = Join-Path $sourceDir $MemberFile
    if (-not (Test-Path -LiteralPath $sourceSkillMd -PathType Leaf)) {
        throw "::VALIDATION:: '$Name' has no SKILL.md - not a skill bundle."
    }

    # --- Draft gate ---------------------------------------------------------
    if ((Get-StatusField $sourceSkillMd) -eq 'draft') {
        $result.skippedDraft = $true
        $result.wouldWrite = $false
        $result.message = "Skill '$Name' has status: draft — skipped (drafts are not pushed to the global profile)."
        $result.exitCode = 0
        if ($Json) { [pscustomobject]$result | ConvertTo-Json -Depth 6 } else { Write-Host $result.message }
        exit 0
    }

    # --- Resolve the skills root, commands root, destination ---------------
    $skillsRoot   = if ($TargetDir) { $TargetDir } else { Join-Path (Get-HomeDir) (Join-Path ".$Vendor" 'skills') }
    $commandsRoot = Join-Path (Split-Path -Parent $skillsRoot) 'commands'
    $destDir      = Join-Path $skillsRoot $Name

    $result.source       = $sourceDir
    $result.destination  = $destDir
    $result.commandsDest = $commandsRoot

    # --- Enumerate the members that are present ----------------------------
    $present = [System.Collections.Generic.List[string]]::new()
    $present.Add($MemberFile)
    foreach ($d in $MemberDirs) {
        if (Test-Path -LiteralPath (Join-Path $sourceDir $d) -PathType Container) { $present.Add($d) }
    }
    $hasCommands = Test-Path -LiteralPath (Join-Path $sourceDir 'commands') -PathType Container
    if ($hasCommands) { $present.Add('commands') }
    $result.members = @($present)

    # Sub-skill leaf count (for the report).
    $subSkillsDir = Join-Path $sourceDir 'sub-skills'
    if (Test-Path -LiteralPath $subSkillsDir -PathType Container) {
        $result.subSkillsNested = @(Get-ChildItem -LiteralPath $subSkillsDir -Directory -ErrorAction SilentlyContinue).Count
    }

    # File count across the nested members + commands (for the report).
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
    $commandFiles = @()
    if ($hasCommands) {
        $commandFiles = @(Get-ChildItem -LiteralPath (Join-Path $sourceDir 'commands') -File -Filter '*.md' -ErrorAction SilentlyContinue)
    }
    $result.commandCount = $commandFiles.Count
    $result.fileCount = $files.Count + $commandFiles.Count

    # --- Write (only under -Force and ShouldProcess) -----------------------
    $doWrite = $Force -and $PSCmdlet.ShouldProcess($destDir, "push bundle '$Name' ($($result.fileCount) files)")
    if ($doWrite) {
        if (-not (Test-Path -LiteralPath $skillsRoot)) {
            New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null
        }
        # Back up an existing destination before replacing it - never clobber silently.
        # The backup MUST live outside the profile skills root: a `<Name>.bak-<ts>` dir
        # left beside the bundle is itself scanned as a skill and loads as a duplicate
        # shadow of the one just deployed. Use a sibling `<root>-backups/` directory.
        if (Test-Path -LiteralPath $destDir) {
            $stamp = (Get-Date).ToString('yyyyMMddHHmmss')
            $backupRoot = Join-Path (Split-Path -Parent $skillsRoot) ((Split-Path -Leaf $skillsRoot) + '-backups')
            if (-not (Test-Path -LiteralPath $backupRoot)) {
                New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
            }
            $backup = Join-Path $backupRoot "$Name.bak-$stamp"
            Move-Item -LiteralPath $destDir -Destination $backup
            $result.backedUpTo = $backup
        }
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null

        # Copy the parent SKILL.md + nested member dirs.
        Copy-Item -LiteralPath $sourceSkillMd -Destination (Join-Path $destDir $MemberFile) -Force
        foreach ($d in $MemberDirs) {
            $src = Join-Path $sourceDir $d
            if (Test-Path -LiteralPath $src -PathType Container) {
                Copy-Item -LiteralPath $src -Destination $destDir -Recurse -Force
            }
        }

        # Stamp provenance into EVERY copied SKILL.md (parent + each nested sub-skill).
        foreach ($md in Get-ChildItem -LiteralPath $destDir -Recurse -File -Filter 'SKILL.md' -ErrorAction SilentlyContinue) {
            if (Add-Provenance $md.FullName) { $result.stampedCount++ }
        }

        # Relocate companion commands to the profile's top-level commands/ dir.
        if ($hasCommands -and $commandFiles.Count -gt 0) {
            if (-not (Test-Path -LiteralPath $commandsRoot)) {
                New-Item -ItemType Directory -Path $commandsRoot -Force | Out-Null
            }
            foreach ($c in $commandFiles) {
                Copy-Item -LiteralPath $c.FullName -Destination (Join-Path $commandsRoot $c.Name) -Force
            }
        }

        $result.wouldWrite = $false
        $result.message = "Pushed '$Name' ($($result.fileCount) files: $($result.stampedCount) stamped SKILL.md, $($result.subSkillsNested) sub-skills nested, $($result.commandCount) commands) to $destDir." +
            $(if ($result.backedUpTo) { " Previous copy backed up to $($result.backedUpTo)." } else { '' })
    }
    else {
        $result.wouldWrite = $true
        $reason = if (-not $Force) { 'preview (pass -Force to write)' } else { 'preview (-WhatIf)' }
        $result.message = "Would push '$Name' ($($result.fileCount) files) to $destDir - $reason."
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
        if (@($result.members).Count -gt 0) {
            Write-Host ("  members: {0}" -f (@($result.members) -join ', '))
        }
        if ($result.commandCount -gt 0 -and -not $result.wouldWrite) {
            Write-Host ("  commands -> {0}" -f $result.commandsDest)
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
