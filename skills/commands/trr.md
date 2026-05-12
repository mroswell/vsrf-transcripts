---
description: Set up a Rumble transcript pipeline for a channel, livestreams page, or single video URL. Runs scrape → download → transcribe → push using whisperX with diarization and RunPod GPU for large archives.
argument-hint: <Rumble URL> [--no-diarize] [--model small|medium|large-v3] [--dir <project-name>]
---

# /trr — Rumble transcripts

User invoked: `/trr $ARGUMENTS`

## What this command does

Sets up a transcription pipeline for a Rumble source. Accepts any of:

- A channel URL: `https://rumble.com/c/CHANNEL_NAME`
- A livestreams page: `https://rumble.com/c/CHANNEL_NAME/livestreams`
- A single video URL: `https://rumble.com/v....html`

## Steps to run

1. **Parse `$ARGUMENTS`** — first positional is the URL, then optional flags:
   - `--no-diarize` → set `WHISPER_DIARIZE=0` (default ON for Rumble; this
     is typically multi-host political/interview content)
   - `--model <size>` → `WHISPER_MODEL` (default `small`; use `medium` for
     technical jargon)
   - `--dir <name>` → directory to use; default is derived from the channel
     name or "rumble-transcripts"

2. **Confirm with the user** before doing destructive work:
   - Show: detected URL type, default project directory, model, diarize.
   - Ask if they want to override.

3. **Verify Hugging Face setup** (required for diarization):
   - Token at `~/.claude/secrets/hf_token.txt` or `tmp/hf_token.txt`.
   - Both `pyannote/speaker-diarization-3.1` and
     `pyannote/speaker-diarization-community-1` licenses accepted on
     huggingface.co.
   - If missing, prompt user and stop.

4. **Set up the project directory** (`~/Projects/<name>` by default):
   ```
   mkdir -p <project>/{scripts,videos_meta,audio,transcripts}
   cd <project>
   git init
   ```
   Copy in scripts from the canonical `vsrf-transcripts/scripts/` template
   (download_audio.sh — Rumble variant with `--impersonate Chrome`,
   transcribe_one.py, transcribe_parallel.sh, progress.sh, runpod_setup.sh,
   runpod_run.sh).

5. **Scrape URLs** with yt-dlp flat-playlist:
   ```
   yt-dlp --flat-playlist --print "%(url)s" "<URL>" > urls.txt
   ```
   Show count to user.

6. **Decide compute** based on URL count:
   - ≤ 5 files → run locally (CPU, with diarization, takes hours per file)
   - > 5 files → recommend RunPod. Diarization makes CPU prohibitively
     slow.

7. **Cloud path with rsync-from-laptop optimization** (Rumble-specific):
   - Rumble + `--impersonate Chrome` is rate-limited even on datacenter
     bandwidth (~5 min/file). Strongly prefer downloading audio locally
     once and rsync'ing to the pod.
   - Walk user through RunPod setup (point to GUIDE.md Step 5).
   - On the pod after setup, instead of `runpod_run.sh`, run only the
     transcribe phase against rsync'd audio:
     ```
     export WHISPER_DEVICE=cuda WHISPER_MODEL=$model WHISPER_DIARIZE=1
     nohup bash scripts/transcribe_parallel.sh -p 1 -a audio -t transcripts > run.log 2>&1 &
     tail -f run.log
     ```

8. **Set up GitHub push from pod** (PAT, not password — see GUIDE.md
   pitfalls section).

9. **Final** — when transcription completes:
   - Show user: total files transcribed, sample with `[SPEAKER_XX]` labels.
   - Push results.
   - Remind them to tear down the pod.

## Differences from /tryt (YouTube)

- Needs `--impersonate Chrome` and `yt-dlp[default,curl-cffi]`.
- Cloudflare + impersonation rate-limits downloads on the pod →
  rsync-from-laptop is faster.
- Diarization on by default (Rumble channels tend to be multi-host).

## Reference

Full workflow detail: `~/Projects/vsrf-transcripts/GUIDE.md`.
Working Rumble example: `~/Projects/vsrf-transcripts/` itself —
339 videos + 167 livestreams from VSRF, all diarized with whisperX.
