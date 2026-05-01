#!/usr/bin/env bash
# Page through /c/VaccineSafetyResearchFoundation/videos and collect every video URL.
# Output: vsrf-pipeline/urls.txt (one URL per line, deduped, sorted).
# Excludes shorts (the /videos tab already excludes them) and the playlist sidebar entries.
set -euo pipefail

cd "$(dirname "$0")/.."

CHANNEL="VaccineSafetyResearchFoundation"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
BASE="https://rumble.com/c/${CHANNEL}/videos"

mkdir -p tmp/pages
: > tmp/all_urls.raw

page=1
while :; do
  url="${BASE}?page=${page}"
  out="tmp/pages/p${page}.html"
  http=$(curl -sSL -A "$UA" -o "$out" -w '%{http_code}' "$url")
  if [[ "$http" != "200" ]]; then
    echo "page $page: http=$http (end of pagination)"
    break
  fi

  # `src_v1_ucp_v` = "user channel page videos tab" — only match videos in this tab,
  # excluding `src_v1_shorts_lnb_i` (shorts in left-nav) and other embeds.
  found=$(grep -oE 'href="/v[a-zA-Z0-9]+[^"]*\.html\?e9s=src_v1_ucp_v"' "$out" \
            | sed -E 's|href="(/[^"]+)"|https://rumble.com\1|' \
            | sort -u || true)

  count=$(printf '%s\n' "$found" | grep -c . || true)
  echo "page $page: $count videos"

  if [[ "$count" -eq 0 ]]; then
    break
  fi

  printf '%s\n' "$found" >> tmp/all_urls.raw
  page=$((page + 1))

  # Safety cap.
  if [[ $page -gt 50 ]]; then
    echo "page cap reached" >&2
    break
  fi
done

# Dedupe, strip the source param, and filter out preview/promo videos.
sort -u tmp/all_urls.raw \
  | sed -E 's|\?e9s=[^"]*$||' \
  | sort -u \
  | grep -iv '/.*preview' > urls.txt

echo "---"
echo "total unique videos: $(wc -l < urls.txt) (after filtering previews)"
