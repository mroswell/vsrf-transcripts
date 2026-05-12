# Plan 06: Push videos, then redo livestreams with medium

## Context

All 339 video transcripts are done on the pod with the `medium` model.
Next: push them, then redo the 167 livestreams (currently in git as
`small`-model output) with `medium` for archive consistency.

## Step 1 — Push videos (on the pod)

```bash
cd /workspace/vsrf-transcripts
git add transcripts/
git commit -m "diarized video transcripts from runpod (medium model)"
git push
```

## Step 2 — Redo livestreams with medium

Audio is already on the pod from the original run, so no re-download.
Move the old (small-model) transcripts out of the way — they're safe in
git history.

```bash
mv livestreams_transcripts livestreams_transcripts_small
mkdir livestreams_transcripts
export WHISPER_DEVICE=cuda
export WHISPER_MODEL=medium
nohup bash scripts/transcribe_parallel.sh -p 1 -a livestreams_audio -t livestreams_transcripts > livestreams_v2.log 2>&1 &
tail -f livestreams_v2.log
```

Monitor:

```bash
bash scripts/progress.sh livestreams_audio livestreams_transcripts
```

Estimated: ~14-28 hours, ~$3-6.

## When that finishes

```bash
rm -rf livestreams_transcripts_small   # optional; small versions remain in git history
git add livestreams_transcripts/
git commit -m "diarized livestream transcripts from runpod (medium model)"
git push
```

Then **tear down the pod** in the RunPod console.
