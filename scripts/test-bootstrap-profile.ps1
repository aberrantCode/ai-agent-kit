#Requires -Version 7.0
# Integration regression: the emitted command must use the supported Bash executable
# and preserve a profile path containing spaces and apostrophes.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$bashCommands = @(Get-Command bash -All -CommandType Application -ErrorAction SilentlyContinue)
if ($IsWindows) {
    $bashCommands = @($bashCommands | Where-Object { $_.Source -notmatch '\\(System32|WindowsApps)\\' })
}
$bashPath = if ($bashCommands.Count) { $bashCommands[0].Source } else { $null }
if (-not $bashPath -and $IsWindows) {
    $fallback = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'Git/bin/bash.exe'
    if (Test-Path -LiteralPath $fallback) { $bashPath = $fallback }
}
if (-not $bashPath) { throw 'This regression check requires a supported Bash installation.' }

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('bootstrap-regression-' + [guid]::NewGuid().ToString('N'))
$profileRoot = Join-Path $testRoot "profile with spaces and 'apostrophe"
New-Item -ItemType Directory -Path $profileRoot -Force | Out-Null
$pwshPath = (Get-Process -Id $PID).Path
$bootstrap = Join-Path $PSScriptRoot 'bootstrap-profile.ps1'
function Invoke-Bootstrap([string[]]$Extra = @('-ProfileHome', $profileRoot)) {
    $out = & $pwshPath -NoProfile -File $bootstrap -Name base @Extra -SkipPrereqInstall -SkipInstructions -Force -Json
    if ($LASTEXITCODE -ne 0) { throw "Bootstrap failed: $out" }
}
try {
    Invoke-Bootstrap
    $settingsPath = Join-Path $profileRoot '.claude/settings.json'
    $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    if ($settings.statusLine.command -match '^bash ') { throw 'Generated command still relies on bare bash.' }
    # Replace the deployed script only inside this disposable fixture to isolate launch
    # correctness from jq and the status-line rendering implementation.
    $scriptPath = Join-Path $profileRoot '.claude/statusline.sh'
    [System.IO.File]::WriteAllText($scriptPath, "printf bootstrap-launch-ok`n")
    $actual = & $bashPath -c $settings.statusLine.command 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $actual.Trim() -ne 'bootstrap-launch-ok') {
        throw "Generated status-line command failed: $actual"
    }
    # Existing bootstrap-managed commands must migrate, while unrelated settings stay.
    $legacyCommand = 'bash ' + ($scriptPath -replace '\\', '/')
    $legacy = @{ statusLine = @{ type = 'command'; command = $legacyCommand }; theme = 'dark' }
    $legacy | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $settingsPath
    Invoke-Bootstrap
    $migrated = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    if ($migrated.statusLine.command -ne $settings.statusLine.command -or $migrated.theme -ne 'dark') {
        throw 'Legacy command migration failed or lost unrelated settings.'
    }
    $custom = '{"statusLine":{"type":"command","command":"custom-statusline"},"theme":"dark"}'
    [System.IO.File]::WriteAllText($settingsPath, $custom)
    Invoke-Bootstrap
    if ([System.IO.File]::ReadAllText($settingsPath) -ne $custom) { throw 'Custom status-line settings changed.' }

    # Default profile home: the canonical `bash ~/.claude/statusline.sh` (the form
    # /install-statusline writes) is bootstrap-managed and migrates too.
    $homeVar = if ($IsWindows) { 'USERPROFILE' } else { 'HOME' }
    $savedHome = [Environment]::GetEnvironmentVariable($homeVar)
    $tilde = '{"statusLine":{"type":"command","command":"bash ~/.claude/statusline.sh"},"theme":"dark"}'
    [System.IO.File]::WriteAllText($settingsPath, $tilde)
    [Environment]::SetEnvironmentVariable($homeVar, $profileRoot)
    try { Invoke-Bootstrap @() } finally { [Environment]::SetEnvironmentVariable($homeVar, $savedHome) }
    $migrated = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    if ($migrated.statusLine.command -ne $settings.statusLine.command -or $migrated.theme -ne 'dark') {
        throw "Default-home legacy command did not migrate: $($migrated.statusLine.command)"
    }

    # Git Bash present only at its install location (off PATH, as right after a winget
    # install or with only the WSL launchers on PATH): the fallback path must be wired.
    $gitBash = if ($IsWindows) { Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'Git/bin/bash.exe' }
    if ($gitBash -and (Test-Path -LiteralPath $gitBash)) {
        $savedPath = $env:PATH
        $env:PATH = (($env:PATH -split ';') | Where-Object {
            $_ -and ($_ -match '\\(System32|WindowsApps)\\?$' -or -not (Test-Path -LiteralPath (Join-Path $_ 'bash.exe')))
        }) -join ';'
        try {
            Remove-Item -LiteralPath $settingsPath
            Invoke-Bootstrap
        } finally { $env:PATH = $savedPath }
        $fallbackCmd = (Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).statusLine.command
        if (-not $fallbackCmd.StartsWith("'" + ($gitBash -replace '\\', '/') + "' ")) {
            throw "Off-PATH Git Bash was not wired: $fallbackCmd"
        }
        [System.IO.File]::WriteAllText($scriptPath, "printf bootstrap-launch-ok`n")
        $actual = & $gitBash -c $fallbackCmd 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or $actual.Trim() -ne 'bootstrap-launch-ok') { throw "Fallback command failed: $actual" }
    } else {
        Write-Host 'SKIP: off-PATH Git Bash case (Windows with Git for Windows only).'
    }
    Write-Host 'PASS: status-line command resolves Bash and preserves special profile paths.'
} finally {
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    $resolvedTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTestRoot.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing cleanup outside the temporary directory.'
    }
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
}
