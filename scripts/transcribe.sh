#!/usr/bin/env bash
# Transcribe every audio file that doesn't yet have a transcript.
# Output: transcripts/<basename>.txt + .json (with timestamps)
# Idempotent: skips files where the .txt already exists.
set -euo pipefail

cd "$(dirname "$0")/.."

MODEL="${WHISPER_MODEL:-small}"  # tiny|base|small|medium|large — small balances quality/speed and is already cached locally
LANG="${WHISPER_LANG:-en}"

mkdir -p transcripts

shopt -s nullglob
total=0; done=0; todo=0
for f in audio/*.mp3; do
  total=$((total+1))
  base=$(basename "$f" .mp3)
  out="transcripts/${base}.txt"
  if [[ -s "$out" ]]; then
    done=$((done+1))
    continue
  fi
  todo=$((todo+1))
done
echo "audio files: $total  already transcribed: $done  to do: $todo  model: $MODEL"

# Sort by file size ascending so short clips finish first and you see progress quickly.
ls -Sr audio/*.mp3 2>/dev/null | while read -r f; do
  base=$(basename "$f" .mp3)
  out_txt="transcripts/${base}.txt"
  if [[ -s "$out_txt" ]]; then
    continue
  fi
  echo ">>> transcribing $base"
  python3 scripts/transcribe_one.py "$f"
done
