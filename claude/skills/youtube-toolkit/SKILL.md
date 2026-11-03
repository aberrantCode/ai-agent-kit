---
name: youtube-toolkit
description: "Download, transcribe, clip, split-by-chapter, and splice YouTube videos. ALWAYS use this whenever the user pastes a YouTube or youtu.be link, or asks to download / save / rip / grab / clip / trim / cut / split / transcribe / caption a YouTube video, or to pull its description, chapters, or metadata, or to splice / stitch / interleave / mix clips from several chapter-split videos into one video — even if they don't say which of those they want. The skill's whole job is to take a link and ask, via the AskUserQuestion tool, which action(s) to perform, then run them with a hardened yt-dlp + ffmpeg pipeline that survives YouTube's rate limits and format defenses."
trigger: /youtube
category: Research & OSINT
version: 1.1.0
---

# YouTube Toolkit

Take a YouTube link, ask the user what they want done with it (via `AskUserQuestion`),
then do it. The point of this skill is that the user should be able to just drop a URL
and be offered a menu — they don't have to know or state the action up front.

The pipeline is hardened against the things that actually break YouTube downloads in
practice: a stale `yt-dlp`, hidden formats behind JS challenges, and the separately
rate-limited caption endpoint. Those lessons are baked into the bundled scripts — use
them rather than hand-rolling `yt-dlp` commands, so each run doesn't rediscover the
same failures.

## Workflow

### 0. Preflight (once per session)

Run the preflight check. `yt-dlp` breaks against YouTube frequently, so this keeps it
current and ensures the pieces that dodge YouTube's defenses are present.

```bash
bash ~/.claude/skills/youtube-toolkit/scripts/preflight.sh
```

It verifies `yt-dlp` / `ffmpeg` / `node`, auto-updates `yt-dlp` if it's stale, and
installs `curl_cffi` (needed for `--impersonate`, the main caption-429 workaround).

### 1. Normalize the URL and probe metadata

Strip tracking params (`?si=…`, playlist noise) down to the bare video URL. Then probe:

```bash
bash ~/.claude/skills/youtube-toolkit/scripts/probe.sh "<url>"
```

This prints title, duration, id, uploader, and the raw `chapters` JSON. You need this to
(a) craft a clean kebab-case `slug` for output filenames — YouTube titles contain
characters that become ugly fullwidth substitutes on disk — and (b) decide whether to
offer chapter-based splitting (only offer it if chapters exist).

### 2. Ask the user what to do — this is the core of the skill

Load the tool once: `ToolSearch` with `query: "select:AskUserQuestion"`.

Ask a **multiSelect** menu (the user may want several things). Tailor the options to
what the probe found. A good default:

- **Download video** — the full video file
- **Transcript (.srt)** — subtitles / captions
- **Description + metadata** — description text and the full info.json (includes chapters)
- **Split into sections** — cut the video into separate clips

`AskUserQuestion` allows at most four options per question, so splicing is not a fifth
menu item. Offer it instead when the user mentions mixing / stitching / combining clips
from several videos, or after a "Split into sections" run when they have given more than
one link ("Splice the sections of these videos into one mix?"). It is step 5 below.

Selecting all four is the "grab everything" path. If the probe showed **no chapters**,
reword the fourth option to "Extract a custom clip" since chapter-splitting won't apply.

Then ask **targeted follow-ups only for what they picked** (batch them in one
`AskUserQuestion` call, up to 4 questions):

- If **Download video** → single-select quality:
  `Best available` (Recommended) / `1080p` / `720p` / `Audio only (MP3)`.
  Warn briefly that "Best available" can be 4K and hundreds of MB.
- If **Split into sections** → single-select method:
  `By chapters — precise 1080p` (Recommended) / `By chapters — fast copy` / `Custom time range(s)`.
  See the cutting section below for the trade-off. Omit the chapter options if there
  are no chapters.

Recommend a default per question (first option, "(Recommended)") so the user can
one-click.

### 3. Execute the chosen actions

Pick a `slug` (e.g. `10-min-abs-workout`) and an output dir (default: a new folder named
after the slug in the current directory). Then run the fetch script with flags matching
the user's choices:

```bash
bash ~/.claude/skills/youtube-toolkit/scripts/download.sh "<url>" \
  --out "<slug>" --slug "<slug>" \
  --quality best \
  --video --desc --meta --subs
```

Flags: `--video --desc --meta --subs` (include only the ones chosen);
`--quality best|1080|720|audio`; `--sublang "en.*"` (default). The script deliberately
fetches the video/metadata first and subtitles in a **second pass** — see why in the
subtitle note below.

### 4. Split into sections (if chosen)

Chapter-based cutting is driven by the info.json, so `--meta` must have been fetched
(the download script pulls it automatically when `--video` is set). Generate the clip
plan and script:

```bash
python ~/.claude/skills/youtube-toolkit/scripts/generate-cuts.py --out "<slug>"
```

This writes `<slug>/chapters.txt` (a readable timestamp table) and
`<slug>/cut-chapters.sh` (one ffmpeg command per chapter, output to `<slug>/sections/`).
Run it in the mode the user picked:

```bash
cd "<slug>" && MODE=reencode bash cut-chapters.sh   # precise, 1080p H.264
cd "<slug>" && MODE=copy     bash cut-chapters.sh   # instant, keeps source quality
```

**copy vs reencode:** `copy` is instant and bit-for-bit but snaps cuts to the nearest
keyframe, so a clip can start up to a couple seconds early. `reencode` is frame-accurate
and produces smaller, universally-playable 1080p H.264 files, but must decode the source
— which is slow when the source is 4K AV1. Default to `reencode` for exact boundaries
unless the user wants speed or to preserve original quality. Pass
`--default-mode copy` to `generate-cuts.py` to make the generated script default to
`copy` when `MODE` is not set.

**Custom clip** (no chapters, or a one-off range): use ffmpeg directly. Seek before
`-i` for speed:

```bash
ffmpeg -y -ss 00:01:20 -to 00:02:20 -i "<slug>/<slug>.mp4" \
  -vf "scale=-2:1080" -c:v libx264 -crf 20 -preset medium -c:a aac -b:a 160k \
  "<slug>/sections/my-clip.mp4"
```

### 5. Splice clips from several split videos (if chosen)

Use this when the user wants **one video built from clips of several chapter-split
videos** (e.g. a mixed workout from abs + biceps + shoulders, a highlight reel, a
compilation). Each source video must already be split with step 4, so each has a
`sections/` folder. Ask via `AskUserQuestion` (one call, up to 4 questions):

- **Groups** — which split folders to mix, and a short label for each (the
  interleave order follows the order given).
- **Exclusions** — filename substrings to drop, e.g. intro / "get-ready" / outro /
  rest / hold clips. Offer the chapter titles from each `chapters.txt` as the choices.
- **Selection** — `All clips, in order` (Recommended) / `Random N per group`
  (optionally reproducible with a seed).
- **Output file** — path of the mixed mp4.

Then run (preview first with `--dry-run`, which prints the sequence and the ffmpeg
command without running anything):

```bash
python ~/.claude/skills/youtube-toolkit/scripts/splice_clips.py   --group abs=abs-workout --group arms=bicep-workout   --exclude get-ready --exclude intro   --pick 3 --seed 42   --out mix/spliced.mp4
```

Clips interleave round-robin (`abs1, arms1, abs2, arms2, ...`); when groups differ in
length the longer group's leftovers follow in order. Picks are re-sorted into source
order unless `--random-order`. Every input is normalised (scale/pad to 1080p, SAR 1,
30 fps, 48 kHz stereo) and re-encoded in one ffmpeg concat pass, so videos with
different fps (30 vs 29.97) or aspect ratios join cleanly. Needs ffmpeg on PATH
(or `pip install imageio-ffmpeg`). Full flag reference and caveats:
`references/splicing.md`.

## Subtitles: why the two-pass fetch

YouTube throttles the caption (`timedtext`) endpoint separately from video, returning
`HTTP 429 Too Many Requests`. If subtitles are requested in the same `yt-dlp` run as the
video, a caption 429 aborts the entire download — including the video. That's why
`download.sh` always fetches subtitles in their own pass.

If the subtitle pass 429s: it's IP-based throttling. `--impersonate chrome` (from
`curl_cffi`) helps but doesn't always override it. **Do not hammer it** — repeated
rapid attempts prolong the throttle. Wait a few minutes and re-run with just `--subs`.
Local transcription (Whisper) is a poor substitute for talk-sparse videos — see
`references/troubleshooting.md`.

## When things fail

Read `references/troubleshooting.md`. It covers the real failure signatures and fixes:
360p-only downloads, `HTTP 403`, "The page needs to be reloaded", PO-token / SABR
warnings, the caption 429, and when local Whisper transcription helps vs. hallucinates.
The short version: most extraction failures mean `yt-dlp` is out of date — update it
first (`preflight.sh --update`).

## Diagram

[View diagram](diagram.html)
