#Requires -Version 7.0

<#
.SYNOPSIS
    Push a skill bundle from the ai-agent-kit archive to a global vendor profile.

.DESCRIPTION
    Deploys a named skill bundle (SKILL.md + sub-skills/ + references/ + rules/ +
    diagram.html, whichever are present) from <RepoRoot>/<Vendor>/skills/<Name> to the
    vendor's global profile — e.g. ~/.claude/skills/<Name>/ for Claude — and its
    companion commands to the profile's commands/ directory. Each SKILL.md (the parent
    plus every nested sub-skill) is stamped with `installed-from: ai-agent-kit`
    provenance so `/find-skills` and `/sync-skill` recognize the copy as archive-managed
    rather than a hand-authored profile source.

    LAYOUT — nested, mirroring the archive (skills-manager /push-skill, corrected
    2026-07-27). The parent skill and its companion commands are the only top-level
    entry points; sub-skills stay INSIDE the bundle at
    ~/.claude/skills/<Name>/sub-skills/<sub>/ and are reached through the parent's
    relative `sub-skills/<sub>` path. This script NEVER writes a sub-skill to a loose
    top-level ~/.claude/skills/<sub>/ directory — that shadows the bundle's own
    sub-skill (audit.ps1 Check 8, `profile-shadowing`) and breaks the parent's
    delegation.

    Shared conventions (docs/requirements/canonical-repo.md §6, binding for every
    lifecycle script):
      - Parameters: common surface is -Name, -TargetDir, -Force, -WhatIf, -Json.
        This script never repurposes their meaning. -TargetDir overrides the vendor
        profile ROOT default (the ~/.<vendor> equivalent); when omitted the profile
        root resolves to the platform home directory joined with .<vendor>. -Vendor is
        an added specific (claude|codex|gemini) selecting both the archive tree and the
        default profile root.
      - Safety: default behavior is preview-only; -Force is required to actually write
        files. Before overwriting an existing profile bundle (or command file) the
        current copy is backed up under <ProfileRoot>/.aak-backups/<Name>-<stamp>/ —
        never a silent clobber. Resolved source and destination paths are canonicalized
        and containment-checked against the archive root and the profile root before any
        write; a crafted -Name is rejected.
      - Portability: no Windows-only APIs (home-directory resolution prefers
        $env:USERPROFILE then $HOME); file output uses utf8NoBOM; enumeration used for
        output is ordinal (culture-invariant) sorted.

.PARAMETER Name
    Name of the skill bundle to push, matching its directory under <Vendor>/skills/.

.PARAMETER Vendor
    Which archive tree and default profile the bundle belongs to: claude (default),
    codex, or gemini. Selects source <Vendor>/skills/<Name> and default profile root
    ~/.<Vendor>.

.PARAMETER TargetDir
    Destination profile ROOT (the ~/.<vendor> equivalent). Skills land under
    <TargetDir>/skills/<Name>/ and commands under <TargetDir>/commands/. Defaults to the
    platform-appropriate global profile root for the vendor when omitted.

.PARAMETER RepoRoot
    Archive root. Defaults to the parent of this script's directory.

.PARAMETER Force
    Required to actually write files. Without it, the script only reports what would be
    copied (preview/report-only default per the shared safety convention).

.PARAMETER WhatIf
    Standard PowerShell ShouldProcess preview — reports the plan without writing, even
    when -Force is also supplied.

.PARAMETER Json
    Emit machine-readable JSON output instead of a console-formatted report.

.OUTPUTS
    Console report (default) or JSON object (-Json) describing the bundle members that
    were, or would be, copied; the sub-skills nested; the companion commands relocated;
    the provenance stamp applied; any strays skipped; and any backups taken.

.NOTES
    Exit codes:
      0 = success — bundle pushed, previewed, or skipped as a draft
      1 = validation failure — -Name missing/invalid, bundle not found, path fails the
          containment check
      2 = execution error — unexpected exception (I/O failure, malformed SKILL.md
          frontmatter that cannot be stamped, etc.)

    Absorbs the skills-manager /push-skill operation
    (.claude/commands/push-skill.md → skills-manager).

.EXAMPLE
    ./scripts/push-to-profile.ps1 -Name github
    Preview what pushing the github bundle to ~/.claude would write.

.EXAMPLE
    ./scripts/push-to-profile.ps1 -Name github -Force
    Push the github bundle to ~/.claude/skills/github (+ commands), backing up any
    existing copy first.

.EXAMPLE
    ./scripts/push-to-profile.ps1 -Name project-manager -Force -Json
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Name = '',

    [ValidateSet('claude', 'codex', 'gemini')]
    [string]$Vendor = 'claude',

    [string]$TargetDir = '',

    [string]$RepoRoot = '',

    [switch]$Force,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Culture-invariant home directory (no Windows-only assumption).
function Get-HomeDir {
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    if ($HOME) { return $HOME }
    throw 'Could not resolve a home directory ($env:USERPROFILE and $HOME are both empty).'
}

# Ordinal (culture-invariant) sort for deterministic output.
function Sort-Ordinal {
    param([string[]]$Items)
    $arr = @($Items)
    [Array]::Sort($arr, [System.StringComparer]::Ordinal)
    return , $arr   # comma keeps an empty array from collapsing to $null on return
}

# True when $Child is $Parent or lives beneath it, after canonicalization.
function Test-Contained {
    param([string]$Parent, [string]$Child)
    $p = [System.IO.Path]::GetFullPath($Parent).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $c = [System.IO.Path]::GetFullPath($Child).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    if ($c -eq $p) { return $true }
    return $c.StartsWith($p + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::Ordinal)
}

# Write text as UTF-8 without BOM, LF line endings, creating parent dirs.
function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

# Insert `installed-from: ai-agent-kit` into a SKILL.md's YAML frontmatter, just before
# the closing `---` (after existing fields). Idempotent. Throws if the file has no
# terminated frontmatter block — a malformed SKILL.md is an execution error (exit 2).
function Add-Provenance {
    param([string]$Content)

    $lines = $Content -split "`r?`n"
    if ($lines.Count -lt 2 -or $lines[0].Trim() -ne '---') {
        throw 'SKILL.md has no YAML frontmatter block (first line is not "---").'
    }

    $close = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { $close = $i; break }
    }
    if ($close -lt 0) {
        throw 'SKILL.md frontmatter block is not terminated by a closing "---".'
    }

    for ($i = 1; $i -lt $close; $i++) {
        if ($lines[$i] -match '^\s*installed-from\s*:') { return $Content }  # already stamped
    }

    $head = $lines[0..($close - 1)]
    $tail = $lines[$close..($lines.Count - 1)]
    return (($head + 'installed-from: ai-agent-kit' + $tail) -join "`n")
}

# Read the `status:` frontmatter value (lowercased), or '' if absent/unparseable.
function Get-StatusField {
    param([string]$Content)
    $lines = $Content -split "`r?`n"
    if ($lines.Count -lt 2 -or $lines[0].Trim() -ne '---') { return '' }
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { break }
        if ($lines[$i] -match '^\s*status\s*:\s*(\S+)') { return $Matches[1].ToLowerInvariant() }
    }
    return ''
}

# ---------------------------------------------------------------------------
# Result scaffold
# ---------------------------------------------------------------------------
$result = [ordered]@{
    name            = $Name
    vendor          = $Vendor
    mode            = 'preview'          # preview | applied | skipped-draft
    sourceBundle    = $null
    profileRoot     = $null
    skillsDest      = $null
    commandsDest    = $null
    subSkillsNested = 0
    planned         = @()               # { kind; source; dest; stamped; overwrite }
    strays          = @()               # bundle-root entries that are not bundle members
    backups         = @()
    written         = @()
    warnings        = @()
    errors          = @()
    exitCode        = 0
}

function Complete-Run {
    param([int]$Code)
    $result.exitCode = $Code
    $obj = [pscustomobject]$result
    if ($Json) {
        $obj | ConvertTo-Json -Depth 8
    }
    else {
        Write-Host ''
        Write-Host "push-to-profile: $($result.name) ($($result.vendor)) -> $($result.mode)"
        if ($result.profileRoot) { Write-Host "  profile root : $($result.profileRoot)" }
        if ($result.skillsDest)  { Write-Host "  bundle dest  : $($result.skillsDest)" }
        if ($result.mode -eq 'skipped-draft') {
            Write-Host '  draft skill — not pushed (change status to push).'
        }
        else {
            $verb = if ($result.mode -eq 'applied') { 'wrote' } else { 'would write' }
            $skillMd = @($result.planned | Where-Object { $_.stamped }).Count
            Write-Host "  $verb $(@($result.planned).Count) file(s): $skillMd stamped SKILL.md, $($result.subSkillsNested) sub-skill(s) nested"
            $cmds = @($result.planned | Where-Object { $_.kind -eq 'command' }).Count
            if ($cmds) { Write-Host "  companion commands -> $($result.commandsDest) ($cmds)" }
            if (@($result.backups).Count) { Write-Host "  backed up $(@($result.backups).Count) existing item(s) under .aak-backups/" }
            if (@($result.strays).Count)  { Write-Host "  skipped strays (not bundle members): $(@($result.strays) -join ', ')" }
        }
        foreach ($w in $result.warnings) { Write-Host "  warn: $w" -ForegroundColor Yellow }
        foreach ($e in $result.errors)   { Write-Host "  error: $e" -ForegroundColor Red }
        Write-Host ''
    }
    exit $Code
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
$apply = $Force.IsPresent -and -not $WhatIfPreference
if ($apply) { $result.mode = 'applied' }

try {
    # --- Validate -Name (reject traversal / separators) -----------------------
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $result.errors += 'Name is required (the skill bundle to push).'
        Complete-Run 1
    }
    if ($Name -notmatch '^[A-Za-z0-9._-]+$' -or $Name -match '\.\.') {
        $result.errors += "Invalid -Name '$Name' (allowed: letters, digits, dot, underscore, hyphen; no path separators or '..')."
        Complete-Run 1
    }

    # --- Resolve archive root + source bundle ---------------------------------
    if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

    $archiveSkills = [System.IO.Path]::Combine($RepoRoot, $Vendor, 'skills')
    if (-not (Test-Path -LiteralPath $archiveSkills)) {
        $result.errors += "Archive skills tree not found for vendor '$Vendor': $archiveSkills"
        Complete-Run 1
    }

    $sourceBundle = [System.IO.Path]::Combine($archiveSkills, $Name)
    $sourceSkillMd = [System.IO.Path]::Combine($sourceBundle, 'SKILL.md')
    if (-not (Test-Path -LiteralPath $sourceSkillMd)) {
        $result.errors += "Skill '$Name' not found in archive: $sourceSkillMd"
        Complete-Run 1
    }
    if (-not (Test-Contained -Parent $archiveSkills -Child $sourceBundle)) {
        $result.errors += "Source path escapes the archive skills root: $sourceBundle"
        Complete-Run 1
    }
    $result.sourceBundle = $sourceBundle

    # --- Resolve profile root, skills root, commands root ---------------------
    if ($TargetDir) {
        $profileRoot = [System.IO.Path]::GetFullPath($TargetDir)
    }
    else {
        $profileRoot = [System.IO.Path]::Combine((Get-HomeDir), ".$Vendor")
    }
    $skillsRoot   = [System.IO.Path]::Combine($profileRoot, 'skills')
    $commandsRoot = [System.IO.Path]::Combine($profileRoot, 'commands')
    $destBundle   = [System.IO.Path]::Combine($skillsRoot, $Name)

    if (-not (Test-Contained -Parent $profileRoot -Child $destBundle)) {
        $result.errors += "Destination bundle escapes the profile root: $destBundle"
        Complete-Run 1
    }
    $result.profileRoot = $profileRoot
    $result.skillsDest  = $destBundle
    $result.commandsDest = $commandsRoot

    # --- Draft gate (drafts are not pushed to a global profile) ---------------
    $skillContent = [System.IO.File]::ReadAllText($sourceSkillMd)
    if ((Get-StatusField $skillContent) -eq 'draft') {
        $result.mode = 'skipped-draft'
        $result.warnings += "Skill '$Name' has status: draft — skipped (drafts are not pushed to the global profile)."
        Complete-Run 0
    }

    # --- Build the planned write set (nested layout) --------------------------
    $plan = [System.Collections.Generic.List[object]]::new()

    function Add-Plan {
        param([string]$Kind, [string]$Source, [string]$Dest, [bool]$Stamped)
        $plan.Add([ordered]@{
            kind      = $Kind
            source    = $Source
            dest      = $Dest
            stamped   = $Stamped
            overwrite = (Test-Path -LiteralPath $Dest)
        })
    }

    # Parent SKILL.md (stamped).
    Add-Plan 'skill' $sourceSkillMd ([System.IO.Path]::Combine($destBundle, 'SKILL.md')) $true

    # diagram.html (optional, kept so the SKILL.md's [View diagram] link resolves).
    $diagram = [System.IO.Path]::Combine($sourceBundle, 'diagram.html')
    if (Test-Path -LiteralPath $diagram) {
        Add-Plan 'diagram' $diagram ([System.IO.Path]::Combine($destBundle, 'diagram.html')) $false
    }

    # Nested member trees: sub-skills/, references/, rules/ (relative paths preserved).
    foreach ($member in 'sub-skills', 'references', 'rules') {
        $memberDir = [System.IO.Path]::Combine($sourceBundle, $member)
        if (-not (Test-Path -LiteralPath $memberDir)) { continue }

        $files = @(Get-ChildItem -LiteralPath $memberDir -Recurse -File -ErrorAction Stop)
        $ordered = $files | Sort-Object { $_.FullName } -Culture ([System.Globalization.CultureInfo]::InvariantCulture)
        foreach ($f in $ordered) {
            $rel = [System.IO.Path]::GetRelativePath($sourceBundle, $f.FullName)
            $dest = [System.IO.Path]::Combine($destBundle, $rel)
            # Only a sub-skill's own SKILL.md carries the provenance stamp.
            $stamp = ($member -eq 'sub-skills' -and $f.Name -eq 'SKILL.md')
            $kind = if ($member -eq 'sub-skills' -and $f.Name -eq 'SKILL.md') { 'subskill' } else { $member }
            Add-Plan $kind $f.FullName $dest $stamp
        }

        if ($member -eq 'sub-skills') {
            $result.subSkillsNested = @(Get-ChildItem -LiteralPath $memberDir -Directory -ErrorAction SilentlyContinue).Count
        }
    }

    # Companion commands -> profile commands root (NOT nested, NOT stamped).
    $commandsDir = [System.IO.Path]::Combine($sourceBundle, 'commands')
    if (Test-Path -LiteralPath $commandsDir) {
        $cmdFiles = @(Get-ChildItem -LiteralPath $commandsDir -File -Filter '*.md' -ErrorAction Stop)
        $orderedCmd = $cmdFiles | Sort-Object { $_.Name } -Culture ([System.Globalization.CultureInfo]::InvariantCulture)
        foreach ($c in $orderedCmd) {
            Add-Plan 'command' $c.FullName ([System.IO.Path]::Combine($commandsRoot, $c.Name)) $false
        }
    }

    # Strays: bundle-root entries that are not recognized bundle members.
    $members = @('SKILL.md', 'diagram.html', 'sub-skills', 'references', 'rules', 'commands')
    $strayNames = @(
        Get-ChildItem -LiteralPath $sourceBundle -Force -ErrorAction Stop |
        Where-Object { $members -notcontains $_.Name } |
        ForEach-Object { $_.Name }
    )
    $result.strays = Sort-Ordinal $strayNames

    $result.planned = $plan.ToArray()

    # --- Preview mode: report the plan, write nothing -------------------------
    if (-not $apply) {
        if (@($result.strays).Count) {
            $result.warnings += "Ignoring non-member bundle-root entries: $(@($result.strays) -join ', ')"
        }
        Complete-Run 0
    }

    # --- Apply mode: back up, then write --------------------------------------
    $stamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss', [System.Globalization.CultureInfo]::InvariantCulture)
    $backupRoot = [System.IO.Path]::Combine($profileRoot, '.aak-backups', "$Name-$stamp")

    # Back up an existing bundle dir wholesale.
    if (Test-Path -LiteralPath $destBundle) {
        $bak = [System.IO.Path]::Combine($backupRoot, 'skills', $Name)
        New-Item -ItemType Directory -Path (Split-Path -Parent $bak) -Force | Out-Null
        Copy-Item -LiteralPath $destBundle -Destination $bak -Recurse -Force
        $result.backups += $bak
    }
    # Back up any command files that will be overwritten.
    foreach ($item in ($plan | Where-Object { $_.kind -eq 'command' -and $_.overwrite })) {
        $bak = [System.IO.Path]::Combine($backupRoot, 'commands', (Split-Path -Leaf $item.dest))
        New-Item -ItemType Directory -Path (Split-Path -Parent $bak) -Force | Out-Null
        Copy-Item -LiteralPath $item.dest -Destination $bak -Force
        $result.backups += $bak
    }

    # Replace the bundle dir cleanly (backed up above), then write the plan.
    if (Test-Path -LiteralPath $destBundle) {
        Remove-Item -LiteralPath $destBundle -Recurse -Force
    }

    foreach ($item in $plan) {
        if ($item.stamped) {
            $raw = [System.IO.File]::ReadAllText($item.source)
            $stamped = Add-Provenance $raw
            Write-Utf8NoBom -Path $item.dest -Content $stamped
        }
        else {
            $destDir = Split-Path -Parent $item.dest
            if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $item.source -Destination $item.dest -Force
        }
        $result.written += $item.dest
    }

    if (@($result.strays).Count) {
        $result.warnings += "Ignored non-member bundle-root entries: $(@($result.strays) -join ', ')"
    }

    Complete-Run 0
}
catch {
    $result.errors += $_.Exception.Message
    Complete-Run 2
}
