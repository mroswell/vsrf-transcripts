#!/usr/bin/env bash
# Page through /c/VaccineSafetyResearchFoundation videos and livestreams tabs
# and collect every video URL.
# Output: urls.txt (one URL per line, deduped, sorted, previews filtered).
set -euo pipefail

cd "$(dirname "$0")/.."

CHANNEL="VaccineSafetyResearchFoundation"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

mkdir -p tmp/pages
: > tmp/all_urls.raw

# Scrape both the videos tab (src_v1_ucp_v) and livestreams tab (src_v1_ucp_l)
for tab in videos livestreams; do
  BASE="https://rumble.com/c/${CHANNEL}/${tab}"
  echo "=== scraping ${tab} ==="

  page=1
  while :; do
    url="${BASE}?page=${page}"
    out="tmp/pages/${tab}_p${page}.html"
    http=$(curl -sSL -A "$UA" -o "$out" -w '%{http_code}' "$url")
    if [[ "$http" != "200" ]]; then
      echo "  page $page: http=$http (end of pagination)"
      break
    fi

    found=$(grep -oE 'href="/v[a-zA-Z0-9]+[^"]*\.html\?e9s=src_v1_ucp_[vl]"' "$out" \
              | sed -E 's|href="(/[^"]+)"|https://rumble.com\1|' \
              | sort -u || true)

    count=$(printf '%s\n' "$found" | grep -c . || true)
    echo "  page $page: $count videos"

    if [[ "$count" -eq 0 ]]; then
      break
    fi

    printf '%s\n' "$found" >> tmp/all_urls.raw
    page=$((page + 1))

    if [[ $page -gt 50 ]]; then
      echo "  page cap reached" >&2
      break
    fi
  done
done

# Dedupe, strip the source param, and filter out preview/promo videos.
sort -u tmp/all_urls.raw \
  | sed -E 's|\?e9s=[^"]*$||' \
  | sort -u \
  | grep -iv '/.*preview' > urls.txt

echo "---"
echo "total unique videos: $(wc -l < urls.txt) (after filtering previews)"
