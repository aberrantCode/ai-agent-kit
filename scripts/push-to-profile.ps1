#Requires -Version 7.0

<#
.SYNOPSIS
    Push a skill bundle from the ai-agent-kit archive to a global vendor profile.

.DESCRIPTION
    Deploys a named skill bundle from <Vendor>/skills/<Name> to the vendor's global
    profile, mirroring the archive layout:

        ~/.<vendor>/skills/<Name>/SKILL.md          (parent skill)
        ~/.<vendor>/skills/<Name>/sub-skills/**      (NESTED — see below)
        ~/.<vendor>/skills/<Name>/<every other member>/**  (references, rules, scripts,
                                                     assets, templates, root files, ...;
                                                     only diagram.html is left behind)
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

    STALE COMMANDS. Each push records the commands it deployed, with a SHA-256 of each,
    in `<bundle>/.deployed-commands.json`. On the next push, a recorded command the
    bundle no longer ships is removed from `~/.<vendor>/commands/` (moved into the
    bundle's backup under `removed-commands/`), so dropped or renamed commands do not
    pile up in the profile. A stale command whose file no longer matches the recorded
    hash (edited locally, or since overwritten by another bundle's command of the same
    name) is kept and reported instead. An install with no record (deployed before
    this existed) gets one on its next push; nothing is removed on that push.

    PROVENANCE. Every copied SKILL.md — the parent and each nested sub-skill — is stamped
    `installed-from: ai-agent-kit` so /audit-skills, /find-skills, /sync-skill, and
    sync-installed.ps1 recognize the copy as an archive deployment (a downstream target,
    like /install-skill writing into a project) rather than a hand-authored profile
    source. Commands, references, rules, and scripts are copied verbatim (not stamped).

    `status: draft` bundles are skipped — drafts are not pushed to a global profile.

    DEPENDENCIES. Every skill named in the bundle's `requires:` frontmatter (inline
    `[a, b]` or block `- a`) is pushed too, transitively and dependencies first, by
    re-invoking this script per dependency with -NoDeps. Without this, pushing a bundle
    whose scripts call a newer sibling (session-manager's dispatch launcher calling
    spawn-terminal.ps1 with a new parameter) left the stale sibling in place. A
    dependency missing from the archive is a validation failure and nothing is written;
    a dependency push that fails aborts before the requested bundle is written. -NoDeps
    pushes the named bundle alone (bootstrap-profile.ps1 passes it, having already
    expanded `requires:` itself).

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

.PARAMETER NoDeps
    Push only the named bundle; do not push the skills in its `requires:` frontmatter.

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
    commands relocated; stale commands removed (or kept because they were edited); and
    any backup taken.

.NOTES
    Exit codes:
      0 = success — bundle pushed, preview completed, or draft skipped
      1 = validation failure — -Name missing/invalid/not found, a `requires:`
          dependency is not in the archive, or a path fails the containment check
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

    [switch]$NoDeps,

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

# Same frontmatter parsing as bootstrap-profile.ps1.
function Split-Frontmatter {
    param([string]$Path)
    $text = [System.IO.File]::ReadAllText($Path) -replace "`r`n", "`n"
    $m = [regex]::Match($text, '(?s)\A---\n(.*?)\n---\n?(.*)\z')
    if (-not $m.Success) { return @{ fm = ''; body = $text } }
    return @{ fm = $m.Groups[1].Value; body = $m.Groups[2].Value }
}

# Parse a frontmatter list field — inline (`[a, b]`) or block (`- a`).
function Get-FmList {
    param([string]$Frontmatter, [string]$Field)
    $inline = [regex]::Match($Frontmatter, "(?m)^${Field}:[ \t]*\[(.*?)\]")
    if ($inline.Success) {
        return @($inline.Groups[1].Value -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ })
    }
    $block = [regex]::Match($Frontmatter, "(?m)^${Field}:[ \t]*\n((?:[ \t]+-[ \t]*.+\n?)+)")
    if ($block.Success) {
        return @($block.Groups[1].Value -split '\n' | ForEach-Object { ($_ -replace '^\s*-\s*', '').Trim().Trim('"', "'") } | Where-Object { $_ })
    }
    return @()
}

# Every top-level entry of the bundle is copied NESTED into the deployed bundle (dirs
# recursively), so a skill's own sub-skills/, references/, assets/, templates/, ... and
# root files (e.g. an .env.example it points at) all ship. Two exclusions: `commands`
# is relocated to the profile's top-level commands/ dir (see below), and diagram.html is
# an archive-only visual, never read at runtime.
$MemberFile = 'SKILL.md'
$ExcludedMembers = @('commands', 'diagram.html')

# Written into the deployed bundle: the commands this push relocated, name -> SHA-256.
$CommandRecord = '.deployed-commands.json'

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
    commandsRemoved = @()
    commandsKept  = @()
    wouldWrite    = (-not $Force)
    skippedDraft  = $false
    backedUpTo    = $null
    dependencies  = @()
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

    # --- Dependencies (requires:) — expand transitively, push first --------
    if (-not $NoDeps) {
        $deps     = [System.Collections.Generic.List[string]]::new()
        $missing  = [System.Collections.Generic.List[string]]::new()
        $visiting = @{ $Name = $true }
        function Add-WithDeps([string]$skill) {
            if ($deps.Contains($skill) -or $missing.Contains($skill) -or $visiting.ContainsKey($skill)) { return }
            $md = Join-Path $skillsArchive (Join-Path $skill $MemberFile)
            if ($skill -notmatch '^[A-Za-z0-9._-]+$' -or $skill -match '\.\.' -or -not (Test-Path -LiteralPath $md -PathType Leaf)) {
                $missing.Add($skill); return
            }
            $visiting[$skill] = $true
            foreach ($dep in (Get-FmList (Split-Frontmatter $md).fm 'requires')) { Add-WithDeps $dep }
            $visiting.Remove($skill)
            $deps.Add($skill)
        }
        foreach ($dep in (Get-FmList (Split-Frontmatter $sourceSkillMd).fm 'requires')) { Add-WithDeps $dep }
        if ($missing.Count -gt 0) {
            throw "::VALIDATION:: '$Name' requires skill(s) not found under $Vendor/skills/: $($missing -join ', ')."
        }

        $pwshExe = (Get-Process -Id $PID).Path
        foreach ($dep in $deps) {
            $depArgs = @('-NoProfile', '-File', $PSCommandPath, '-Name', $dep, '-Vendor', $Vendor, '-TargetDir', $skillsRoot, '-NoDeps', '-Json')
            if ($Force) { $depArgs += '-Force' }
            if ($WhatIfPreference) { $depArgs += '-WhatIf' }
            $out  = & $pwshExe @depArgs 2>&1 | Out-String
            $code = $LASTEXITCODE
            try { $msg = ($out | ConvertFrom-Json).message } catch { $msg = $out.Trim() }
            $result.dependencies += [ordered]@{ name = $dep; exitCode = $code; message = $msg }
            if ($code -ne 0) {
                throw "::EXEC:: dependency '$dep' failed to push (exit $code): $msg '$Name' was not written."
            }
        }
    }

    # --- Enumerate the members that are present ----------------------------
    $memberItems = @(Get-ChildItem -LiteralPath $sourceDir -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne $MemberFile -and $ExcludedMembers -notcontains $_.Name } |
        Sort-Object -Property Name -Culture ([cultureinfo]::InvariantCulture))
    $present = [System.Collections.Generic.List[string]]::new()
    $present.Add($MemberFile)
    foreach ($m in $memberItems) { $present.Add($m.Name) }
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
    foreach ($m in $memberItems) {
        if ($m.PSIsContainer) {
            foreach ($f in Get-ChildItem -LiteralPath $m.FullName -Recurse -File -Force -ErrorAction SilentlyContinue) {
                $files.Add($f.FullName)
            }
        } else {
            $files.Add($m.FullName)
        }
    }
    $commandFiles = @()
    if ($hasCommands) {
        $commandFiles = @(Get-ChildItem -LiteralPath (Join-Path $sourceDir 'commands') -File -Filter '*.md' -ErrorAction SilentlyContinue)
    }
    $result.commandCount = $commandFiles.Count
    $result.fileCount = $files.Count + $commandFiles.Count

    # --- Stale commands: recorded by the previous push, no longer shipped ----
    # Only a command whose file still matches the recorded hash is ours to remove.
    $staleCommands = [System.Collections.Generic.List[string]]::new()
    $recordPath = Join-Path $destDir $CommandRecord
    if (Test-Path -LiteralPath $recordPath -PathType Leaf) {
        $previous = (Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json).commands
        $shipped  = @($commandFiles | ForEach-Object { $_.Name })
        foreach ($prop in @($previous.PSObject.Properties | Sort-Object Name -Culture ([cultureinfo]::InvariantCulture))) {
            $cmdName = $prop.Name
            if ($shipped -contains $cmdName -or $cmdName -notmatch '^[A-Za-z0-9._-]+\.md$') { continue }
            $cmdPath = Join-Path $commandsRoot $cmdName
            if (-not (Test-Path -LiteralPath $cmdPath -PathType Leaf)) { continue }
            if ((Get-FileHash -LiteralPath $cmdPath -Algorithm SHA256).Hash -eq $prop.Value) {
                $staleCommands.Add($cmdName)
            } else {
                $result.commandsKept += $cmdName
            }
        }
    }
    $result.commandsRemoved = @($staleCommands)

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

        # Copy the parent SKILL.md + every other member (dirs recursively).
        Copy-Item -LiteralPath $sourceSkillMd -Destination (Join-Path $destDir $MemberFile) -Force
        foreach ($m in $memberItems) {
            Copy-Item -LiteralPath $m.FullName -Destination $destDir -Recurse -Force
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

        # Remove stale commands into the backup (a record implies one was taken).
        if ($staleCommands.Count -gt 0) {
            $removedDir = Join-Path $result.backedUpTo 'removed-commands'
            New-Item -ItemType Directory -Path $removedDir -Force | Out-Null
            foreach ($cmdName in $staleCommands) {
                Move-Item -LiteralPath (Join-Path $commandsRoot $cmdName) -Destination (Join-Path $removedDir $cmdName) -Force
            }
        }

        # Record what this push deployed, for the next push's stale check.
        $record = [ordered]@{}
        foreach ($c in ($commandFiles | Sort-Object Name -Culture ([cultureinfo]::InvariantCulture))) {
            $record[$c.Name] = (Get-FileHash -LiteralPath (Join-Path $commandsRoot $c.Name) -Algorithm SHA256).Hash
        }
        Write-Utf8NoBom (Join-Path $destDir $CommandRecord) (([ordered]@{ commands = $record } | ConvertTo-Json -Depth 3) + "`n")

        $result.wouldWrite = $false
        $result.message = "Pushed '$Name' ($($result.fileCount) files: $($result.stampedCount) stamped SKILL.md, $($result.subSkillsNested) sub-skills nested, $($result.commandCount) commands) to $destDir." +
            $(if ($result.backedUpTo) { " Previous copy backed up to $($result.backedUpTo)." } else { '' }) +
            $(if ($staleCommands.Count -gt 0) { " Removed $($staleCommands.Count) stale command(s): $($staleCommands -join ', ')." } else { '' }) +
            $(if (@($result.commandsKept).Count -gt 0) { " Kept edited stale command(s): $(@($result.commandsKept) -join ', ')." } else { '' })
    }
    else {
        $result.wouldWrite = $true
        $reason = if (-not $Force) { 'preview (pass -Force to write)' } else { 'preview (-WhatIf)' }
        $result.message = "Would push '$Name' ($($result.fileCount) files) to $destDir - $reason." +
            $(if ($staleCommands.Count -gt 0) { " Would remove $($staleCommands.Count) stale command(s): $($staleCommands -join ', ')." } else { '' }) +
            $(if (@($result.commandsKept).Count -gt 0) { " Would keep edited stale command(s): $(@($result.commandsKept) -join ', ')." } else { '' })
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
    foreach ($d in $result.dependencies) {
        Write-Host ("dependency {0}: {1}" -f $d.name, $d.message)
    }
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
