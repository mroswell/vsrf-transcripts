# Plan 04: Diarized videos batch on the RunPod pod

## Context

Of the 339 video transcripts in git, 338 are non-diarized (no
`[SPEAKER_XX]` labels). Now that the pod is paid for and warm, redo them
with whisperX + pyannote so the videos archive matches the livestreams.

## State entering this step

- Pod: `root@69.30.85.195:22025`, repo at `/workspace/vsrf-transcripts`
- `audio/` on pod: 339 mp3s rsync'd from laptop, ~5 GB. **No download
  needed.**
- `transcripts/` on pod: emptied (originals moved to
  `transcripts_backup_pod/`; laptop also has `transcripts_backup/`).
- Livestreams complete and pushed.
- Git push credentials configured (HTTPS + GitHub PAT).

## Settings (user request)

- `WHISPER_MODEL=medium` (up from `small`) — better accuracy on
  technical/medical jargon.
- `batch_size=32` (up from 16) — speed bump on the T4.

## Open question

Whether to also redo the 167 livestreams with `medium` for consistency.
Cost ~$6 + ~30 hr GPU time. Default: do videos first, decide on
livestreams after.

## Edits required

In `scripts/transcribe_one.py`:

```python
result = model.transcribe(audio, batch_size=32)
```

(Change `batch_size=16` to `batch_size=32`.)

## Commands on the pod's web terminal

```
cd /workspace/vsrf-transcripts
git pull   # to pick up the batch_size edit, once committed from laptop
export WHISPER_DEVICE=cuda
export WHISPER_MODEL=medium
nohup bash scripts/transcribe_parallel.sh -p 1 -a audio -t transcripts > videos.log 2>&1 &
tail -f videos.log
```

Skipping `runpod_run.sh` because it would also run `download_audio.sh`,
which would re-verify all 339 URLs against Rumble — slow and pointless
since audio is already on disk.

## Verification

1. `bash scripts/progress.sh audio transcripts` after ~5-10 min should
   show ≥ 1 done.
2. Spot-check first transcript for `[SPEAKER_00]` labels.
3. Final state: `339 of 339 done (100%)` and a new commit with all
   diarized transcripts.

## When it finishes

```
git add transcripts/
git commit -m "diarized video transcripts from runpod (medium model)"
git push
```

Then **tear down the pod** in the RunPod console.

## Cost

~30-40 hr T4 time at the medium model + batch_size=32. ~$6-8.
