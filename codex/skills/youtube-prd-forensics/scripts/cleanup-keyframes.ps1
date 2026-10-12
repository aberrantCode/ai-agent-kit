<#
.SYNOPSIS
    Delete the temporary keyframe working directory once the PRD is complete.

.DESCRIPTION
    Implements workflow step 9 of the youtube-prd-forensics skill: after keyframes
    have been analyzed (step 6) and the specific screenshots needed by the PRD have
    been persisted elsewhere under docs/images/screenshots/ (step 7), the bulk
    keyframe working directory (for example docs/images/video_frames_5s/) is no
    longer needed and is removed. Only the keyframe working directory is deleted —
    final persisted artifacts (the video, transcript, PRD, selected screenshots,
    YouTube metadata/description/comments) live elsewhere and are untouched.

    This is a CLI tool. Its console output is intended output for the operator
    driving the skill, not debug noise.

.PARAMETER KeyframeDir
    Path to the keyframe working directory to delete (for example
    docs/images/video_frames_5s).

.PARAMETER RequiredNameHint
    Safety guard: the last path segment of -KeyframeDir must contain this
    substring (case-insensitive) or the script refuses to delete it. Defaults to
    'frame', which matches the skill's documented working-directory names
    (video_frames_5s, etc.) without hard-coding one exact name. Override only if
    your working directory legitimately uses a different naming convention.

.EXAMPLE
    ./cleanup-keyframes.ps1 -KeyframeDir docs/images/video_frames_5s
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KeyframeDir,

    [string]$RequiredNameHint = 'frame'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $KeyframeDir)) {
    Write-Host "Keyframe directory does not exist (already clean): $KeyframeDir"
    exit 0
}

$resolved = (Resolve-Path -LiteralPath $KeyframeDir).Path
$leaf = Split-Path -Path $resolved -Leaf

# Guard against nuking an unexpected path: refuse unless the directory name
# looks like a keyframe working directory, and refuse any path that resolves
# to a filesystem root.
if ($leaf -notmatch [regex]::Escape($RequiredNameHint)) {
    throw "Refusing to delete '$resolved' — its name does not contain the expected hint '$RequiredNameHint'. Pass -RequiredNameHint to override if this is intentional."
}

$pathRoot = [System.IO.Path]::GetPathRoot($resolved)
if ($resolved.TrimEnd('\', '/') -eq $pathRoot.TrimEnd('\', '/')) {
    throw "Refusing to delete '$resolved' — it resolves to a filesystem root."
}

Remove-Item -LiteralPath $resolved -Recurse -Force

if (Test-Path -LiteralPath $resolved) {
    throw "Cleanup failed: '$resolved' still exists after Remove-Item."
}

Write-Host "Deleted keyframe working directory: $resolved"
