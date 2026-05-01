#!/usr/bin/env bash
# Commit and push new transcripts and metadata to GitHub.
# Safe to call when there are no changes — it simply exits.
set -euo pipefail

cd "$(dirname "$0")/.."

git add transcripts/ videos_meta/ urls.txt
if ! git diff --cached --quiet; then
  git commit -m "weekly refresh: $(date +%F)"
  git push origin main
else
  echo "git_sync: nothing new to commit"
fi
