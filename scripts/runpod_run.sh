#!/usr/bin/env bash
# RunPod-side runner: download remaining livestreams, transcribe on GPU, push results.
#
# Idempotent — safe to re-run after interruption. Uses yt-dlp's download archive
# and skips files that already have a .txt transcript.
#
# Usage:
#   bash scripts/runpod_run.sh                # livestreams (default)
#   bash scripts/runpod_run.sh urls.txt audio transcripts   # videos
set -euo pipefail
cd "$(dirname "$0")/.."

URLS="${1:-livestream_urls.txt}"
AUDIO_DIR="${2:-livestreams_audio}"
TRANSCRIPT_DIR="${3:-livestreams_transcripts}"

export WHISPER_DEVICE=cuda
export WHISPER_MODEL="${WHISPER_MODEL:-small}"
export WHISPER_LANG="${WHISPER_LANG:-en}"

mkdir -p "$AUDIO_DIR" "$TRANSCRIPT_DIR"

echo "===> [1/3] download missing audio with yt-dlp"
bash scripts/download_audio.sh "$URLS" "$AUDIO_DIR"

echo "===> [2/3] transcribe on GPU (single process; whisperX uses the whole card)"
bash scripts/transcribe_parallel.sh -p 1 -a "$AUDIO_DIR" -t "$TRANSCRIPT_DIR"

echo "===> [3/3] commit and push transcripts"
git config user.email "${GIT_EMAIL:-runpod@vsrf-transcripts.local}"
git config user.name "${GIT_NAME:-runpod}"
git add "$TRANSCRIPT_DIR"
if ! git diff --cached --quiet; then
  git commit -m "transcripts batch from runpod ($(date -u +%Y-%m-%dT%H:%MZ))"
  git push origin main
else
  echo "    no new transcripts to commit"
fi

echo ">>> all done"
