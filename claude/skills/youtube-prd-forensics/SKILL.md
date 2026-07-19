---
name: youtube-prd-forensics
category: Research & OSINT
description: Create or update a detailed Product Requirements Document from a YouTube demo video using evidence-first analysis. Use when the user wants reproducible requirements tied to timestamps, transcript/description/comments, keyframe evidence, and embedded screenshots persisted in the project.
---

# YouTube PRD Forensics

## Workflow

Execute this workflow in order.

1. Prepare output locations under `docs/`.
2. Download and persist the source video locally.
3. Extract YouTube page artifacts (description, metadata, comments, transcript/subtitles).
4. Generate transcript from local video if YouTube transcript is missing.
5. Extract keyframes at 5-second intervals and build an index.
6. Analyze keyframes and transcript together to derive requirements.
7. Persist high-resolution screenshots for specific requirements.
8. Update or write `docs/PRD.md` with timestamped requirements and embedded images.
9. Delete keyframes and retain only final artifacts.

Use `references/prd-evidence-checklist.md` as the completion gate.

## Required Persisted Artifacts

Keep these files:

- `docs/<project>_reference_1080p.<ext>` (downloaded video)
- `docs/transcript_notes.md` (curated transcript with timestamps)
- `docs/PRD.md` (final requirements document)
- `docs/images/screenshots/*` (selected full-frame or cropped screenshots used by PRD)
- `docs/youtube_metadata.json`
- `docs/youtube_description.txt`
- `docs/youtube_comments.json`

Delete temporary keyframes at the end (for example `docs/images/video_frames_5s/`).

## Commands

Run these commands from repo root. Replace `<YOUTUBE_URL>` and `<BASENAME>`.

1. Download video:
```powershell
yt-dlp -f "bv*[height<=1080]+ba/b[height<=1080]" `
  -o "docs/<BASENAME>_reference_1080p.%(ext)s" "<YOUTUBE_URL>"
```

2. Extract page metadata, description, comments:
```powershell
yt-dlp --skip-download --write-info-json --write-description --write-comments `
  -o "docs/youtube.%(ext)s" "<YOUTUBE_URL>"
Move-Item -Force docs/youtube.info.json docs/youtube_metadata.json
Move-Item -Force docs/youtube.description docs/youtube_description.txt
Move-Item -Force docs/youtube.comments.json docs/youtube_comments.json
```

3. Extract transcript/subtitles from YouTube when available:
```powershell
yt-dlp --skip-download --write-auto-subs --write-subs --sub-langs "en.*" `
  --sub-format "vtt" -o "docs/youtube.%(ext)s" "<YOUTUBE_URL>"
```

4. If transcript is unavailable, generate it from local video (tool-dependent; whisper/whisper.cpp acceptable). Always output `docs/transcript_notes.md`.

5. Extract 5-second keyframes and index:
```powershell
powershell -ExecutionPolicy Bypass -File `
  "skills/youtube-prd-forensics/scripts/extract-keyframes-5s.ps1" `
  -VideoPath "docs/<BASENAME>_reference_1080p.mp4" `
  -OutputDir "docs/images/video_frames_5s"
```

6. Cleanup temporary keyframes after PRD completion:
```powershell
powershell -ExecutionPolicy Bypass -File `
  "skills/youtube-prd-forensics/scripts/cleanup-keyframes.ps1" `
  -KeyframeDir "docs/images/video_frames_5s"
```

## PRD Content Requirements

Enforce all of the following in `docs/PRD.md`:

- Include source metadata: video URL, title, creator, publish date, duration, description summary, notable comments.
- Include requirement sections that map features/behaviors to explicit timestamps.
- Embed screenshots under each major requirement section.
- Distinguish observed facts from inferred requirements.
- Capture UI controls, data sources, layer toggles, failure states, and workflow behavior shown in the video.
- End with a modification/change-summary table whenever editing an existing PRD.

## Screenshot Guidance

- Save screenshots into `docs/images/screenshots/`.
- Use full keyframes when context matters.
- Use cropped images when isolating a control/feature is clearer.
- Name files descriptively with numeric prefixes (for stable PRD references), for example `01_hud_overview.jpg`.

## Diagram

[View diagram](diagram.html)
