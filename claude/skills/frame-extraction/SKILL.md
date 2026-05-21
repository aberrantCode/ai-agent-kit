---
name: frame-extraction
description: >
  Domain expertise for slicing a downloaded YouTube video into image frames using ffmpeg —
  with sampling strategies tuned to the downstream task (file reconstruction, PRD evidence,
  diagram capture). Sub-skill of `youtube-extraction`.
---

# Frame Extraction

Sub-skill of `youtube-extraction`. You receive a path to the downloaded video,
`<basename>`, and a `mode` flag from the caller.

## Goal

Place individual frame images at:
```
docs/youtube-extraction/<basename>/frames/
```

…using a sampling strategy appropriate for the caller's mode. Frames are
disposable — `youtube-extraction` deletes this directory after the operation
completes.

## Why mode matters

Different downstream tasks need different sampling.

| Mode | Caller | Strategy | Why |
|------|--------|----------|-----|
| `file-reconstruction` | `/recreate-files` | Scene change + 1 fps cap | File panes scroll; you need enough overlap between frames to stitch lines, but not so many that OCR cost explodes. |
| `prd-evidence` | (other operations) | Fixed 5-second interval | PRD evidence wants a coarse, predictable index — every screen shown for ≥5s gets at least one frame. |
| `diagram-capture` | (other operations) | Scene change only | Diagrams are static — one frame per scene is enough. |

For `youtube-extraction`'s `recreate-files` operation, always use `file-reconstruction`.

## Strategy: file-reconstruction

```powershell
ffmpeg -i docs/youtube-extraction/<basename>/video.mp4 `
  -vf "select='gt(scene,0.2)+not(mod(n,30))',showinfo" `
  -vsync vfr `
  -q:v 2 `
  docs/youtube-extraction/<basename>/frames/frame_%05d.jpg
```

Decoded:
- `gt(scene,0.2)` — keep frames where the scene-change score exceeds 0.2.
  This catches IDE scrolls, slide transitions, terminal clears.
- `not(mod(n,30))` — also keep every 30th frame (≈1 fps at 30 fps source) so we
  have temporal anchors even during long static screens.
- `vsync vfr` — variable frame rate output so timestamps stay correct.
- `-q:v 2` — high JPEG quality (lower number = better). Code OCR is sensitive
  to compression artefacts; the storage cost is acceptable for tutorials.

## Strategy: prd-evidence (5-second interval)

For completeness, since other operations need it:

```powershell
ffmpeg -i docs/youtube-extraction/<basename>/video.mp4 `
  -vf "fps=1/5" `
  -q:v 3 `
  docs/youtube-extraction/<basename>/frames/frame_%05d.jpg
```

## Build a frame index

Whichever strategy you used, write `frames.index.json` alongside the frames
mapping `filename → seconds_into_video`. The downstream `frame-content-recognition`
sub-skill needs timestamps to cross-reference with the transcript.

```json
[
  { "file": "frame_00001.jpg", "t": 0.000 },
  { "file": "frame_00002.jpg", "t": 4.733 },
  …
]
```

You can derive timestamps from `ffprobe` or from ffmpeg's `showinfo` filter
output. Store seconds as a float; the parent skill formats `[mm:ss]` for
display.

## Performance notes

- **Resolution stays native.** Don't downscale — OCR is the bottleneck and
  you want every pixel ffmpeg gives you.
- **JPEG vs PNG.** JPEG with `-q:v 2` is fine for OCR and roughly 1/5th the
  disk of PNG. Use PNG only if the video is short (< 5 min) and you want
  pixel-perfect frames for screenshot reuse later.
- **Long videos.** A 60-minute tutorial in `file-reconstruction` mode can
  produce 1500–3000 frames. That's expected. The cleanup step at the end of
  the parent operation deletes them.

## Idempotence

If `frames/` already contains files matching the expected pattern and
`frames.index.json` exists, skip extraction unless the caller forces a refresh.

## What to surface back

- The frames directory path
- Path to `frames.index.json`
- Frame count and total duration covered
- Mode used
