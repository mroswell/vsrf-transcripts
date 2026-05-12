# Plan 01: Original VSRF transcript pipeline

## Context

Build a resumable, idempotent pipeline that scrapes the Rumble channel
@VaccineSafetyResearchFoundation, downloads audio for each video, and
transcribes them with Whisper. The original PLAN.md at repo root is the
canonical version of this — this file just summarizes the moving parts.

## Components

- `scripts/scrape_urls.sh` — pulls every video URL into `urls.txt` using
  yt-dlp's flat-playlist extraction. Updated later to also pull
  `/livestreams` into `livestream_urls.txt`.
- `scripts/download_audio.sh` — yt-dlp with `--impersonate Chrome`
  (Cloudflare bypass) and `--download-archive` (idempotency). Writes
  `.info.json` sidecars to `videos_meta/` for later HTML rendering.
- `scripts/transcribe_parallel.sh` — fan-out wrapper using `xargs -P`.
- `scripts/transcribe_one.py` — single-file Whisper invocation.
- `scripts/build_wall.py` — generates `videos.html` and
  `livestreams.html` using the `.info.json` sidecars.
- `scripts/progress.sh` — quick `<done>/<total>` percentage check.
- `.github/workflows/watchdog.yml` — alerts if the local pipeline stalls.

## Status

Done. ~339 videos and 167 livestreams scraped and downloaded. All audio
in `audio/` (videos) and `livestreams_audio/` (livestreams).
