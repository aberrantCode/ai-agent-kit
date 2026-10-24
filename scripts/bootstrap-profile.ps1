#Requires -Version 7.0

<#
.SYNOPSIS
    Bootstrap a user profile from a local ai-agent-kit clone: standard skills, the status
    line, and default global CLAUDE.md / AGENTS.md / GEMINI.md.

.DESCRIPTION
    One non-interactive pass that gives a fresh (or drifted) profile the archive's
    standard setup. Three phases, each reported separately:

      1. SKILLS — manifest.json `standard_skills` (source: STANDARD_SKILLS in
         scripts/generate-manifest.py), expanded with each skill's `requires:`
         dependencies (transitively) and deployed dependencies-first. Every bundle is
         deployed by push-to-profile.ps1 — this script never copies bundle files itself —
         so provenance stamping, sub-skill nesting, companion-command relocation, backups,
         and draft gating all apply unchanged.

      2. STATUS LINE (claude only) — deploys the statusline bundle's
         assets/statusline.sh to ~/.claude/statusline.sh and wires `statusLine` into
         ~/.claude/settings.json (other keys preserved, settings.json backed up first).
         A status line the user already configured to some other command is left alone.
         Missing prerequisites are installed with winget (Windows; -SkipPrereqInstall
         opts out): jq via jqlang.jq, bash and git via Git.Git (one package). The WSL
         `bash` launcher in System32/WindowsApps does not count as bash.

      3. INSTRUCTIONS — writes the default global instructions file for each CLI:
         ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md, ~/.gemini/GEMINI.md, built from
         manifest.json `standard_guardrails` (shared/guardrails/<name>.md bodies, filtered
         by each guardrail's `applies-to`). A file that already exists is SKIPPED, never
         overwritten — it belongs to the user from then on.

    This script runs from a LOCAL CLONE of the archive. When no clone exists yet, see
    "Bootstrap a new profile" in README.md (clone, or download and extract the archive
    zip, then run this script from it).

    Shared conventions (docs/requirements/canonical-repo.md section 6):
      - Parameters: -Name, -TargetDir, -Force, -Json keep their common meaning. -Name
        here accepts a LIST of bundles that replaces the standard set.
      - Safety: preview-only by default; -Force is required to write. Bundle backups and
        path containment are enforced by push-to-profile.ps1; settings.json is backed up
        before it is changed; instruction files are never overwritten.
      - Portability: no Windows-only APIs; utf8NoBOM + LF output; ordinal sorting.

.PARAMETER Name
    Bundles to deploy instead of the manifest's standard set. Dependencies declared in
    `requires:` are still added.

.PARAMETER Vendor
    Skill tree and profile for phase 1: claude (default), codex, or gemini. A standard
    skill with no mirror for the vendor is reported and skipped. Phase 2 runs only for
    claude.

.PARAMETER TargetDir
    Skills root for phase 1. Defaults to <ProfileHome>/.<vendor>/skills.

.PARAMETER ProfileHome
    Home directory whose .claude/.codex/.gemini profiles are written. Defaults to the
    current user's home. Point it at a scratch directory to rehearse a bootstrap.

.PARAMETER InstructionVendors
    Which CLIs get a default instructions file in phase 3. Default: claude, codex, gemini.

.PARAMETER SkipStatusline
    Skip phase 2.

.PARAMETER SkipInstructions
    Skip phase 3.

.PARAMETER SkipPrereqInstall
    Do not install missing prerequisites (jq, bash, git) with winget — only warn. Use it when rehearsing
    with -ProfileHome, since a package install is machine-wide, not per-profile.

.PARAMETER Pull
    Fast-forward the clone (`git pull --ff-only`) before deploying. Skipped with a
    warning when the working tree is dirty or the clone is not a git checkout.

.PARAMETER Force
    Required to actually write. Without it every phase is previewed only.

.PARAMETER Json
    Emit a machine-readable JSON report instead of the console summary.

.EXAMPLE
    pwsh ./scripts/bootstrap-profile.ps1
    Preview the full bootstrap of the current user's profile.

.EXAMPLE
    pwsh ./scripts/bootstrap-profile.ps1 -Pull -Force
    Update the clone, then bootstrap the current user's profile.

.OUTPUTS
    Console summary (default) or JSON:
    { vendor, force, pulled, skills[], missing[], results[], exitCode }.

.NOTES
    Exit codes: 0 every step done/previewed/skipped by design; 1 a requested bundle or
    guardrail is missing, or push-to-profile reported a validation failure; 2 execution
    error. Prerequisite warnings (e.g. jq missing) do not change the exit code.
#>

[CmdletBinding()]
param(
    [string[]]$Name = @(),

    [ValidateSet('claude', 'codex', 'gemini')]
    [string]$Vendor = 'claude',

    [string]$TargetDir = '',

    [string]$ProfileHome = '',

    [ValidateSet('claude', 'codex', 'gemini')]
    [string[]]$InstructionVendors = @('claude', 'codex', 'gemini'),

    [switch]$SkipStatusline,

    [switch]$SkipInstructions,

    [switch]$SkipPrereqInstall,

    [switch]$Pull,

    [switch]$Force,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot    = Split-Path -Parent $PSScriptRoot
$PushScript  = Join-Path $PSScriptRoot 'push-to-profile.ps1'
$SkillsRoot  = Join-Path $RepoRoot (Join-Path $Vendor 'skills')
$DefaultHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$HomeDir     = if ($ProfileHome) { $ProfileHome } else { $DefaultHome }
$InstructionFile = @{ claude = 'CLAUDE.md'; codex = 'AGENTS.md'; gemini = 'GEMINI.md' }

function Write-Utf8Lf {
    param([string]$Path, [string]$Text)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
}

# `<path>.bak-<n>` with the first unused <n> — never overwrites an earlier backup.
function Backup-File {
    param([string]$Path)
    $n = 1
    while (Test-Path -LiteralPath "$Path.bak-$n") { $n++ }
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$n"
    return "$Path.bak-$n"
}

# Split a markdown file into frontmatter text and body.
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

$report = [ordered]@{
    vendor   = $Vendor
    force    = [bool]$Force
    pulled   = $null
    skills   = @()
    missing  = @()
    results  = @()
    exitCode = 0
}

function Add-Result {
    param([string]$Phase, [string]$Item, [string]$Status, [string]$Message, [int]$Code = 0)
    $report.results += [ordered]@{ phase = $Phase; name = $Item; status = $Status; exitCode = $Code; message = $Message }
    if ($Code -gt $report.exitCode) { $report.exitCode = $Code }
}

try {
    if (-not (Test-Path -LiteralPath $PushScript)) { throw "push-to-profile.ps1 not found at $PushScript" }
    if (-not (Test-Path -LiteralPath $HomeDir -PathType Container)) { throw "profile home not found: $HomeDir" }

    if ($Pull) {
        $isGit = (& git -C $RepoRoot rev-parse --is-inside-work-tree 2>$null) -eq 'true'
        if (-not $isGit) {
            Write-Warning 'Not a git checkout - skipping -Pull.'
            $report.pulled = 'skipped: not a git checkout'
        } elseif (& git -C $RepoRoot status --porcelain) {
            Write-Warning 'Working tree is dirty - skipping -Pull.'
            $report.pulled = 'skipped: dirty working tree'
        } else {
            & git -C $RepoRoot pull --ff-only --quiet
            if ($LASTEXITCODE -ne 0) { throw "git pull --ff-only failed in $RepoRoot" }
            $report.pulled = 'fast-forwarded'
        }
    }

    $manifest = Get-Content -LiteralPath (Join-Path $RepoRoot 'manifest.json') -Raw | ConvertFrom-Json

    # --- Phase 1: skills ----------------------------------------------------------
    # `pwsh -File ... -Name a,b` arrives as one string — split on commas either way.
    $requested = @($Name | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($requested.Count -eq 0) {
        $requested = @($manifest.standard_skills)
        if ($requested.Count -eq 0) { throw 'manifest.json has no standard_skills' }
    }

    # Expand requires: transitively; post-order so dependencies deploy first.
    $ordered  = [System.Collections.Generic.List[string]]::new()
    $missing  = [System.Collections.Generic.List[string]]::new()
    $visiting = @{}
    function Add-WithDeps([string]$skill) {
        if ($ordered.Contains($skill) -or $missing.Contains($skill) -or $visiting.ContainsKey($skill)) { return }
        if ($skill -notmatch '^[A-Za-z0-9._-]+$') { $missing.Add($skill); return }
        $md = Join-Path $SkillsRoot (Join-Path $skill 'SKILL.md')
        if (-not (Test-Path -LiteralPath $md)) { $missing.Add($skill); return }
        $visiting[$skill] = $true
        foreach ($dep in (Get-FmList (Split-Frontmatter $md).fm 'requires')) { Add-WithDeps $dep }
        $visiting.Remove($skill)
        $ordered.Add($skill)
    }
    foreach ($s in $requested) { Add-WithDeps $s }

    $report.skills  = @($ordered)
    $report.missing = @($missing)
    foreach ($m in $missing) { Add-Result 'skills' $m 'missing' "no $Vendor/skills/$m in the archive - skipped" 1 }

    $skillsTarget = if ($TargetDir) { $TargetDir } else { Join-Path $HomeDir (Join-Path ".$Vendor" 'skills') }
    foreach ($skill in $ordered) {
        $pushArgs = @('-NoProfile', '-File', $PushScript, '-Name', $skill, '-Vendor', $Vendor, '-TargetDir', $skillsTarget, '-NoDeps', '-Json')
        if ($Force) { $pushArgs += '-Force' }
        $out  = & pwsh @pushArgs 2>&1 | Out-String
        $code = $LASTEXITCODE
        try { $msg = ($out | ConvertFrom-Json).message } catch { $msg = $out.Trim() }
        $status = if ($code -ne 0) { 'failed' } elseif ($Force) { 'deployed' } else { 'preview' }
        Add-Result 'skills' $skill $status $msg $code
    }

    # --- Phase 2: status line (claude only) -------------------------------------
    if (-not $SkipStatusline -and $Vendor -eq 'claude') {
        $asset = Join-Path $RepoRoot 'claude/skills/statusline/assets/statusline.sh'
        if (-not (Test-Path -LiteralPath $asset)) {
            Add-Result 'statusline' 'statusline.sh' 'missing' "asset not found: $asset" 1
        } else {
            # Prerequisites, installed with winget when missing (Windows). bash and git both
            # come from Git for Windows, so they share one package. A fresh install lands on
            # PATH for new shells only, so each tool also has a known install location.
            $programFiles = [Environment]::GetFolderPath('ProgramFiles')
            $gitRoot = if ($programFiles) { Join-Path $programFiles 'Git' } else { '' }
            $linkDirs = @(
                $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Microsoft/WinGet/Links' }),   # user-scope installs
                $(if ($programFiles) { Join-Path $programFiles 'WinGet/Links' })                      # machine-scope installs
            ) | Where-Object { $_ }
            $prereqs = [ordered]@{
                bash = @{ id = 'Git.Git';   fallback = @($(if ($gitRoot) { Join-Path $gitRoot 'bin/bash.exe' })) }
                git  = @{ id = 'Git.Git';   fallback = @($(if ($gitRoot) { Join-Path $gitRoot 'cmd/git.exe' })) }
                jq   = @{ id = 'jqlang.jq'; fallback = @($linkDirs | ForEach-Object { Join-Path $_ 'jq.exe' }) }
            }
            # The supported executable for a tool: first on PATH, else its known install location.
            function Resolve-Prereq([string]$tool) {
                $found = @(Get-Command $tool -All -CommandType Application -ErrorAction SilentlyContinue)
                # On Windows, `bash` in System32 / WindowsApps is the WSL launcher, not the Git
                # Bash the status line runs under — it does not count.
                if ($tool -eq 'bash' -and $IsWindows) {
                    $found = @($found | Where-Object { $_.Source -notmatch '\\(System32|WindowsApps)\\' })
                }
                if ($found.Count -gt 0) { return $found[0].Source }
                return @($prereqs[$tool].fallback | Where-Object { $_ -and (Test-Path -LiteralPath $_) }) | Select-Object -First 1
            }
            function Test-Prereq([string]$tool) { [bool](Resolve-Prereq $tool) }

            $missingTools = @($prereqs.Keys | Where-Object { -not (Test-Prereq $_) })
            $winget = Get-Command winget -ErrorAction SilentlyContinue
            if ($missingTools -and $winget -and -not $SkipPrereqInstall) {
                foreach ($id in @($missingTools | ForEach-Object { $prereqs[$_].id } | Select-Object -Unique)) {
                    $tools = @($missingTools | Where-Object { $prereqs[$_].id -eq $id })
                    $label = $tools -join ', '
                    if (-not $Force) {
                        Add-Result 'statusline' $label 'preview' "would install $label (winget install --id $id)"
                        continue
                    }
                    & winget install --id $id --exact --silent --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Null
                    $wingetCode = $LASTEXITCODE
                    $still = @($tools | Where-Object { -not (Test-Prereq $_) })
                    if ($still.Count -eq 0) {
                        Add-Result 'statusline' $label 'deployed' "installed $label via winget ($id; new shells pick it up on PATH)"
                    } else {
                        Add-Result 'statusline' $label 'warning' "winget install $id exited $wingetCode and $($still -join ', ') is still not found - install it manually"
                    }
                }
                # In preview, the tools above are accounted for; after an install, re-check.
                $missingTools = if ($Force) { @($prereqs.Keys | Where-Object { -not (Test-Prereq $_) }) } else { @() }
            }
            if ($missingTools) {
                $hints = ($missingTools | ForEach-Object { "${_}: winget install $($prereqs[$_].id)" }) -join '; '
                Add-Result 'statusline' 'prerequisites' 'warning' ("status line needs: " + ($missingTools -join ', ') + " - not found ($hints)")
            }

            $claudeDir    = Join-Path $HomeDir '.claude'
            $scriptTarget = Join-Path $claudeDir 'statusline.sh'
            $settingsPath = Join-Path $claudeDir 'settings.json'
            # Wire the same supported executable prerequisite detection accepted, resolved after
            # any install. Bare `bash` may select the WSL launcher, so it is never written.
            $bashPath = Resolve-Prereq 'bash'
            # Preview: a pending Git.Git install lands at its known location.
            if (-not $bashPath -and -not $Force) { $bashPath = @($prereqs.bash.fallback)[0] }
            # POSIX single quoting preserves spaces, apostrophes, and shell metacharacters.
            $quotePosix = { param($p) "'" + ($p -replace '\\', '/').Replace("'", "'\''") + "'" }
            $command = if ($bashPath) { "$(& $quotePosix $bashPath) $(& $quotePosix $scriptTarget)" } else { $null }

            $settings = @{}
            if (Test-Path -LiteralPath $settingsPath) {
                $raw = Get-Content -LiteralPath $settingsPath -Raw
                if ($raw.Trim()) { $settings = $raw | ConvertFrom-Json -AsHashtable }
            }
            $current = if ($settings.ContainsKey('statusLine')) { $settings['statusLine'] } else { $null }
            $currentCmd = if ($current -is [System.Collections.IDictionary] -and $current.ContainsKey('command')) { [string]$current['command'] } else { $null }

            $legacyPath = if ($HomeDir -eq $DefaultHome) { '~/.claude/statusline.sh' } else { $scriptTarget -replace '\\', '/' }
            $isManagedCommand = $currentCmd -eq $command -or $currentCmd -eq "bash $legacyPath"
            if (-not $command) {
                Add-Result 'statusline' 'statusline' 'warning' 'no supported bash found - status line not deployed or wired (see prerequisites)'
            } elseif ($current -and -not $isManagedCommand) {
                Add-Result 'statusline' 'statusline' 'skipped' "a custom status line is already configured ($currentCmd) - left unchanged"
            } else {
                $assetText = ([System.IO.File]::ReadAllText($asset)) -replace "`r`n", "`n"
                $same = (Test-Path -LiteralPath $scriptTarget) -and (([System.IO.File]::ReadAllText($scriptTarget) -replace "`r`n", "`n") -eq $assetText)
                $actions = @()
                if (-not $same) { $actions += "deploy $scriptTarget" }
                $needsWiring = -not $current -or $currentCmd -ne $command
                if ($needsWiring) { $actions += "wire statusLine in $settingsPath" }
                if ($actions.Count -eq 0) {
                    Add-Result 'statusline' 'statusline' 'current' 'status line already deployed and wired'
                } elseif (-not $Force) {
                    Add-Result 'statusline' 'statusline' 'preview' ("would " + ($actions -join '; '))
                } else {
                    $notes = @()
                    if (-not $same) {
                        if (Test-Path -LiteralPath $scriptTarget) { $notes += "script backed up to $(Backup-File $scriptTarget)" }
                        Write-Utf8Lf $scriptTarget $assetText
                    }
                    if ($needsWiring) {
                        if (Test-Path -LiteralPath $settingsPath) { $notes += "settings backed up to $(Backup-File $settingsPath)" }
                        $settings['statusLine'] = [ordered]@{ type = 'command'; command = $command }
                        Write-Utf8Lf $settingsPath (($settings | ConvertTo-Json -Depth 32) + "`n")
                    }
                    Add-Result 'statusline' 'statusline' 'deployed' ((@("done: " + ($actions -join '; ')) + $notes) -join '; ')
                }
            }
        }
    }

    # --- Phase 3: default instructions files -----------------------------------
    if (-not $SkipInstructions) {
        $guardrails = @($manifest.standard_guardrails)
        $sources = @()
        foreach ($g in $guardrails) {
            $path = Join-Path $RepoRoot "shared/guardrails/$g.md"
            if ($g -notmatch '^[A-Za-z0-9._-]+$' -or -not (Test-Path -LiteralPath $path)) {
                Add-Result 'instructions' $g 'missing' "no shared/guardrails/$g.md - skipped" 1
                continue
            }
            $parts = Split-Frontmatter $path
            $sources += @{ name = $g; appliesTo = @(Get-FmList $parts.fm 'applies-to'); body = $parts.body.Trim() }
        }

        foreach ($v in $InstructionVendors) {
            $file   = Join-Path $HomeDir (Join-Path ".$v" $InstructionFile[$v])
            $chosen = @($sources | Where-Object { $_.appliesTo.Count -eq 0 -or $_.appliesTo -contains $v })
            if (Test-Path -LiteralPath $file) {
                Add-Result 'instructions' $InstructionFile[$v] 'skipped' "$file already exists - left unchanged"
                continue
            }
            if ($chosen.Count -eq 0) {
                Add-Result 'instructions' $InstructionFile[$v] 'skipped' "no standard guardrail applies to $v"
                continue
            }
            $names = ($chosen | ForEach-Object { $_.name }) -join ', '
            if (-not $Force) {
                Add-Result 'instructions' $InstructionFile[$v] 'preview' "would write $file ($names)"
                continue
            }
            $text = "# Global agent rules`n`n" +
                "<!-- Written by ai-agent-kit scripts/bootstrap-profile.ps1 from shared/guardrails/ ($names).`n" +
                "     This file is yours now: edit freely - re-running the bootstrap never overwrites it. -->`n`n" +
                (($chosen | ForEach-Object { $_.body }) -join "`n`n") + "`n"
            Write-Utf8Lf $file $text
            Add-Result 'instructions' $InstructionFile[$v] 'deployed' "wrote $file ($names)"
        }
    }
} catch {
    Add-Result 'bootstrap' '(bootstrap)' 'failed' $_.Exception.Message 2
}

if ($Json) {
    [pscustomobject]$report | ConvertTo-Json -Depth 6
} else {
    $mode = if ($Force) { 'deploy' } else { 'preview (pass -Force to write)' }
    Write-Host "bootstrap-profile: $Vendor skills, profile $HomeDir - $mode"
    if ($report.pulled) { Write-Host "  clone: $($report.pulled)" }
    foreach ($r in $report.results) {
        Write-Host ("  [{0,-8}] {1,-12} {2}: {3}" -f $r.status, $r.phase, $r.name, $r.message)
    }
    Write-Host "bootstrap-profile: exit $($report.exitCode)"
}

exit $report.exitCode
