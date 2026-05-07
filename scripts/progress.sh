#!/usr/bin/env bash
# Quick progress check for transcription.
# Usage: bash scripts/progress.sh [AUDIO_DIR] [TRANSCRIPT_DIR]
AUDIO_DIR="${1:-livestreams_audio}"
TRANSCRIPT_DIR="${2:-livestreams_transcripts}"

LATEST=$(basename "$(ls -t "$TRANSCRIPT_DIR"/*.txt | head -1)" .txt | cut -d_ -f2)
echo "[$(date +%H:%M)] $(ls "$TRANSCRIPT_DIR"/*.txt | wc -l) of $(ls "$AUDIO_DIR"/*.mp3 | wc -l) done ($(( $(ls "$TRANSCRIPT_DIR"/*.txt | wc -l) * 100 / $(ls "$AUDIO_DIR"/*.mp3 | wc -l) ))%) — latest: $LATEST"
