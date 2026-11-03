#!/usr/bin/env bash
# Ensure the YouTube toolchain is ready. Idempotent; safe to run every session.
#
# Why this exists: yt-dlp breaks against YouTube constantly (YouTube keeps changing
# its extraction defenses), so the single most common cause of a failed download is a
# stale yt-dlp. This keeps it fresh and installs the pieces that dodge those defenses.
#
# Usage: preflight.sh [--update]   (--update forces a yt-dlp upgrade regardless of age)
set -uo pipefail

FORCE_UPDATE=0
[ "${1:-}" = "--update" ] && FORCE_UPDATE=1

if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "ERROR: yt-dlp not found. Install with:" >&2
  echo "  python -m pip install -U yt-dlp curl_cffi" >&2
  exit 1
fi

ver="$(yt-dlp --version 2>/dev/null)"   # yt-dlp versions are dates: YYYY.MM.DD
echo "yt-dlp: $ver"

# Auto-update if stale (>45 days) or forced. YouTube extraction rots fast, so a
# month-and-a-half-old build is already a liability.
stale=0
if [ "$FORCE_UPDATE" = 1 ]; then
  stale=1
else
  vy="${ver%%.*}"; rest="${ver#*.}"; vm="${rest%%.*}"; vd="${rest#*.}"
  if [ -n "${vy:-}" ] && [ -n "${vm:-}" ] && [ -n "${vd:-}" ]; then
    then_epoch=$(python -c "import datetime,sys;print(int(datetime.datetime(int(sys.argv[1]),int(sys.argv[2]),int(sys.argv[3])).timestamp()))" "$vy" "$vm" "$vd" 2>/dev/null || echo 0)
    now_epoch=$(python -c "import time;print(int(time.time()))")
    if [ "$then_epoch" -gt 0 ]; then
      age_days=$(( (now_epoch - then_epoch) / 86400 ))
      echo "  (build is ~${age_days} days old)"
      [ "$age_days" -gt 45 ] && stale=1
    fi
  fi
fi
if [ "$stale" = 1 ]; then
  echo "Updating yt-dlp..."
  python -m pip install -U -q yt-dlp && echo "yt-dlp now: $(yt-dlp --version)"
fi

# curl_cffi enables --impersonate <browser>, which sends a real-browser TLS
# fingerprint. This is the main workaround for the caption-endpoint 429 and some
# format 403s.
if python -c "import curl_cffi" 2>/dev/null; then
  echo "curl_cffi: present (--impersonate available)"
else
  echo "Installing curl_cffi (enables --impersonate)..."
  python -m pip install -q curl_cffi && echo "curl_cffi: installed"
fi

# ffmpeg merges separate video+audio streams and does all the clipping.
if command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg: $(ffmpeg -version 2>/dev/null | head -n1 | cut -d' ' -f1-3)"
else
  echo "WARNING: ffmpeg not found - required to merge streams and cut clips." >&2
fi

# A JS runtime lets yt-dlp solve YouTube's 'n-challenge' and reach the full,
# high-quality formats instead of a lone 360p fallback.
if command -v node >/dev/null 2>&1; then
  echo "node: $(node --version) (JS runtime available)"
else
  echo "WARNING: node not found - without a JS runtime YouTube may only expose 360p." >&2
fi

echo "Preflight OK."
