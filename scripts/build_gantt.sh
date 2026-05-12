#!/usr/bin/env bash
# Generate a mermaid gantt chart of finished transcripts from file mtimes.
# Usage: bash scripts/build_gantt.sh [TRANSCRIPT_DIR] [OUT_FILE]
set -euo pipefail
cd "$(dirname "$0")/.."

TRANSCRIPT_DIR="${1:-livestreams_transcripts}"
OUT="${2:-tmp/transcription_timeline.mmd}"

mkdir -p "$(dirname "$OUT")"

{
  echo 'gantt'
  echo "    title Transcription Timeline ($TRANSCRIPT_DIR)"
  echo '    dateFormat YYYY-MM-DD HH:mm'
  echo '    axisFormat %m-%d %H:%M'
  echo ''
  echo "    section transcripts"

  prev_epoch=""
  # mtime in epoch seconds, then path; sort by epoch
  for f in "$TRANSCRIPT_DIR"/*.txt; do
    [[ -f "$f" ]] || continue
    epoch=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f")
    echo "$epoch|$f"
  done | sort -n | while IFS='|' read -r epoch path; do
    base=$(basename "$path" .txt)
    vid=${base#*_}
    # Pretty start time = previous transcript's finish time, or this one minus 60s for the first row
    if [[ -z "$prev_epoch" ]]; then
      start_epoch=$((epoch - 60))
      duration=1
    else
      start_epoch=$prev_epoch
      duration=$(( (epoch - prev_epoch) / 60 ))
      [[ $duration -lt 1 ]] && duration=1
    fi
    start_fmt=$(date -r "$start_epoch" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$start_epoch" "+%Y-%m-%d %H:%M")
    printf "    %-20s :%s, %dmin\n" "$vid" "$start_fmt" "$duration"
    prev_epoch=$epoch
  done
} > "$OUT"

echo "wrote $OUT ($(grep -c ^ "$OUT") lines)"
