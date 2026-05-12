---
description: Set up a YouTube transcript pipeline for a channel, playlist, or video URL. Runs scrape → download → transcribe → push using whisperX, optionally diarization, and RunPod GPU for large archives.
argument-hint: <YouTube URL> [--diarize] [--model small|medium|large-v3] [--dir <project-name>]
---

# /tryt — YouTube transcripts

User invoked: `/tryt $ARGUMENTS`

## What this command does

Sets up a transcription pipeline for a YouTube source. Accepts any of:

- A channel URL: `https://www.youtube.com/@username` or `.../@username/videos`
- A playlist URL: `https://www.youtube.com/playlist?list=...`
- A single video URL: `https://www.youtube.com/watch?v=...`
- A category page: `.../@username/shorts`, `.../@username/streams`

## Steps to run

1. **Parse `$ARGUMENTS`** — first positional is the URL, then optional flags:
   - `--diarize` → set `WHISPER_DIARIZE=1` (default off; YouTube content is
     typically single-speaker)
   - `--model <size>` → `WHISPER_MODEL` (default `small`; use `medium` for
     technical jargon)
   - `--dir <name>` → directory to use; default is derived from the channel
     handle or playlist title

2. **Confirm with the user** before doing destructive work:
   - Show: detected URL type, default project directory, model, diarize.
   - Ask if they want to override.

3. **Set up the project directory** (`~/Projects/<name>` by default):
   ```
   mkdir -p <project>/{scripts,urls,audio,transcripts,meta}
   cd <project>
   git init
   ```
   Copy in scripts from the canonical `vsrf-transcripts/campbell/` template
   (download_audio.sh — YouTube variant, transcribe_one.py with
   WHISPER_DIARIZE toggle, transcribe_parallel.sh, progress.sh,
   runpod_setup.sh, runpod_run.sh).

4. **Scrape URLs** with yt-dlp flat-playlist:
   ```
   yt-dlp --flat-playlist --print "%(url)s" "<URL>" > urls/all.txt
   ```
   Show count to user.

5. **Decide compute** based on URL count:
   - ≤ 10 files → run locally on CPU (fast enough, no pod needed)
   - 11-50 files → ask user which they prefer
   - > 50 files → recommend RunPod (cite `~/Projects/vsrf-transcripts/GUIDE.md`
     for the full RunPod walkthrough)

6. **Local path** (small batches):
   ```
   bash scripts/download_audio.sh urls/all.txt audio
   export WHISPER_DEVICE=cpu WHISPER_MODEL=$model WHISPER_DIARIZE=$diarize
   bash scripts/transcribe_parallel.sh -p 1 -a audio -t transcripts
   ```
   Monitor with `bash scripts/progress.sh audio transcripts`.

7. **Cloud path** (large batches):
   - Walk user through RunPod setup (point to GUIDE.md Step 5).
   - On the pod, after setup: `bash scripts/runpod_run.sh`.
   - Set up GitHub repo so `runpod_run.sh`'s auto-commit works.

8. **Final** — when transcription completes:
   - Show user: total files transcribed, sample of one transcript.
   - Push results.
   - Remind them to tear down the pod.

## Differences from /trr (Rumble)

- No `--impersonate Chrome` needed.
- No Cloudflare rate limits — datacenter download is fast on the pod.
- For YouTube, re-downloading on the pod is faster than rsync from laptop
  (opposite of Rumble).

## Reference

Full workflow detail: `~/Projects/vsrf-transcripts/GUIDE.md`.
Working YouTube example (Campbell teaching): `~/Projects/vsrf-transcripts/campbell/`.
