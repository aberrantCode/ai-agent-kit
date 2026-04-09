#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive skill and instruction installer for Claude, Codex, and Gemini.

.DESCRIPTION
    Fetches available skills and agent instructions from the llm_skills GitHub
    archive, displays interactive selectors, and deploys chosen bundles to local
    directories you specify.

    Flow:
      1. Pick platforms  (Claude / Codex / Gemini)
      2. Pick asset types (Skills / Instructions)
      3. Set deploy paths
      4. Select items via interactive checkbox UI
      5. Confirm and apply

.NOTES
    Remote one-liner:
        irm 'https://raw.githubusercontent.com/aberrantCode/llm_skills/main/install-skills.ps1' | iex
#>

$ErrorActionPreference = 'Stop'

# ── Constants ─────────────────────────────────────────────────────────────────

$Owner   = 'aberrantCode'
$Repo    = 'llm_skills'
$Branch  = 'main'
$ApiBase = "https://api.github.com/repos/$Owner/$Repo"
$RawBase = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch"

# ── Manifest URL ──────────────────────────────────────────────────────────────
# The manifest.json at repo root contains all skill/instruction metadata:
# categories, descriptions, standard skills list. One fetch replaces both the
# hardcoded category map and the per-skill description API calls.

$ManifestUrl = "$RawBase/manifest.json"

# ── Deploy Path Defaults ─────────────────────────────────────────────────────

$DefaultPaths = @{
    'claude_skills'       = Join-Path $env:USERPROFILE '.claude\skills'
    'claude_instructions' = Join-Path $env:USERPROFILE '.claude\agents'
    'codex_skills'        = Join-Path $env:USERPROFILE '.codex\skills'
    'codex_instructions'  = Join-Path $env:USERPROFILE '.codex\agents'
    'gemini_skills'       = Join-Path $env:USERPROFILE '.gemini\skills'
    'gemini_instructions' = Join-Path $env:USERPROFILE '.gemini\agents'
}

# ── Helpers ───────────────────────────────────────────────────────────────────

function Invoke-GitHubApi {
    param([string]$Path)
    try {
        Invoke-RestMethod -Uri "$ApiBase/$Path" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 404) { return $null }
        throw
    }
}

# Manifest data (populated in Phase 4)
$script:Manifest = $null
$script:DescLookup = @{}

# ── Simple Checkbox Picker (for platform/type selection) ──────────────────────

function Show-CheckboxPicker {
    param(
        [string]   $Title,
        [string[]] $Labels,
        [bool[]]   $Checked
    )

    $cursor  = 0
    $width   = [Math]::Max([Console]::WindowWidth, 60)
    $running = $true

    while ($running) {
        [Console]::SetCursorPosition(0, 0)
        [Console]::CursorVisible = $false

        Write-Host "  $Title".PadRight($width) -ForegroundColor Cyan -BackgroundColor DarkBlue
        Write-Host ('  ' + ('-' * ($width - 4)) + '  ') -ForegroundColor DarkGray
        Write-Host '  [Space] Toggle   [Enter] Confirm   [Q] Quit'.PadRight($width) -ForegroundColor DarkGray
        Write-Host ''

        for ($i = 0; $i -lt $Labels.Count; $i++) {
            $check = if ($Checked[$i]) { 'x' } else { ' ' }
            $arrow = if ($i -eq $cursor) { '>' } else { ' ' }

            if ($i -eq $cursor -and $Checked[$i]) {
                Write-Host "    $arrow [$check] $($Labels[$i])".PadRight($width) -ForegroundColor Yellow -BackgroundColor DarkGreen
            } elseif ($i -eq $cursor) {
                Write-Host "    $arrow [$check] $($Labels[$i])".PadRight($width) -ForegroundColor Yellow -BackgroundColor DarkBlue
            } elseif ($Checked[$i]) {
                Write-Host "    $arrow [$check] $($Labels[$i])".PadRight($width) -ForegroundColor Green
            } else {
                Write-Host "    $arrow [$check] $($Labels[$i])".PadRight($width) -ForegroundColor Gray
            }
        }

        # Pad
        for ($p = $Labels.Count; $p -lt 6; $p++) { Write-Host ''.PadRight($width) }

        $sel = @($Checked | Where-Object { $_ }).Count
        Write-Host ''
        Write-Host "  $sel selected".PadRight($width) -ForegroundColor White

        $key = [Console]::ReadKey($true)

        if ($key.Key -eq [ConsoleKey]::UpArrow -and $cursor -gt 0) { $cursor-- }
        elseif ($key.Key -eq [ConsoleKey]::DownArrow -and $cursor -lt $Labels.Count - 1) { $cursor++ }
        elseif ($key.Key -eq [ConsoleKey]::Spacebar) { $Checked[$cursor] = -not $Checked[$cursor] }
        elseif ($key.Key -eq [ConsoleKey]::Enter) {
            if (@($Checked | Where-Object { $_ }).Count -gt 0) { $running = $false }
        }
        elseif ($key.KeyChar.ToString().ToLower() -eq 'q') {
            [Console]::CursorVisible = $true
            [Console]::Clear()
            Write-Host 'Aborted - no changes made.' -ForegroundColor Yellow
            exit 0
        }
    }

    return $Checked
}

# ── Visible Item Builder (for category-based skill selector) ──────────────────

function Get-VisibleItems {
    param(
        [System.Collections.Specialized.OrderedDictionary]$AllCategories,
        [hashtable]$Expanded,
        [string[]]$Available
    )

    $items       = [System.Collections.Generic.List[hashtable]]::new()
    $categorized = @{}

    foreach ($catName in $AllCategories.Keys) {
        $catSkills = @($AllCategories[$catName] | Where-Object { $Available -contains $_ })
        if ($catSkills.Count -eq 0) { continue }
        $items.Add(@{ type = 'category'; name = $catName; skills = $catSkills })
        foreach ($s in $catSkills) { $categorized[$s] = $true }
        if ($Expanded[$catName]) {
            foreach ($skill in $catSkills) {
                $items.Add(@{ type = 'skill'; name = $skill; category = $catName })
            }
        }
    }

    $uncategorized = @($Available | Where-Object { -not $categorized.ContainsKey($_) })
    if ($uncategorized.Count -gt 0) {
        $items.Add(@{ type = 'category'; name = 'Other'; skills = $uncategorized })
        if ($Expanded['Other']) {
            foreach ($skill in $uncategorized) {
                $items.Add(@{ type = 'skill'; name = $skill; category = 'Other' })
            }
        }
    }

    return , $items.ToArray()
}

# ── Category Selector UI ─────────────────────────────────────────────────────

function Show-CategorySelector {
    param(
        [object[]]  $Items,
        [hashtable] $Selected,
        [hashtable] $Expanded,
        [int]       $Cursor,
        [int]       $ViewportTop,
        [string]    $Description,
        [string]    $Title,
        [int]       $ViewportSize,
        [int]       $Width
    )

    [Console]::SetCursorPosition(0, 0)
    [Console]::CursorVisible = $false

    Write-Host "  $Title".PadRight($Width) -ForegroundColor Cyan -BackgroundColor DarkBlue
    Write-Host ('  ' + ('-' * ($Width - 4)) + '  ') -ForegroundColor DarkGray
    Write-Host '  [Sp] Toggle  [Enter] Expand/Apply  [A] All  [N] None  [I] Invert  [Q] Quit  '.PadRight($Width) -ForegroundColor DarkGray
    Write-Host ''

    $viewportEnd = [Math]::Min($ViewportTop + $ViewportSize - 1, $Items.Count - 1)

    for ($i = $ViewportTop; $i -le $viewportEnd; $i++) {
        $item     = $Items[$i]
        $isActive = ($i -eq $Cursor)

        if ($item.type -eq 'category') {
            $catSkills  = $item.skills
            $selCount   = @($catSkills | Where-Object { $Selected[$_] }).Count
            $total      = $catSkills.Count
            $expandChar = if ($Expanded[$item.name]) { '-' } else { '+' }
            $checkChar  = if ($selCount -eq $total -and $total -gt 0) { 'x' } `
                          elseif ($selCount -gt 0) { '~' } else { ' ' }
            $label      = "  [$checkChar] [$expandChar] $($item.name)  ($selCount/$total)"
            $line       = $label.PadRight($Width)

            if ($isActive) { Write-Host $line -ForegroundColor Black -BackgroundColor Cyan }
            elseif ($selCount -gt 0) { Write-Host $line -ForegroundColor Cyan }
            else { Write-Host $line -ForegroundColor DarkCyan }
        } else {
            $isSel = $Selected[$item.name]
            $check = if ($isSel) { 'x' } else { ' ' }
            $arrow = if ($isActive) { '>' } else { ' ' }
            $line  = "        $arrow [$check] $($item.name)".PadRight($Width)

            if ($isActive -and $isSel) { Write-Host $line -ForegroundColor Yellow -BackgroundColor DarkGreen }
            elseif ($isActive) { Write-Host $line -ForegroundColor Yellow -BackgroundColor DarkBlue }
            elseif ($isSel) { Write-Host $line -ForegroundColor Green }
            else { Write-Host $line -ForegroundColor Gray }
        }
    }

    $rendered = $viewportEnd - $ViewportTop + 1
    for ($p = $rendered; $p -lt $ViewportSize; $p++) { Write-Host ''.PadRight($Width) }

    Write-Host ''
    Write-Host ("  > $Description").PadRight($Width) -ForegroundColor DarkCyan

    $checkedCount = @($Selected.Values | Where-Object { $_ }).Count
    $scrollInfo   = if ($Items.Count -gt $ViewportSize) {
        "  rows $($ViewportTop+1)-$($viewportEnd+1) of $($Items.Count)"
    } else { '' }
    Write-Host "  Selected: $checkedCount / $($Selected.Count)  $scrollInfo".PadRight($Width) -ForegroundColor White
}

# ── Interactive Selector Loop (shared by skills and instructions) ─────────────

function Invoke-Selector {
    param(
        [string]   $Title,
        [string[]] $Available,
        [string[]] $Installed,
        [System.Collections.Specialized.OrderedDictionary]$Categories  # $null for flat list
    )

    # Build selection state
    $selected = @{}
    foreach ($s in $Available) { $selected[$s] = ($Installed -contains $s) }

    # Build category map (flat list = single "All" category)
    $allCats = [ordered]@{}
    if ($Categories) {
        foreach ($k in $Categories.Keys) { $allCats[$k] = $Categories[$k] }
    } else {
        $allCats['All'] = @($Available)
    }

    # Expansion state
    $expanded = @{ 'Other' = $false }
    foreach ($k in $allCats.Keys) { $expanded[$k] = $false }
    $firstKey = @($allCats.Keys)[0]
    $expanded[$firstKey] = $true

    [Console]::Clear()

    $width      = [Math]::Max([Console]::WindowWidth, 72)
    $viewSize   = [Math]::Max([Console]::WindowHeight - 10, 10)
    $cursor     = 0
    $viewTop    = 0
    $lastCursor = -1
    $desc       = ''
    $running    = $true

    while ($running) {
        $items  = Get-VisibleItems -AllCategories $allCats -Expanded $expanded -Available $Available
        $maxIdx = $items.Count - 1
        if ($cursor -gt $maxIdx) { $cursor = $maxIdx }

        $cur = $items[$cursor]

        if ($cursor -ne $lastCursor) {
            $lastCursor = $cursor
            if ($cur.type -eq 'skill') {
                $d = $script:DescLookup[$cur.name]
                $desc = if ($d) { $d } else { '(no description)' }
            } else {
                $desc = "$($cur.skills.Count) items  [Space] toggle all  [Enter] expand"
            }
        }

        Show-CategorySelector -Items $items -Selected $selected -Expanded $expanded `
            -Cursor $cursor -ViewportTop $viewTop -Description $desc `
            -Title $Title -ViewportSize $viewSize -Width $width

        $key = [Console]::ReadKey($true)

        if ($key.Key -eq [ConsoleKey]::UpArrow) {
            if ($cursor -gt 0) { $cursor--; if ($cursor -lt $viewTop) { $viewTop = $cursor } }
        } elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
            if ($cursor -lt $maxIdx) { $cursor++; if ($cursor -ge $viewTop + $viewSize) { $viewTop = $cursor - $viewSize + 1 } }
        } elseif ($key.Key -eq [ConsoleKey]::PageUp) {
            $cursor  = [Math]::Max(0, $cursor - $viewSize)
            $viewTop = [Math]::Max(0, $viewTop - $viewSize)
        } elseif ($key.Key -eq [ConsoleKey]::PageDown) {
            $cursor  = [Math]::Min($maxIdx, $cursor + $viewSize)
            $viewTop = [Math]::Min([Math]::Max(0, $maxIdx - $viewSize + 1), $viewTop + $viewSize)
            if ($viewTop -lt 0) { $viewTop = 0 }
        } elseif ($key.Key -eq [ConsoleKey]::Spacebar) {
            if ($cur.type -eq 'category') {
                $catSkills   = @($cur.skills | Where-Object { $Available -contains $_ })
                $allSelected = (@($catSkills | Where-Object { $selected[$_] }).Count -eq $catSkills.Count)
                foreach ($s in $catSkills) { $selected[$s] = -not $allSelected }
            } else {
                $selected[$cur.name] = -not $selected[$cur.name]
            }
        } elseif ($key.Key -eq [ConsoleKey]::Enter) {
            if ($cur.type -eq 'category') { $expanded[$cur.name] = -not $expanded[$cur.name] }
            else { $running = $false }
        } else {
            switch ($key.KeyChar.ToString().ToLower()) {
                'a' { foreach ($s in $Available) { $selected[$s] = $true  } }
                'n' { foreach ($s in $Available) { $selected[$s] = $false } }
                'i' { foreach ($s in $Available) { $selected[$s] = -not $selected[$s] } }
                'q' {
                    [Console]::CursorVisible = $true
                    [Console]::Clear()
                    Write-Host 'Aborted - no changes made.' -ForegroundColor Yellow
                    exit 0
                }
            }
        }
    }

    [Console]::CursorVisible = $true
    return $selected
}

# ── Install Helpers ───────────────────────────────────────────────────────────

function Install-SkillBundle {
    param([string]$SkillName, [string]$Platform, [string]$InstallDir)

    $skillDir = Join-Path $InstallDir $SkillName
    if (-not (Test-Path $skillDir)) { New-Item -ItemType Directory -Path $skillDir -Force | Out-Null }

    try {
        Invoke-WebRequest -Uri "$RawBase/$Platform/skills/$SkillName/SKILL.md" `
            -OutFile (Join-Path $skillDir 'SKILL.md') -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Warning "    Could not download $SkillName/SKILL.md - skipping"
        return $false
    }

    try {
        $commandsApi = Invoke-GitHubApi "contents/$Platform/skills/$SkillName/commands"
        if ($commandsApi) {
            $cmdDir = Join-Path $skillDir 'commands'
            if (-not (Test-Path $cmdDir)) { New-Item -ItemType Directory -Path $cmdDir -Force | Out-Null }
            foreach ($item in ($commandsApi | Where-Object { $_.type -eq 'file' -and $_.download_url })) {
                Invoke-WebRequest -Uri $item.download_url -OutFile (Join-Path $cmdDir $item.name) `
                    -UseBasicParsing -ErrorAction Stop
            }
        }
    } catch { Write-Warning "    commands/ incomplete for $SkillName" }

    try {
        $subApi = Invoke-GitHubApi "contents/$Platform/skills/$SkillName/sub-skills"
        if ($subApi) {
            $subRoot = Join-Path $skillDir 'sub-skills'
            if (-not (Test-Path $subRoot)) { New-Item -ItemType Directory -Path $subRoot -Force | Out-Null }
            foreach ($subDir in ($subApi | Where-Object { $_.type -eq 'dir' })) {
                $subDest = Join-Path $subRoot $subDir.name
                if (-not (Test-Path $subDest)) { New-Item -ItemType Directory -Path $subDest -Force | Out-Null }
                $subFiles = Invoke-GitHubApi "contents/$Platform/skills/$SkillName/sub-skills/$($subDir.name)"
                foreach ($file in ($subFiles | Where-Object { $_.type -eq 'file' -and $_.name -like '*.md' -and $_.download_url })) {
                    Invoke-WebRequest -Uri $file.download_url -OutFile (Join-Path $subDest $file.name) `
                        -UseBasicParsing -ErrorAction Stop
                }
            }
        }
    } catch { Write-Warning "    sub-skills/ incomplete for $SkillName" }

    return $true
}

function Install-Instruction {
    param([string]$Name, [string]$Platform, [string]$InstallDir)

    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }

    $dest = Join-Path $InstallDir "$Name.md"
    try {
        Invoke-WebRequest -Uri "$RawBase/$Platform/instructions/$Name.md" `
            -OutFile $dest -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        Write-Warning "    Could not download $Name.md - skipping"
        return $false
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN FLOW
# ══════════════════════════════════════════════════════════════════════════════

[Console]::Clear()

# ── Phase 1: Platform Selection ───────────────────────────────────────────────

$platformLabels  = @('Claude', 'Codex', 'Gemini')
$platformKeys    = @('claude', 'codex', 'gemini')
$platformChecked = @($true, $false, $false)

$platformChecked = Show-CheckboxPicker -Title 'Select Platforms' -Labels $platformLabels -Checked $platformChecked

$selectedPlatforms = @()
for ($i = 0; $i -lt $platformKeys.Count; $i++) {
    if ($platformChecked[$i]) { $selectedPlatforms += $platformKeys[$i] }
}

# ── Phase 2: Type Selection ───────────────────────────────────────────────────

[Console]::Clear()

$typeLabels  = @('Skills', 'Instructions')
$typeKeys    = @('skills', 'instructions')
$typeChecked = @($true, $true)

$typeChecked = Show-CheckboxPicker -Title 'What would you like to manage?' -Labels $typeLabels -Checked $typeChecked

$selectedTypes = @()
for ($i = 0; $i -lt $typeKeys.Count; $i++) {
    if ($typeChecked[$i]) { $selectedTypes += $typeKeys[$i] }
}

# ── Phase 3: Deploy Paths ────────────────────────────────────────────────────

[Console]::Clear()
Write-Host '  Deploy Paths' -ForegroundColor Cyan
Write-Host '  ------------------------------------------------' -ForegroundColor DarkGray
Write-Host '  Press Enter to accept the default shown in [brackets].' -ForegroundColor DarkGray
Write-Host ''

$deployPaths = @{}

foreach ($platform in $selectedPlatforms) {
    foreach ($assetType in $selectedTypes) {
        $key     = "${platform}_${assetType}"
        $default = $DefaultPaths[$key]
        if (-not $default) { $default = Join-Path $env:USERPROFILE ".$platform\$assetType" }

        $prompt = "  $($platform.Substring(0,1).ToUpper() + $platform.Substring(1)) $assetType [$default]"
        $answer = Read-Host $prompt
        if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $default }
        $deployPaths[$key] = $answer

        if (-not (Test-Path $answer)) {
            New-Item -ItemType Directory -Path $answer -Force | Out-Null
        }
    }
}

# ── Phase 4: Fetch Manifest + Select ─────────────────────────────────────────

Write-Host ''
Write-Host '  Fetching manifest from GitHub...' -ForegroundColor Cyan

try {
    $script:Manifest = Invoke-RestMethod -Uri $ManifestUrl -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
} catch {
    Write-Warning "Could not fetch manifest.json - falling back to API listing"
    $script:Manifest = $null
}

$allChanges = [System.Collections.Generic.List[hashtable]]::new()

foreach ($platform in $selectedPlatforms) {
    foreach ($assetType in $selectedTypes) {
        $key        = "${platform}_${assetType}"
        $installDir = $deployPaths[$key]

        # Try manifest first, fall back to API listing
        $available     = @()
        $categories    = $null
        $script:DescLookup = @{}

        if ($script:Manifest -and $script:Manifest.platforms.$platform) {
            $pData = $script:Manifest.platforms.$platform

            if ($assetType -eq 'skills' -and $pData.skills) {
                $available = @($pData.skills.PSObject.Properties.Name | Sort-Object)

                # Build description lookup
                foreach ($prop in $pData.skills.PSObject.Properties) {
                    $script:DescLookup[$prop.Name] = $prop.Value.description
                }

                # Build category map from manifest
                $catMap = [ordered]@{}
                $standardList = @($script:Manifest.standard_skills | Where-Object { $available -contains $_ })
                if ($standardList.Count -gt 0) { $catMap['Standard Skills'] = $standardList }
                foreach ($catName in $script:Manifest.categories) {
                    $catSkills = @($pData.skills.PSObject.Properties |
                        Where-Object { $_.Value.category -eq $catName } |
                        ForEach-Object { $_.Name } | Sort-Object)
                    if ($catSkills.Count -gt 0) { $catMap[$catName] = $catSkills }
                }
                $categories = $catMap

            } elseif ($assetType -eq 'instructions' -and $pData.instructions) {
                $available = @($pData.instructions.PSObject.Properties.Name | Sort-Object)
                foreach ($prop in $pData.instructions.PSObject.Properties) {
                    $script:DescLookup[$prop.Name] = $prop.Value.description
                }
            }
        }

        # Fallback: API listing if manifest didn't have this platform/type
        if ($available.Count -eq 0) {
            Write-Host "  Fetching $platform $assetType from API..." -ForegroundColor DarkGray

            if ($assetType -eq 'skills') {
                $apiItems = Invoke-GitHubApi "contents/$platform/skills"
                if ($apiItems) {
                    $available = @($apiItems | Where-Object { $_.type -eq 'dir' } | Select-Object -ExpandProperty name | Sort-Object)
                }
            } else {
                $apiItems = Invoke-GitHubApi "contents/$platform/instructions"
                if ($apiItems) {
                    $available = @($apiItems | Where-Object { $_.type -eq 'file' -and $_.name -like '*.md' -and $_.name -ne '.gitkeep' } |
                        ForEach-Object { $_.name -replace '\.md$', '' } | Sort-Object)
                }
            }
        }

        if ($available.Count -eq 0) {
            Write-Host "    No $assetType found for $platform." -ForegroundColor DarkGray
            continue
        }

        # Detect installed
        if ($assetType -eq 'skills') {
            $installed = @(Get-ChildItem -Path $installDir -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        } else {
            $installed = @(Get-ChildItem -Path $installDir -Filter '*.md' -File -ErrorAction SilentlyContinue |
                ForEach-Object { $_.Name -replace '\.md$', '' })
        }

        Write-Host "  Found $($available.Count) $assetType for $platform." -ForegroundColor DarkGray

        $platformTitle = $platform.Substring(0,1).ToUpper() + $platform.Substring(1)
        $assetLabel    = if ($assetType -eq 'skills') { 'Skills' } else { 'Instructions' }

        $selected = Invoke-Selector `
            -Title "$platformTitle $assetLabel" `
            -Available $available `
            -Installed $installed `
            -Categories $categories

        $toInstall = @($available | Where-Object { $selected[$_]  -and ($installed -notcontains $_) })
        $toRemove  = @($available | Where-Object { -not $selected[$_] -and ($installed -contains $_) })

        if ($toInstall.Count -gt 0 -or $toRemove.Count -gt 0) {
            $allChanges.Add(@{
                platform   = $platform
                assetType  = $assetType
                installDir = $installDir
                toInstall  = $toInstall
                toRemove   = $toRemove
            })
        }
    }
}

# ── Phase 5: Confirm + Apply ─────────────────────────────────────────────────

[Console]::Clear()

if ($allChanges.Count -eq 0) {
    Write-Host 'No changes to apply.' -ForegroundColor Green
    exit 0
}

Write-Host 'Pending changes:' -ForegroundColor White
Write-Host ''

foreach ($change in $allChanges) {
    $label = "$($change.platform) $($change.assetType) -> $($change.installDir)"
    Write-Host "  $label" -ForegroundColor White -BackgroundColor DarkGray
    foreach ($name in $change.toInstall) { Write-Host "    + $name" -ForegroundColor Green }
    foreach ($name in $change.toRemove)  { Write-Host "    - $name" -ForegroundColor Red }
    Write-Host ''
}

$confirm = Read-Host 'Apply these changes? [Y/N]'
if ($confirm -notmatch '^[Yy]') {
    Write-Host 'Aborted - no changes made.' -ForegroundColor Yellow
    exit 0
}

Write-Host ''

foreach ($change in $allChanges) {
    $platform   = $change.platform
    $installDir = $change.installDir

    foreach ($name in $change.toRemove) {
        if ($change.assetType -eq 'skills') {
            $path = Join-Path $installDir $name
        } else {
            $path = Join-Path $installDir "$name.md"
        }
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force
            Write-Host "  - Removed $name ($($change.platform) $($change.assetType))" -ForegroundColor Red
        }
    }

    foreach ($name in $change.toInstall) {
        Write-Host "  + Installing $name..." -ForegroundColor Green -NoNewline
        if ($change.assetType -eq 'skills') {
            $ok = Install-SkillBundle -SkillName $name -Platform $platform -InstallDir $installDir
        } else {
            $ok = Install-Instruction -Name $name -Platform $platform -InstallDir $installDir
        }
        if ($ok) { Write-Host ' done' -ForegroundColor DarkGreen }
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ''
$totalInstalled = ($allChanges | ForEach-Object { $_.toInstall.Count } | Measure-Object -Sum).Sum
$totalRemoved   = ($allChanges | ForEach-Object { $_.toRemove.Count }  | Measure-Object -Sum).Sum
Write-Host "Done.  +$totalInstalled installed, -$totalRemoved removed." -ForegroundColor Cyan
