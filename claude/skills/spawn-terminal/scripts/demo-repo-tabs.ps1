<#
.SYNOPSIS
    Open one Windows Terminal window with a colored tab per registered repo, to preview the palette.

.DESCRIPTION
    Reads ~/.claude/repo-colors.json and opens a single WT window whose tabs are each titled by a
    repo and painted with that repo's assigned tab color. No Claude sessions are launched — each tab
    runs a pwsh banner so you can eyeball the color set together. Purely a visual check.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'resolve-repo-color.ps1')   # Get-ColorMap, palette

$map = Get-ColorMap
if ($map.Count -eq 0) { throw 'Registry is empty — run manage-repo-colors.ps1 -Action reset-top first.' }
if (-not (Get-Command wt.exe -ErrorAction SilentlyContinue)) { throw 'Windows Terminal (wt.exe) not found.' }

$banner = Join-Path ([System.IO.Path]::GetTempPath()) "repo-tab-banner-$PID.ps1"
@'
param($Repo, $Hex)
Write-Host ""
Write-Host "   $Repo" -ForegroundColor Green
Write-Host "   tab color $Hex" -ForegroundColor DarkGray
Write-Host ""
Write-Host "   (demo tab — close when done)" -ForegroundColor DarkGray
'@ | Set-Content -LiteralPath $banner -Encoding UTF8

# Build one wt invocation: `new-tab ... ; new-tab ... ; ...`. A bare ';' argument is wt's tab
# separator. Sorted by color so the palette reads in a stable order.
$wtArgs = @()
$first = $true
foreach ($entry in ($map.GetEnumerator() | Sort-Object Value)) {
    $repo = $entry.Key.Split('/')[-1]
    if (-not $first) { $wtArgs += ';' }
    $first = $false
    $wtArgs += @(
        'new-tab', '--title', $repo, '--tabColor', $entry.Value,
        'pwsh', '-NoExit', '-ExecutionPolicy', 'Bypass', '-File', $banner, '-Repo', $repo, '-Hex', $entry.Value
    )
}

Start-Process wt.exe -ArgumentList $wtArgs
Write-Host "Opened $($map.Count) colored demo tabs."
