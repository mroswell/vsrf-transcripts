# VSRF Channel Transcript Pipeline

## Context

You want a searchable archive of every long-form video on the Rumble channel `VaccineSafetyResearchFoundation` — full audio transcripts plus screenshots every 30 seconds — and you want it to update itself every Wednesday at 1 AM as new episodes go up.

We've already built and smoke-tested the core pipeline at `vsrf-pipeline/`:

- **URL scraper** (`scripts/scrape_urls.sh`) pages through `/c/.../videos`, filters `e9s=src_v1_ucp_v` to exclude shorts, produces `urls.txt` (385 unique videos).
- **Audio downloader** (`scripts/download_audio.sh`) uses `yt-dlp --impersonate Chrome` to bypass Cloudflare, with `--download-archive` for idempotency and a polite `--sleep-interval`.
- **Whisper transcription** (`scripts/transcribe.sh`) skips files that already have a `.txt`. Smoke test produced clean output on a 2-min clip.
- **Refresh wrapper** (`scripts/refresh.sh`) runs scrape → download → transcribe.

Real numbers from the cached HTML: **385 videos / 161.7 hours of audio**, with 80 long-form episodes (>1 hr) carrying 138 of those hours and 249 short clips (<5 min) carrying just 7.5 hr.

### Decisions locked in

- **Whisper model**: `small` (already cached locally; 1.35× faster than realtime; clean output on smoke test)
- **Filter**: drop the 46 videos with "preview" in the title (explicit promos, redundant with the full episodes)
- **Audio**: mp3 q5 (~1.5 MB/min)
- **Frames**: 1 every 30 s, JPEG q5 (~30–60 KB each)
- **Schedule host**: local `launchd` on this Mac, Wed 1 AM, with `pmset` wake 5 minutes prior
- **Repo location**: new **private** GitHub repo cloned at `~/Projects/vsrf-transcripts`

---

## Phase 1 — Extend the pipeline to also capture frames

Currently `scripts/download_audio.sh` extracts audio and discards the video. To get frames we need the video file briefly, so the new script downloads the video, runs ffmpeg twice (audio + frames), then deletes the video.

### Changes

**Rename** `scripts/download_audio.sh` → `scripts/download_media.sh` and rewrite the download to keep the source video, then post-process:

```bash
yt-dlp \
  --impersonate Chrome \
  --batch-file "$URLS" \
  --download-archive media/.archive \
  --no-overwrites \
  --write-info-json \
  --output "media/raw/%(upload_date)s_%(id)s.%(ext)s" \
  --restrict-filenames \
  --sleep-interval 1 --max-sleep-interval 4 \
  --retries 5 \
  --ignore-errors \
  --exec "after_video:bash $(pwd)/scripts/postprocess.sh {} %(id)s %(upload_date)s"
```

**New** `scripts/postprocess.sh` — runs once per downloaded video:
1. `ffmpeg -i "$VIDEO" -vn -acodec libmp3lame -q:a 5 "audio/${date}_${id}.mp3"`
2. `mkdir -p "frames/${id}" && ffmpeg -i "$VIDEO" -vf "fps=1/30" -q:v 5 "frames/${id}/frame_%04d.jpg"`
3. `rm "$VIDEO"`

Idempotency: if the audio file already exists *and* `frames/${id}/frame_0001.jpg` exists, skip immediately and exit 0.

**Update** `scripts/scrape_urls.sh` to filter Preview titles. The duration-extraction regex I built in this session (used to write `tmp/durations.tsv`) already parses titles per tile — lift that pattern in and skip any whose title matches `/preview/i`. Result: 385 → ~339 URLs.

**Update** `scripts/refresh.sh` to call `download_media.sh` instead of `download_audio.sh`, and to call `git_sync.sh` at the end (Phase 4).

**New** `scripts/transcribe_parallel.sh` — wrapper that runs N whisper processes in parallel via `xargs -P` over the queue of unprocessed audio files. Default N=2 (good fit for an 8-core M-series Mac running other work).

**Fix** `scripts/transcribe.sh` — the existing version passes `--output_format txt` and `--output_format json` together, which silently drops `txt`. Replace with `--output_format all`. (Already done in this session — keep.)

---

## Phase 2 — Run the backfill (one-time, local)

1. Re-scrape with the new Preview filter → `urls.txt` shrinks to ~339 entries.
2. `bash scripts/refresh.sh` once.
3. Expected wall time:
   - Download + frame extraction: ~6–10 hr (network + polite delays)
   - Transcription: ~120 hr serial, ~60 hr with `transcribe_parallel.sh -p 2`
4. Disk after backfill (final, persistent): ~14 GB mp3 + ~3–5 GB frames + ~30 MB transcripts.
5. The pipeline is fully resumable — kill it any time and re-run; it picks up where it left off.

---

## Phase 3 — GitHub repo at `~/Projects/vsrf-transcripts`

### Move and initialize

```bash
mv .../uigen/vsrf-pipeline ~/Projects/vsrf-transcripts
cd ~/Projects/vsrf-transcripts
git init
gh repo create vsrf-transcripts --private --source=. --remote=origin
```

### File layout (committed vs ignored)

| Path | Status | Why |
|---|---|---|
| `scripts/` | committed | source of truth |
| `urls.txt` | committed | the list, small text |
| `transcripts/*.txt`, `*.json` | committed | the deliverable, ~30 MB |
| `videos_meta/*.info.json` | committed | metadata, ~2 MB; useful for analysis later |
| `PLAN.md`, `README.md` | committed | docs |
| `audio/` | **gitignored** | ~14 GB |
| `frames/` | **gitignored** | ~5 GB; GitHub starts warning at 1 GB |
| `media/raw/` | **gitignored** | transient downloads |
| `tmp/` | **gitignored** | working files |
| `media/.archive`, `audio/.archive` | **gitignored** | local-only state |

We'll move the existing `audio/*.info.json` files into a new top-level `videos_meta/` directory so they survive the gitignore on `audio/` and `media/`.

If you later want frames in the cloud too, the natural upgrade is an S3/R2 bucket synced via `aws s3 sync frames/ s3://...` — out of scope for this plan but I'll note it in the README.

### `.gitignore`

```
audio/
frames/
media/
tmp/
*.archive
.DS_Store
__pycache__/
```

### Initial commit

After the backfill completes, commit everything in one push (~30 MB of text). Subsequent commits only contain the week's new transcripts.

---

## Phase 4 — Weekly refresh, Wed 1 AM (launchd + pmset)

### Wake the Mac (one-time)

```bash
sudo pmset repeat wakeorpoweron W 00:55:00
```

Schedules a recurring wake every Wednesday at 12:55 AM.

### launchd job

**New** `~/Library/LaunchAgents/com.mroswell.vsrf-refresh.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.mroswell.vsrf-refresh</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>cd ~/Projects/vsrf-transcripts &amp;&amp; bash scripts/refresh.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key><integer>3</integer>
    <key>Hour</key><integer>1</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key><string>/tmp/vsrf-refresh.log</string>
  <key>StandardErrorPath</key><string>/tmp/vsrf-refresh.err</string>
</dict></plist>
```

Load with `launchctl load ~/Library/LaunchAgents/com.mroswell.vsrf-refresh.plist`.

**New** `scripts/git_sync.sh` (called at the end of `refresh.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
git add transcripts/ videos_meta/ urls.txt
if ! git diff --cached --quiet; then
  git commit -m "weekly refresh: $(date +%F)"
  git push origin main
fi
```

### Why launchd, not the alternatives

- **GitHub Actions for transcription**: Free CPU runners are ~5× slower than this Mac; weekly delta of ~3 hr of audio runs ~15 hr on `small`, exceeding the 6-hr per-job limit. Workarounds (per-video matrix jobs, `tiny` model, paid larger runners, self-hosted) all add complexity for no upside given you have suitable local hardware.
- **Claude routine**: Designed for orchestration, not heavy compute. Cannot run whisper directly. Ends up needing a host machine anyway.
- **Hybrid (GH Action detects, local runs)**: Strictly more moving parts than just running everything locally, since launchd already detects "are there new URLs?" via `urls.txt` + `--download-archive`.

---

## Phase 5 — Watchdog (cheap insurance)

If the Mac is closed at 12:55 AM Wed (lid shut, traveling, etc.), the launchd job won't fire and you'd silently miss a refresh. Add a tiny GitHub Action that checks the latest commit timestamp every day at 9 AM and opens an issue if nothing has landed in 8 days.

**New** `.github/workflows/watchdog.yml`:

```yaml
name: refresh-watchdog
on:
  schedule: [{ cron: "0 9 * * *" }]
  workflow_dispatch:
jobs:
  check:
    runs-on: ubuntu-latest
    permissions:
      issues: write
      contents: read
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Open issue if no commit in 8 days
        run: |
          last=$(git log -1 --format=%ct)
          age_days=$(( ( $(date +%s) - last ) / 86400 ))
          if [ "$age_days" -gt 8 ]; then
            gh issue create -t "Refresh appears stalled (${age_days}d)" \
              -b "Latest commit is ${age_days} days old; weekly refresh may have missed a Wednesday."
          fi
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

This is the only thing that runs in the cloud; everything else is local. Free for private repos and well under the 2000 min/month allowance.

---

## Critical files

- [vsrf-pipeline/scripts/scrape_urls.sh](vsrf-pipeline/scripts/scrape_urls.sh) — add Preview-title filter
- [vsrf-pipeline/scripts/download_audio.sh](vsrf-pipeline/scripts/download_audio.sh) — rename → `download_media.sh`, drop `--extract-audio`, add `--exec after_video:` to call `postprocess.sh`
- [vsrf-pipeline/scripts/transcribe.sh](vsrf-pipeline/scripts/transcribe.sh) — confirm `--output_format all` (already fixed in session)
- [vsrf-pipeline/scripts/refresh.sh](vsrf-pipeline/scripts/refresh.sh) — point to `download_media.sh`, append `git_sync.sh` call
- New: `scripts/postprocess.sh` (audio + frames extraction + cleanup)
- New: `scripts/transcribe_parallel.sh` (parallel whisper wrapper)
- New: `scripts/git_sync.sh` (commit + push)
- New: `~/Library/LaunchAgents/com.mroswell.vsrf-refresh.plist`
- New: `.gitignore`, `README.md` in the repo
- New: `.github/workflows/watchdog.yml`

### Reusable bits already verified in this session

- The `--impersonate Chrome` invocation pattern in [scripts/download_audio.sh](vsrf-pipeline/scripts/download_audio.sh) — works against Rumble's Cloudflare TLS fingerprinting.
- The duration-extraction Python that produced `tmp/durations.tsv` — same regex shape can be lifted directly into `scrape_urls.sh` for the Preview filter (it already parses titles per tile).
- `audio/.archive` (currently 2 IDs from the smoke test) — preserve and reuse to avoid re-downloading those.

---

## Verification

**After Phase 1** (smoke test the new media flow on the same 2 short URLs in `tmp/smoke_urls.txt`):
- `find frames -name 'frame_*.jpg' | wc -l` returns >0 frames per video ID
- `ls audio/*.mp3` shows the same 2 mp3s as before
- No `media/raw/*.mp4` or `*.webm` files left over
- `du -sh frames audio` is small

**After Phase 2 backfill**:
- `find audio -name '*.mp3' | wc -l` ≈ 339
- `find transcripts -name '*.txt' | wc -l` ≈ 339
- `find frames -mindepth 1 -maxdepth 1 -type d | wc -l` ≈ 339
- Random spot-check 3 transcripts visually

**After Phase 3 push**:
- `gh repo view mroswell/vsrf-transcripts` shows the repo
- `git ls-files | grep -E '^(audio|frames|media)/'` returns empty
- `git ls-files transcripts | wc -l` ≈ 678 (txt + json)

**After Phase 4** (week 1):
- `launchctl list | grep vsrf-refresh` shows the agent loaded
- `pmset -g sched` shows the Wed 00:55 wake
- Thursday morning of week 1: a new commit landed between 1:00–2:00 AM Wed (or `/tmp/vsrf-refresh.log` shows "no new URLs" if the channel didn't post)

**After Phase 5**: manually trigger the watchdog with `gh workflow run watchdog.yml` and confirm it runs cleanly (it should not open an issue, since the repo is fresh).
