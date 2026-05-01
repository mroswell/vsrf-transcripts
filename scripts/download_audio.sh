#!/usr/bin/env bash
# Download audio-only for every URL in urls.txt.
# Idempotent: yt-dlp's --download-archive records completed IDs and skips them on re-run.
# Writes a sidecar .info.json per video for metadata (date, duration, etc).
set -euo pipefail

cd "$(dirname "$0")/.."

URLS="${1:-urls.txt}"
mkdir -p audio videos_meta

yt-dlp \
  --impersonate Chrome \
  --batch-file "$URLS" \
  --download-archive audio/.archive \
  --no-overwrites \
  -f "ba/b" \
  --extract-audio \
  --audio-format mp3 \
  --audio-quality 5 \
  --write-info-json \
  --output "audio/%(upload_date)s_%(id)s.%(ext)s" \
  --output "infojson:videos_meta/%(upload_date)s_%(id)s.%(ext)s" \
  --restrict-filenames \
  --sleep-interval 1 --max-sleep-interval 4 \
  --retries 5 \
  --ignore-errors \
  --progress
