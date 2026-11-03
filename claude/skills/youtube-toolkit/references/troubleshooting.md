# YouTube Toolkit — Troubleshooting

Real failure signatures seen against live YouTube, and what actually fixes them.
The recurring theme: **YouTube changes its defenses often, so an out-of-date `yt-dlp`
is the first suspect for almost any extraction failure.** Run
`scripts/preflight.sh --update` before deep debugging.

## Only 360p offered / "SABR-only" / formats missing a URL

Signature:
```
Some ... client https formats have been skipped as they are missing a URL.
YouTube may have enabled the SABR-only streaming experiment ...
```
and `-F` lists only format `18` (360p).

Cause: YouTube hides the high-quality DASH formats behind a JavaScript challenge (the
"n-challenge"). Without a JS runtime, `yt-dlp` can't solve it and falls back to the one
combined 360p stream.

Fix: install a JS runtime and pass it. `node` works well:
```
yt-dlp --js-runtimes node ...
```
`download.sh`/`probe.sh` already add `--js-runtimes node` when node is on PATH. If node
is missing, install Node.js (or Deno, which yt-dlp enables by default).

## HTTP 403 Forbidden / "The page needs to be reloaded" / PO-token warning

Signature: `ERROR: unable to download video data: HTTP Error 403`, or
`ERROR: ... The page needs to be reloaded`, or a warning about a required GVS PO Token.

Cause: usually a stale `yt-dlp`, sometimes an unlucky player client.

Fix, in order:
1. `scripts/preflight.sh --update` (this alone resolves most cases).
2. Retry — the default client set usually works once yt-dlp is current.
3. If it persists, try a different client:
   `--extractor-args "youtube:player_client=tv,web_safari"`. Note the `ios` client
   often needs a PO token and will 403 without one; don't rely on it.

## HTTP 429 on subtitles / captions

Signature: video downloads fine, but
`ERROR: Unable to download video subtitles for 'en': HTTP Error 429: Too Many Requests`.

Cause: YouTube rate-limits the caption (`timedtext`) endpoint separately and by IP.
It is easy to trip and, once tripped, **stays tripped for minutes** — and every rapid
retry resets that clock.

Fixes, in order:
1. `--impersonate chrome` (needs `curl_cffi`; preflight installs it). A real-browser
   TLS fingerprint sometimes clears it. `download.sh` adds this automatically.
2. **Wait.** Give it several minutes of genuine quiet — no repeated attempts — then
   re-run with only `--subs`. Patience beats hammering here; hammering is why it stays
   throttled.
3. Browser cookies (`--cookies-from-browser chrome`) can raise limits, but on recent
   Windows Chrome/Edge this frequently fails with a DPAPI / app-bound-encryption error
   and a locked cookie DB — don't count on it.

Note the two-pass design in `download.sh` exists precisely for this: subtitles are
fetched in their own run so a caption 429 never aborts the video download.

## Local transcription (Whisper) — when it helps, when it lies

If YouTube captions are truly unavailable and you have the audio, `faster-whisper` can
transcribe locally (IP-independent, no throttle):
```
ffmpeg -y -i "<slug>/<slug>.mp4" -vn -ac 1 -ar 16000 -c:a pcm_s16le audio.wav
python -c "from faster_whisper import WhisperModel as M; \
  m=M('small.en',device='cpu',compute_type='int8'); \
  segs,_=m.transcribe('audio.wav',language='en'); \
  open('out.txt','w',encoding='utf-8').write(' '.join(s.text.strip() for s in segs))"
```

**Caveat — Whisper hallucinates on talk-sparse audio.** On music-heavy videos (e.g. a
follow-along workout that's mostly a soundtrack with occasional cues), Whisper loops
phantom phrases like a repeated "I can do it" over silent/musical stretches. If the
authentic YouTube captions are mostly `[Music]`, that's the honest transcript — a local
ASR pass will invent speech that isn't there. Prefer the real captions; treat local
transcription as a fallback only for genuinely speech-dense content, and sanity-check
the output for repetition.

## Filenames look wrong (fullwidth characters)

YouTube titles contain characters illegal in filenames (`|`, `:`, `?`), which yt-dlp
replaces with fullwidth look-alikes (`｜`, `：`). That's cosmetic but awkward for
scripting. The skill sidesteps it by writing to a clean kebab-case `slug` via
`-o "<slug>.%(ext)s"` rather than `%(title)s`.

## Re-encode is slow

4K AV1 is a poor editing codec — decoding it to re-encode each clip is CPU-heavy. If the
cuts are taking too long and you don't need frame-accurate boundaries, use
`MODE=copy bash cut-chapters.sh` (instant, keyframe-snapped). Or download at `1080` /
`720` quality up front so there's less to decode later.
