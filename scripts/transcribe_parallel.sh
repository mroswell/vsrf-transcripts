#!/usr/bin/env bash
# Transcribe audio files in parallel using whisper.
# Usage: bash scripts/transcribe_parallel.sh [-p NUM_PROCS] [-l]
#   -p  Number of parallel processes (default: 2)
#   -l  Loop mode: after each batch, sleep 5 min and check for new files.
#       Exits when all URLs have transcripts.
set -euo pipefail

cd "$(dirname "$0")/.."

PROCS=2
LOOP=false
while getopts "p:l" opt; do
  case $opt in
    p) PROCS="$OPTARG" ;;
    l) LOOP=true ;;
    *) echo "Usage: $0 [-p NUM_PROCS] [-l]" >&2; exit 1 ;;
  esac
done

export WHISPER_MODEL="${WHISPER_MODEL:-small}"
export WHISPER_LANG="${WHISPER_LANG:-en}"

mkdir -p transcripts

transcribe_batch() {
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
    return 1  # nothing to do
  fi

  echo "to transcribe: $total files, $PROCS parallel processes, model: $WHISPER_MODEL"

  printf '%s\n' "${queue[@]}" | xargs -P "$PROCS" -I {} bash -c '
    f="$1"
    base=$(basename "$f" .mp3)
    echo ">>> transcribing $base"
    python3 scripts/transcribe_one.py "$f"
  ' _ {}
}

if [[ "$LOOP" == true ]]; then
  echo "loop mode: will check for new files every 5 minutes (ctrl-c to stop)"
  while true; do
    if transcribe_batch; then
      echo "[$(date +%H:%M)] batch complete"
    else
      echo "[$(date +%H:%M)] nothing to transcribe"
    fi
    echo "sleeping 5 minutes..."
    sleep 300
  done
else
  if ! transcribe_batch; then
    echo "nothing to transcribe"
  fi
fi
