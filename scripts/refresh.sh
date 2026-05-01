#!/usr/bin/env bash
# One command to pull new videos and transcribe them.
#   1. Re-scrape /videos to catch new uploads.
#   2. Download audio for any IDs not already in audio/.archive.
#   3. Transcribe any audio file lacking a transcript.
# Safe to run repeatedly (cron, manual, etc.) — every step is idempotent.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== [1/4] scraping channel ==="
bash scripts/scrape_urls.sh

echo
echo "=== [2/4] downloading new audio ==="
bash scripts/download_audio.sh urls.txt

echo
echo "=== [3/4] transcribing ==="
bash scripts/transcribe_parallel.sh

echo
echo "=== [4/4] syncing to git ==="
bash scripts/git_sync.sh

echo
echo "done. run 'bash scripts/report.sh' for status."
