---
name: transcript-acquisition
description: >
  Domain expertise for obtaining a timestamped transcript of a YouTube video — first via
  YouTube's own auto-subs/CC, falling back to local Whisper transcription of the downloaded
  video. Sub-skill of `youtube-extraction`. Use when the parent skill needs spoken-word
  evidence aligned to timestamps.
---

# Transcript Acquisition

Sub-skill of `youtube-extraction`. You receive `url`, `<basename>`, and a path
to the already-downloaded local video.

## Goal

Place a timestamped transcript at:
```
docs/youtube-extraction/<basename>/transcript.md
```

Format: a markdown document where each line is `**[mm:ss]** spoken text`. This
is what downstream sub-skills grep against — keep it scannable.

## Why both sources

YouTube auto-subs are fast and free but uneven for technical content (function
names, library names, file paths get mangled). Whisper on the local file is
slower but typically more accurate for code-related terminology. Try YouTube
first; if subs are missing or obviously low-quality, fall back to Whisper.

## Step 1 — try YouTube subtitles first

```powershell
yt-dlp --skip-download --write-auto-subs --write-subs --sub-langs "en.*" `
  --sub-format "vtt" `
  -o "docs/youtube-extraction/<basename>/yt.%(ext)s" `
  "<url>"
```

If a `.vtt` file lands, parse it into the markdown format above. Drop the
WEBVTT header, drop styling cue settings, and merge consecutive cues that share
overlapping text (auto-subs frequently emit rolling 2-line cues that
double-count words).

## Step 2 — fallback to Whisper

If no subs were written, transcribe the local video. Prefer `whisper.cpp` for
speed when available; otherwise `openai-whisper`.

```powershell
# whisper.cpp
whisper-cli -m models/ggml-medium.en.bin `
  -f docs/youtube-extraction/<basename>/video.mp4 `
  -of docs/youtube-extraction/<basename>/transcript `
  --output-vtt
```

```powershell
# openai-whisper
whisper docs/youtube-extraction/<basename>/video.mp4 `
  --model medium.en --output_format vtt `
  --output_dir docs/youtube-extraction/<basename>/
```

Then convert the VTT to the markdown format above.

## Step 3 — heuristic: did YouTube give us garbage?

If YouTube returned subs but they look low-quality, redo with Whisper. Cheap
heuristics that suggest auto-sub failure:

- > 5% of the captioned tokens are `[Music]`, `[Applause]`, or `inaudible`.
- The video has fewer than 100 captioned words but is longer than 5 minutes.
- The channel title or description suggests a non-English speaker but
  `--sub-langs "en.*"` returned only auto-translated English.

## Output normalisation

Whatever source you used, the transcript file ends as a single markdown file
with this shape:

```markdown
# Transcript — <video title>

Source: <youtube auto-subs | whisper-cpp medium.en | openai-whisper medium.en>

**[00:00]** opening words
**[00:04]** next line
…
```

Group lines into 1-3 second windows; longer windows are fine for slow speech
but avoid 30-second mega-cues — downstream evidence-mapping needs sub-minute
resolution.

## Idempotence

If `transcript.md` already exists for `<basename>`, do not re-transcribe unless
the caller explicitly forces a refresh (Whisper on a long video is slow). If
you do refresh, retain the previous transcript at `transcript.prev.md`.

## What to surface back to the parent skill

- Path to `transcript.md`
- Source used (`youtube-auto-subs` | `youtube-manual-subs` | `whisper-cpp` | `whisper`)
- Caveat flags (low confidence, partial coverage)
