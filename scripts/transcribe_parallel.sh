#!/usr/bin/env bash
# Transcribe audio files in parallel using whisper.
# Usage: bash scripts/transcribe_parallel.sh [-p NUM_PROCS]
# Default: 2 parallel processes (good for 8-core M-series Mac running other work).
set -euo pipefail

cd "$(dirname "$0")/.."

PROCS=2
while getopts "p:" opt; do
  case $opt in
    p) PROCS="$OPTARG" ;;
    *) echo "Usage: $0 [-p NUM_PROCS]" >&2; exit 1 ;;
  esac
done

MODEL="${WHISPER_MODEL:-small}"
LANG="${WHISPER_LANG:-en}"

mkdir -p transcripts

# Build list of audio files needing transcription
queue=()
for f in audio/*.mp3; do
  [[ -f "$f" ]] || continue
  base=$(basename "$f" .mp3)
  if [[ ! -s "transcripts/${base}.txt" ]]; then
    queue+=("$f")
  fi
done

total=${#queue[@]}
if [[ $total -eq 0 ]]; then
  echo "nothing to transcribe"
  exit 0
fi

echo "to transcribe: $total files, $PROCS parallel processes, model: $MODEL"

# Export for use in subshell
export MODEL LANG

printf '%s\n' "${queue[@]}" | xargs -P "$PROCS" -I {} bash -c '
  f="$1"
  base=$(basename "$f" .mp3)
  echo ">>> transcribing $base"
  python3 -m whisper "$f" \
    --model "$MODEL" \
    --language "$LANG" \
    --output_format all \
    --output_dir transcripts/ \
    --verbose False \
    --fp16 False
  echo "<<< done $base"
' _ {}
