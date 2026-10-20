<#
.SYNOPSIS
    Extract a frame every 5 seconds from an input video and build a timestamp index.

.DESCRIPTION
    Implements workflow step 5 of the youtube-prd-forensics skill: given the video
    persisted in step 2, extract one keyframe approximately every 5 seconds into a
    working directory, and write an index file mapping each frame filename to its
    timestamp so later analysis and PRD-writing steps can cite exact moments in the
    source video.

    This is a CLI tool. Its console output (progress lines, the final frame count)
    is intended output for the operator driving the skill, not debug noise.

.PARAMETER VideoPath
    Path to the source video file (for example
    docs/<project>_reference_1080p.mp4) produced by the skill's download step.

.PARAMETER OutputDir
    Directory keyframes and the index file are written into (for example
    docs/images/video_frames_5s). Created if it does not already exist.

.PARAMETER IntervalSeconds
    Seconds between extracted frames. Defaults to 5, matching the skill's workflow.

.EXAMPLE
    ./extract-keyframes-5s.ps1 -VideoPath docs/demo_reference_1080p.mp4 -OutputDir docs/images/video_frames_5s
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VideoPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDir,

    [int]$IntervalSeconds = 5
)

$ErrorActionPreference = 'Stop'

function Get-FfmpegCommand {
    $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "ffmpeg was not found on PATH. Install ffmpeg before running this script."
    }
    return $cmd.Source
}

if (-not (Test-Path -LiteralPath $VideoPath -PathType Leaf)) {
    throw "Input video not found: $VideoPath"
}

if ($IntervalSeconds -le 0) {
    throw "IntervalSeconds must be a positive number, got: $IntervalSeconds"
}

$ffmpeg = Get-FfmpegCommand

$resolvedVideoPath = (Resolve-Path -LiteralPath $VideoPath).Path

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$resolvedOutputDir = (Resolve-Path -LiteralPath $OutputDir).Path

Write-Host "Extracting keyframes every $IntervalSeconds second(s) from: $resolvedVideoPath"
Write-Host "Output directory: $resolvedOutputDir"

# Frame filename pattern: frame_0001.jpg, frame_0002.jpg, ...
$framePattern = Join-Path $resolvedOutputDir 'frame_%04d.jpg'

# fps=1/<interval> samples one frame every <interval> seconds, starting at t=0.
$fpsExpr = "fps=1/$IntervalSeconds"

& $ffmpeg -y -i $resolvedVideoPath -vf $fpsExpr -vsync vfr -q:v 2 $framePattern 2>&1 |
    ForEach-Object { Write-Verbose $_ }

if ($LASTEXITCODE -ne 0) {
    throw "ffmpeg exited with code $LASTEXITCODE while extracting keyframes."
}

$frameFiles = Get-ChildItem -LiteralPath $resolvedOutputDir -Filter 'frame_*.jpg' |
    Sort-Object Name

if ($frameFiles.Count -eq 0) {
    throw "ffmpeg produced no keyframes. Check that the input video is valid and non-empty."
}

$indexPath = Join-Path $resolvedOutputDir 'keyframe_index.csv'
$indexRows = for ($i = 0; $i -lt $frameFiles.Count; $i++) {
    $timestampSeconds = $i * $IntervalSeconds
    $timestamp = [TimeSpan]::FromSeconds($timestampSeconds).ToString('hh\:mm\:ss')
    [PSCustomObject]@{
        frame_file = $frameFiles[$i].Name
        timestamp_seconds = $timestampSeconds
        timestamp = $timestamp
    }
}

$indexRows | Export-Csv -LiteralPath $indexPath -NoTypeInformation -Encoding UTF8

Write-Host "Wrote $($frameFiles.Count) keyframe(s) and index: $indexPath"
