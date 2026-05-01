#!/usr/bin/env bash
# Report pipeline progress: per-video status with title, date, and completion.
# Reads videos_meta/*.info.json for metadata, checks audio/ and transcripts/ for completion.
set -euo pipefail

cd "$(dirname "$0")/.."

# Count URLs not yet downloaded (no .info.json)
total_urls=$(wc -l < urls.txt | tr -d ' ')
meta_count=$(find videos_meta -name '*.info.json' 2>/dev/null | wc -l | tr -d ' ')
audio_count=$(find audio -name '*.mp3' 2>/dev/null | wc -l | tr -d ' ')
transcript_count=$(find transcripts -name '*.txt' 2>/dev/null | wc -l | tr -d ' ')

echo "=== VSRF Pipeline Status ==="
echo "URLs in list:    $total_urls"
echo "Downloaded:      $audio_count"
echo "Transcribed:     $transcript_count"
echo "Metadata files:  $meta_count"
echo ""

# Per-video detail from info.json
printf "%-12s  %-11s  %-6s  %-11s  %s\n" "DATE" "ID" "AUDIO" "TRANSCRIPT" "TITLE"
printf "%-12s  %-11s  %-6s  %-11s  %s\n" "----" "--" "-----" "----------" "-----"

python3 -c "
import json, glob, os, sys

rows = []
for path in sorted(glob.glob('videos_meta/*.info.json')):
    with open(path) as f:
        info = json.load(f)
    vid_id = info.get('id', '?')
    title = info.get('title', '(no title)')
    date_raw = info.get('upload_date', '????????')
    date_fmt = f'{date_raw[:4]}-{date_raw[4:6]}-{date_raw[6:8]}' if len(date_raw) == 8 else date_raw
    base = os.path.basename(path).replace('.info.json', '')
    has_audio = 'yes' if os.path.isfile(f'audio/{base}.mp3') else 'no'
    has_txt = 'yes' if os.path.isfile(f'transcripts/{base}.txt') else 'no'
    rows.append((date_fmt, vid_id, has_audio, has_txt, title))

rows.sort()
for date_fmt, vid_id, has_audio, has_txt, title in rows:
    # Truncate title to 60 chars for readability
    short_title = (title[:57] + '...') if len(title) > 60 else title
    print(f'{date_fmt:12}  {vid_id:11}  {has_audio:6}  {has_txt:11}  {short_title}')
"

# Show count of URLs without metadata yet
not_downloaded=$((total_urls - meta_count))
if [[ $not_downloaded -gt 0 ]]; then
  echo ""
  echo "$not_downloaded URLs not yet downloaded (no metadata available)"
fi
