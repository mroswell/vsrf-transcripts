#!/usr/bin/env bash
# RunPod-side setup for vsrf-transcripts.
# Run this once after SSHing into a fresh PyTorch pod.
#
# Usage:
#   bash scripts/runpod_setup.sh
#
# Prerequisites set BEFORE running:
#   - HF_TOKEN env var (or paste token to tmp/hf_token.txt)
#   - GIT_REMOTE env var (e.g. git@github.com:mroswell/vsrf-transcripts.git) — only needed if
#     you didn't already clone via HTTPS

set -euo pipefail

echo ">>> apt deps (ffmpeg)"
apt-get update -qq
apt-get install -y -qq ffmpeg

echo ">>> python deps"
pip install --quiet --upgrade pip
pip install --quiet \
  whisperx \
  "yt-dlp[default,curl-cffi]" \
  pyannote.audio \
  hf_transfer

echo ">>> NLTK data (whisperx needs punkt_tab)"
python3 -c "import nltk; nltk.download('punkt_tab', quiet=True)"

echo ">>> HF token"
mkdir -p tmp
if [[ -n "${HF_TOKEN:-}" ]]; then
  echo "$HF_TOKEN" > tmp/hf_token.txt
  echo "    wrote tmp/hf_token.txt from \$HF_TOKEN"
elif [[ -s tmp/hf_token.txt ]]; then
  echo "    tmp/hf_token.txt already present"
else
  echo "    !! no token. Set \$HF_TOKEN or write tmp/hf_token.txt before running."
  exit 1
fi

echo ">>> sanity-check CUDA"
python3 -c "import torch; assert torch.cuda.is_available(), 'no CUDA'; print(f'    CUDA OK: {torch.cuda.get_device_name(0)}')"

echo ">>> done. Next: bash scripts/runpod_run.sh"
