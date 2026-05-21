---
name: video-acquisition
description: >
  Domain expertise for downloading a YouTube video locally at a resolution suitable for
  later frame OCR. Sub-skill of `youtube-extraction`. Use when the parent skill needs to
  acquire the source video file before any frame, transcript, or content analysis.
---

# Video Acquisition

Sub-skill of `youtube-extraction`. The parent skill calls this when it needs the
source video on disk. You receive `url` and `<basename>` from the caller.

## Goal

Place the video at:
```
docs/youtube-extraction/<basename>/video.<ext>
```
…at a resolution high enough for OCR of code and IDE chrome. Aim for 1080p when
available; accept 720p when the upload caps there.

## Why resolution matters

Frame OCR quality scales with pixel density. A 480p frame loses character
distinctions that are critical for code (`l` vs `1`, `O` vs `0`, `:` vs `;`). If
you accept a low-res download here, every downstream sub-skill pays for it.

## Primary command

```powershell
yt-dlp -f "bv*[height<=1080]+ba/b[height<=1080]" `
  --merge-output-format mp4 `
  -o "docs/youtube-extraction/<basename>/video.%(ext)s" `
  "<url>"
```

The format selector picks the best video stream up to 1080p plus the best
audio, falling back to a single 1080p-or-lower combined stream when separate
streams are unavailable. Merging into mp4 is friendlier to ffmpeg downstream.

## Also fetch metadata in the same pass

```powershell
yt-dlp --skip-download --write-info-json --write-description `
  -o "docs/youtube-extraction/<basename>/info.%(ext)s" `
  "<url>"
Move-Item -Force docs/youtube-extraction/<basename>/info.info.json `
  docs/youtube-extraction/<basename>/metadata.json
Move-Item -Force docs/youtube-extraction/<basename>/info.description `
  docs/youtube-extraction/<basename>/description.txt
```

`metadata.json` carries the title, channel, duration, publish date, view count,
and tags — every later sub-skill leans on these. `description.txt` often holds
the canonical repo URL and file paths the speaker references.

## Failure modes and fallbacks

| Symptom | Fallback |
|---------|----------|
| `Sign in to confirm you're not a bot` | Pass `--cookies-from-browser chrome` (or whichever browser the user is signed into YouTube on). |
| Live stream / premiere | Skip — extraction needs a finalised VOD. Surface a clear error. |
| Members-only / private | Authenticated cookies as above. If still blocked, surface to the user. |
| Age-restricted | `--cookies-from-browser` again. |
| 1080p unavailable | Drop to `bv*[height<=720]+ba/b[height<=720]`. Note the resolution drop in `EXTRACTION.md` later. |
| Multiple parts (chapters) | Single download — chapters are timestamps within one file. |

## Sanity checks before returning

- Confirm `video.<ext>` exists and is non-empty.
- Confirm `metadata.json` parses as JSON and has a `duration` field.
- Confirm the duration is sensible (> 0, < 6 hours for typical tutorials —
  longer is fine but warn).

## Idempotence

If `video.<ext>` already exists with non-zero size for the same `<basename>`, do
not re-download. Re-fetch metadata and description anyway, since channels can
edit those after upload.
