#!/usr/bin/env bash
# Probe a YouTube video's metadata without downloading it.
# Prints title, duration, id, uploader, and the raw chapters JSON so the caller can
# build a clean output slug and decide whether to offer chapter-based splitting.
#
# Usage: probe.sh "<url>"
set -uo pipefail

URL="${1:?usage: probe.sh <url>}"

COMMON=()
command -v node >/dev/null 2>&1 && COMMON+=(--js-runtimes node)
python -c "import curl_cffi" 2>/dev/null && COMMON+=(--impersonate chrome)

yt-dlp "${COMMON[@]}" --skip-download --no-warnings \
  --print "TITLE: %(title)s" \
  --print "DURATION: %(duration>%H:%M:%S)s" \
  --print "ID: %(id)s" \
  --print "UPLOADER: %(uploader)s" \
  --print "CHAPTERS: %(chapters)j" \
  "$URL"
