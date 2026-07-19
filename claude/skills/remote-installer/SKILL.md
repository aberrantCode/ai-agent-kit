---
name: remote-installer
category: Tooling & DevOps
description: Domain expertise for implementing a remote PowerShell install script (install.ps1) and self-update check for a GitHub-hosted repository. Covers auto-elevation, GitHub Releases API version resolution, safe download-before-delete ordering, .env backup/merge, module dependency installation, and an in-app update-check block. Use when asked to add remote install or self-update capability to a PowerShell-based repo.
---

# Remote PowerShell Installer — Domain Expertise

This skill implements two artifacts in a GitHub-hosted PowerShell repository:

1. **`install.ps1`** — a repo-root bootstrap script, runnable as a one-liner remote command
2. **Update-check block** — inserted into the primary app script so it silently updates itself on each launch

## Critical Prerequisite — GitHub Releases must be published

`install.ps1` calls the GitHub Releases API (`/releases/latest`). This endpoint returns
**404 "Not Found"** if the repository has no published GitHub Releases — even if git tags
exist. A bare `git tag` + `git push --tags` is **not** sufficient.

**Every release must also be published with:**
```bash
gh release create "$VERSION" --title "$VERSION" --notes "..."
```

If the API returns 404, instruct the user to publish the release:
```bash
gh release create v1.0.0 --title "v1.0.0" --generate-notes
```

The `/release-to-main` skill includes this step when followed correctly.

---

## Required Context (must be known before writing any code)

| Variable | How to obtain |
|----------|--------------|
| `$OWNER/$REPO` | `git remote get-url origin` → parse GitHub URL |
| `$INSTALL_DIR` | Asked from user (e.g. `C:\osm\my-app`) |
| `$APP_SCRIPT` | Path to the primary script that runs the app (e.g. `src\MyApp\App.ps1`) |
| `$START_SCRIPT` | Launcher script path (e.g. `scripts\Start-App.ps1`) |
| `$MODULE` | Required PowerShell module name and version, or `$null` if none |
| `$ENV_EXAMPLE` | Whether `.env.example` exists at repo root (`$true`/`$false`) |

---

## Part 1 — `install.ps1` (repo root)

### Remote invocation one-liner
```powershell
irm 'https://raw.githubusercontent.com/$OWNER/$REPO/main/install.ps1' | iex
```

### Complete implementation pattern

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    Remote installer and self-updater for $REPO.

.DESCRIPTION
    Downloads the latest GitHub release, installs to $INSTALL_DIR, merges
    any existing .env, installs required modules, and optionally launches the app.

.NOTES
    Remote one-liner (elevated PowerShell):
        irm 'https://raw.githubusercontent.com/$OWNER/$REPO/main/install.ps1' | iex

    Auto-elevates to Administrator if needed.
#>

$ErrorActionPreference = 'Stop'

# ── Constants ─────────────────────────────────────────────────────────────────
$InstallDir      = '$INSTALL_DIR'
$ApiUrl          = 'https://api.github.com/repos/$OWNER/$REPO/releases/latest'
$RawInstallerUrl = 'https://raw.githubusercontent.com/$OWNER/$REPO/main/install.ps1'

# ── Auto-elevation ────────────────────────────────────────────────────────────
# PATTERN: Always elevate via re-launch, never via -RunAs on the caller.
# Use -Command with the same one-liner so the elevated window is self-contained.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $oneLiner = "Invoke-Expression (Invoke-RestMethod '$RawInstallerUrl')"
    Start-Process pwsh `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$oneLiner`"" `
        -Verb RunAs `
        -Wait
    exit
}

# ── Step 1: Resolve latest release via GitHub Releases API ───────────────────
# SAFEGUARD: Wrap in try/catch — if GitHub is unreachable, exit cleanly (0),
# never crash. This is especially important for the auto-update code path.
Write-Host 'Checking for latest release...' -ForegroundColor Cyan
try {
    $release = Invoke-RestMethod -Uri $ApiUrl -TimeoutSec 10 -ErrorAction Stop
} catch {
    Write-Warning "GitHub API unreachable: $_"
    Write-Warning 'Cannot check for updates. Exiting.'
    exit 0
}

$tag     = $release.tag_name          # e.g. "v1.2.0"
$version = $tag -replace '^v', ''     # e.g. "1.2.0"

# ── Step 2: Compare with installed version ───────────────────────────────────
# PATTERN: Track installed version in a plain-text version.txt file.
# If file is missing → treat as fresh install (never skip install on missing file).
$versionFile      = Join-Path $InstallDir 'version.txt'
$installedVersion = $null

if (Test-Path $versionFile) {
    $installedVersion = (Get-Content $versionFile -Raw).Trim()
}

if ($installedVersion -eq $version) {
    Write-Host "Already up to date (v$version)." -ForegroundColor Green
    # Jump directly to the run prompt (Step 8) — no download needed
} else {
    if ($installedVersion) {
        Write-Host "Updating v$installedVersion → v$version..." -ForegroundColor Cyan
    } else {
        Write-Host "Installing v$version..." -ForegroundColor Cyan
    }

    # ── Step 3: Backup .env BEFORE touching anything ─────────────────────────
    # SAFEGUARD: Read .env into memory first. The directory will be deleted in
    # Step 5; if we waited until after deletion the backup would be lost.
    $envPath   = Join-Path $InstallDir '.env'
    $envBackup = $null

    if (Test-Path $envPath) {
        $envBackup = Get-Content $envPath -Raw -ErrorAction SilentlyContinue
        Write-Host 'Backed up existing .env.' -ForegroundColor DarkGray
    }

    # ── Step 4: Download release ZIP ─────────────────────────────────────────
    # SAFEGUARD: Download BEFORE deleting the existing install.
    # If the download fails, the old install is left intact.
    $zipUrl  = "https://github.com/$OWNER/$REPO/archive/refs/tags/$tag.zip"
    $zipPath = Join-Path $env:TEMP "$REPO-$tag.zip"

    Write-Host "Downloading $zipUrl ..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Error "Download failed: $_"
        Write-Warning 'Existing install left untouched.'
        exit 1
    }

    # ── Step 5: Install — remove old, extract new ────────────────────────────
    # ORDERING: Only remove old install AFTER successful download (Step 4 above).
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force
    }

    $stagingDir = Join-Path $env:TEMP "$REPO-staging-$tag"
    if (Test-Path $stagingDir) { Remove-Item $stagingDir -Recurse -Force }

    Expand-Archive -Path $zipPath -DestinationPath $stagingDir -Force

    # SAFEGUARD: GitHub ZIPs always extract to a single root folder named
    # "{repo}-{version}". Detect it dynamically rather than hardcoding the name,
    # so the script works across version bumps.
    $extractedRoot = Get-ChildItem -Path $stagingDir -Directory | Select-Object -First 1

    if (-not $extractedRoot) {
        Write-Error 'Unexpected ZIP structure: no root folder found.'
        exit 1
    }

    Move-Item -Path $extractedRoot.FullName -Destination $InstallDir

    # Cleanup temp files
    Remove-Item -Path $zipPath    -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Installed to $InstallDir." -ForegroundColor Green

    # ── Step 6: Write version file ────────────────────────────────────────────
    Set-Content -Path (Join-Path $InstallDir 'version.txt') -Value $version -Encoding UTF8

    # ── Step 7: Restore and merge .env ───────────────────────────────────────
    # ALGORITHM (additive-only):
    #   1. Parse .env.example → key→defaultValue dict (skip comment lines)
    #   2. Parse backup .env  → key→existingValue dict
    #   3. For each key in .env.example:
    #        if key in backup  → use backup value  (never overwrite user data)
    #        else              → use example default (adds new keys transparently)
    #   4. Write merged KEY=value lines to .env
    #
    # This never removes keys the user already has and never overwrites
    # existing values. New keys added in a future .env.example appear automatically.
    #
    # If no backup existed, leave .env absent — the app handles missing .env
    # interactively on first launch.
    $envExamplePath = Join-Path $InstallDir '.env.example'

    if ($envBackup) {
        $backupDict = @{}
        foreach ($line in ($envBackup -split "`n")) {
            $line = $line.Trim()
            if ($line -match '^([^#=][^=]*)=(.*)$') {
                $backupDict[$Matches[1].Trim()] = $Matches[2].Trim()
            }
        }

        $exampleDict = @{}
        if (Test-Path $envExamplePath) {
            foreach ($line in (Get-Content $envExamplePath)) {
                $line = $line.Trim()
                if ($line -match '^([^#=][^=]*)=(.*)$') {
                    $exampleDict[$Matches[1].Trim()] = $Matches[2].Trim()
                }
            }
        }

        $merged = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $exampleDict.Keys) {
            if ($backupDict.ContainsKey($key)) {
                $merged.Add("$key=$($backupDict[$key])")
            } else {
                $merged.Add("$key=$($exampleDict[$key])")
            }
        }

        Set-Content -Path (Join-Path $InstallDir '.env') -Value ($merged -join "`n") -Encoding UTF8
        Write-Host '.env merged (existing values preserved).' -ForegroundColor DarkGray
    }
}

# ── Step 8: Install required PowerShell module if missing ────────────────────
# PATTERN: Check with Get-Module -ListAvailable before calling Install-Module.
# Omit this block entirely if no module dependency exists.
$moduleInstalled = Get-Module $MODULE -ListAvailable
if (-not $moduleInstalled) {
    Write-Host "Installing $MODULE module..." -ForegroundColor Cyan
    Install-Module $MODULE -RequiredVersion $MODULE_VERSION -Scope AllUsers -Force
    Write-Host "$MODULE installed." -ForegroundColor Green
}

# ── Step 9: Prompt to run ─────────────────────────────────────────────────────
# PATTERN: Gated by $env:SKIP_RUN_PROMPT — set by the in-app update-check block
# so that silent auto-updates don't open a second "run now?" prompt.
# Use a repo-unique env var name to avoid collisions: ${REPO}_SKIP_RUN_PROMPT
$startScript = Join-Path $InstallDir 'scripts\Start-App.ps1'

if (-not $env:${REPO}_SKIP_RUN_PROMPT) {
    $answer = Read-Host 'Run the app now? [Y/N]'
    if ($answer -match '^[Yy]') {
        if (Test-Path $startScript) {
            & $startScript
        } else {
            Write-Warning "Start script not found at: $startScript"
        }
    }
}
```

---

## Part 2 — Update-check block (insert into `$APP_SCRIPT`)

### Placement
Insert **immediately after the elevation guard block** and **before any module imports or UI setup**. The elevation guard ensures the update code runs with the necessary privileges.

```powershell
# ── Update check ───────────────────────────────────────────────────────────────
# DEV-SAFE: The entire block is skipped when version.txt is absent.
# version.txt is only written by install.ps1, so cloned/dev environments
# are unaffected and never make network calls here.
$versionFile = Join-Path $PSScriptRoot '..\..' 'version.txt'
if (Test-Path $versionFile) {
    $localVersion = (Get-Content $versionFile -Raw -ErrorAction SilentlyContinue).Trim()
    try {
        $release = Invoke-RestMethod `
            -Uri 'https://api.github.com/repos/$OWNER/$REPO/releases/latest' `
            -TimeoutSec 5 `
            -ErrorAction Stop
        $latestVersion = $release.tag_name -replace '^v', ''
        if ($latestVersion -ne $localVersion) {
            Write-Host "New version available ($latestVersion). Updating..."
            $env:${REPO}_SKIP_RUN_PROMPT = '1'
            Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/$OWNER/$REPO/main/install.ps1')
            $env:${REPO}_SKIP_RUN_PROMPT = $null
            & '$INSTALL_DIR\scripts\Start-App.ps1'
            return   # Exit this stale instance — re-launched copy takes over
        }
    } catch {
        # Offline or API unreachable — skip silently, run normally
    }
}
```

### Adjust `$PSScriptRoot` depth
The `Join-Path $PSScriptRoot '..\..' 'version.txt'` assumes `$APP_SCRIPT` lives two levels below the repo root (e.g. `src\MyApp\App.ps1`). Adjust the number of `'..'` segments to match the actual depth.

---

## Safeguards Checklist

Before declaring the implementation complete, verify every item:

### `install.ps1`
- [ ] `#Requires -Version 5.1` at top
- [ ] Auto-elevation re-launches via `Start-Process pwsh -Verb RunAs -Wait` (not `sudo`)
- [ ] GitHub API call wrapped in `try/catch` → `exit 0` on failure (clean, not error)
- [ ] `.env` backed up into memory **before** any directory removal
- [ ] ZIP downloaded **before** `Remove-Item` on install dir (download-before-delete)
- [ ] Extracted root folder detected dynamically, not hardcoded
- [ ] `version.txt` written after successful extract (not before)
- [ ] `.env` merge is additive-only: user values never overwritten, new keys added from example
- [ ] Module installed only when `Get-Module -ListAvailable` returns empty
- [ ] Run prompt gated by `$env:${REPO}_SKIP_RUN_PROMPT`
- [ ] `$ErrorActionPreference = 'Stop'` at top

### Update-check block
- [ ] Entire block inside `if (Test-Path $versionFile)` — dev environments skipped
- [ ] `try/catch` around API call — offline/timeout fails silently
- [ ] `-TimeoutSec 5` on `Invoke-RestMethod`
- [ ] `$env:${REPO}_SKIP_RUN_PROMPT = '1'` set before invoking installer
- [ ] Env var cleared after installer returns (`= $null`)
- [ ] `return` after re-launching so the stale instance exits
- [ ] Positioned after elevation guard, before module imports

---

## Common Mistakes to Avoid

| Mistake | Correct Pattern |
|---------|----------------|
| Delete install dir before downloading | Download first, then delete, then extract |
| Read .env after removing install dir | Backup .env into memory before any deletion |
| Hardcode extracted folder name | `Get-ChildItem -Directory \| Select-Object -First 1` |
| `exit 1` when GitHub API is unreachable | `exit 0` — being offline is not an error |
| Skip `Test-Path $versionFile` guard | Always wrap update check in this guard |
| Force-install module on every run | Check `Get-Module -ListAvailable` first |
| Use same env var name across repos | Prefix with repo name: `${REPO}_SKIP_RUN_PROMPT` |
| Apply update check before elevation | Elevation guard must come first |
| Use `Write-Host` with Spectre markup before module import | Module must be imported before using markup syntax |
| Overwrite user .env values on update | Merge algorithm: backup values always win |

## Diagram

[View diagram](diagram.html)
