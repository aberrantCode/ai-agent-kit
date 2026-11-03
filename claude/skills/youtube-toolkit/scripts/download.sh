#!/usr/bin/env bash
# Robust YouTube fetch: video / audio / description / metadata / subtitles.
#
# Key design decision - TWO PASSES:
#   Pass 1 pulls the video (or audio) plus description and info.json.
#   Pass 2 pulls subtitles in a SEPARATE yt-dlp run.
# YouTube throttles the caption (timedtext) endpoint independently with HTTP 429. If
# subtitles are requested in the same run as the video, a caption 429 aborts the whole
# download - so we isolate subtitles to their own pass. A failed subtitle pass then
# never costs you the video.
#
# Usage:
#   download.sh "<url>" [--out DIR] [--slug NAME] [--quality best|1080|720|audio]
#                       [--video] [--desc] [--meta] [--subs] [--sublang "en.*"]
# Include only the content flags you want. Example - grab everything at best quality:
#   download.sh "<url>" --out abs --slug abs --quality best --video --desc --meta --subs
set -uo pipefail

URL=""; OUT="."; SLUG="video"; QUALITY="best"; SUBLANG="en.*"
DO_VIDEO=0; DO_DESC=0; DO_META=0; DO_SUBS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --out)     OUT="$2"; shift 2;;
    --slug)    SLUG="$2"; shift 2;;
    --quality) QUALITY="$2"; shift 2;;
    --sublang) SUBLANG="$2"; shift 2;;
    --video)   DO_VIDEO=1; shift;;
    --desc)    DO_DESC=1; shift;;
    --meta)    DO_META=1; shift;;
    --subs)    DO_SUBS=1; shift;;
    http*|https*) URL="$1"; shift;;
    *) echo "unknown arg: $1" >&2; shift;;
  esac
done

[ -n "$URL" ] || { echo "usage: download.sh <url> --video|--desc|--meta|--subs [--quality ...] [--out DIR] [--slug NAME]" >&2; exit 1; }
if [ "$DO_VIDEO" = 0 ] && [ "$DO_DESC" = 0 ] && [ "$DO_META" = 0 ] && [ "$DO_SUBS" = 0 ]; then
  echo "nothing to do: pass at least one of --video --desc --meta --subs" >&2; exit 1
fi
mkdir -p "$OUT"

# Common flags: a JS runtime unlocks full-quality formats; impersonation dodges some
# 429/403 defenses. Both are added only if available so the script still runs without them.
COMMON=(--retries 10)
command -v node >/dev/null 2>&1 && COMMON+=(--js-runtimes node)
python -c "import curl_cffi" 2>/dev/null && COMMON+=(--impersonate chrome)

case "$QUALITY" in
  best)  FMT=(-f "bestvideo*+bestaudio/best" --merge-output-format mp4);;
  1080)  FMT=(-f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" --merge-output-format mp4);;
  720)   FMT=(-f "bestvideo[height<=720]+bestaudio/best[height<=720]" --merge-output-format mp4);;
  audio) FMT=(-x --audio-format mp3 --audio-quality 0);;
  *) echo "unknown quality: $QUALITY (use best|1080|720|audio)" >&2; exit 1;;
esac

# ---- Pass 1: video/audio + description + metadata (no subs) ------------------
if [ "$DO_VIDEO" = 1 ] || [ "$DO_DESC" = 1 ] || [ "$DO_META" = 1 ]; then
  ARGS=("${COMMON[@]}")
  if [ "$DO_VIDEO" = 1 ]; then
    ARGS+=("${FMT[@]}")
    [ "$QUALITY" != "audio" ] && ARGS+=(--embed-chapters)
  else
    ARGS+=(--skip-download)
  fi
  [ "$DO_DESC" = 1 ] && ARGS+=(--write-description)
  [ "$DO_META" = 1 ] && ARGS+=(--write-info-json)
  echo ">> Pass 1: video/metadata (quality=$QUALITY)"
  yt-dlp "${ARGS[@]}" -o "$OUT/$SLUG.%(ext)s" "$URL"
fi

# ---- Pass 2: subtitles (isolated so a caption 429 can't kill the video) ------
if [ "$DO_SUBS" = 1 ]; then
  echo ">> Pass 2: subtitles ($SUBLANG)"
  if yt-dlp "${COMMON[@]}" --skip-download \
        --write-subs --write-auto-subs --sub-langs "$SUBLANG" --convert-subs srt \
        --retry-sleep 10 -o "$OUT/$SLUG.%(ext)s" "$URL"; then
    :
  else
    echo "!! Subtitle fetch failed - almost always HTTP 429 on YouTube's caption endpoint." >&2
    echo "   This is IP-based throttling. Do NOT retry immediately (it prolongs the throttle)." >&2
    echo "   Wait a few minutes, then re-run with just --subs. See references/troubleshooting.md." >&2
  fi
fi

echo "Done -> $OUT/"
ls -la "$OUT"
