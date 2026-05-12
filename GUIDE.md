# GUIDE: Building a transcription archive from a video channel

A pragmatic walkthrough of the workflow used to build the VSRF transcripts
archive — collecting every video and livestream from a Rumble channel and
producing speaker-diarized transcripts with whisperX + pyannote, using a
RunPod cloud GPU.

The same pipeline works for any source `yt-dlp` supports: a YouTube
channel, a playlist, a single video URL, or a category page like
`/livestreams` or `/shorts`. Where Rumble-specific quirks come up,
they're called out.

> **Time:** ~1-2 hours of active setup, plus 1-3 days of unattended GPU
> time for a typical channel of a few hundred videos.
> **Cost:** ~$5-15 in RunPod credit, depending on size and model.

---

## Prerequisites

On your laptop:

- `git`, `python3` (3.11+), `ffmpeg`
- `pip install yt-dlp[default,curl-cffi] whisperx pyannote.audio`
- A **HuggingFace account** with the licenses accepted for both:
  - `pyannote/speaker-diarization-3.1`
  - `pyannote/speaker-diarization-community-1`
  - Generate a token at https://huggingface.co/settings/tokens
- A **GitHub repo** to store the transcripts (private or public).
- A **RunPod account** with $10-25 of prepaid credit
  (https://www.runpod.io). No subscription.

---

## Step 1 — Scrape URLs from the channel

`yt-dlp`'s flat-playlist mode pulls every video URL on a channel page
without downloading the videos themselves. Run once per content type
(channel, livestreams, shorts, etc.):

```bash
yt-dlp --flat-playlist --print "%(url)s" \
  "https://rumble.com/c/CHANNEL_NAME" \
  > urls.txt

yt-dlp --flat-playlist --print "%(url)s" \
  "https://rumble.com/c/CHANNEL_NAME/livestreams" \
  > livestream_urls.txt
```

> **Note (Rumble-specific):** Rumble sits behind Cloudflare and
> fingerprints TLS, so most yt-dlp commands need `--impersonate Chrome`.
> The flat-playlist call above usually works without it; the actual
> downloads later **do** need it.

---

## Step 2 — Download audio (local)

A simple yt-dlp invocation. **Idempotent**: re-running skips already
downloaded files via `--download-archive`.

```bash
yt-dlp \
  --impersonate Chrome \
  --batch-file livestream_urls.txt \
  --download-archive livestreams_audio/.archive \
  --no-overwrites \
  -f "ba/b" \
  --extract-audio --audio-format mp3 --audio-quality 5 \
  --write-info-json \
  --output "livestreams_audio/%(upload_date)s_%(id)s.%(ext)s" \
  --output "infojson:videos_meta/%(upload_date)s_%(id)s.%(ext)s" \
  --restrict-filenames \
  --sleep-interval 1 --max-sleep-interval 4 \
  --retries 5 --ignore-errors --progress
```

The `.info.json` sidecars in `videos_meta/` capture title, upload date,
duration, thumbnail, etc. The HTML wall step at the end uses them.

> **Decision change later:** This command is fine for downloading from
> a residential connection. Once we moved to the RunPod pod, downloads
> took **~5 min/file** because Rumble rate-limited the impersonated
> requests. We ended up rsync'ing already-downloaded audio from laptop
> to pod instead of re-downloading. See Step 5 below.

---

## Step 3 — Set up the transcription scripts

Create a small `scripts/` directory with these:

### `scripts/transcribe_one.py`

```python
#!/usr/bin/env python3
import sys, os, json
import whisperx
from whisperx.diarize import DiarizationPipeline

audio_path = sys.argv[1]
out_dir = sys.argv[2] if len(sys.argv) > 2 else "transcripts"
model_name = os.environ.get("WHISPER_MODEL", "small")
lang = os.environ.get("WHISPER_LANG", "en")
device = os.environ.get("WHISPER_DEVICE", "cpu")
compute_type = os.environ.get(
    "WHISPER_COMPUTE_TYPE",
    "float16" if device == "cuda" else "int8",
)

with open("tmp/hf_token.txt") as f:
    hf_token = f.read().strip()

base = os.path.splitext(os.path.basename(audio_path))[0]

model = whisperx.load_model(model_name, device, compute_type=compute_type, language=lang)
audio = whisperx.load_audio(audio_path)
result = model.transcribe(audio, batch_size=32)

align_model, metadata = whisperx.load_align_model(language_code=lang, device=device)
result = whisperx.align(result["segments"], align_model, metadata, audio, device, return_char_alignments=False)

diarize_model = DiarizationPipeline(token=hf_token, device=device)
diarize_segments = diarize_model(audio)
result = whisperx.assign_word_speakers(diarize_segments, result)

current_speaker, lines = None, []
for seg in result["segments"]:
    speaker, text = seg.get("speaker", "UNKNOWN"), seg["text"].strip()
    if not text:
        continue
    if speaker != current_speaker:
        if current_speaker is not None: lines.append("")
        lines.append(f"[{speaker}]")
        current_speaker = speaker
    lines.append(text)

with open(os.path.join(out_dir, f"{base}.txt"), "w") as f:
    f.write("\n".join(lines) + "\n")
with open(os.path.join(out_dir, f"{base}.json"), "w") as f:
    json.dump(result, f, indent=2, ensure_ascii=False, default=str)
```

> **Decision changes baked in:**
> - `WHISPER_DEVICE` env var so the same script runs on cpu (laptop) or
>   cuda (pod).
> - `WHISPER_LANG` instead of `LANG` — `LANG` collides with system locale.
> - `batch_size=32` (originally 16); 32 is fine on a T4 (16 GB) and faster.

### `scripts/transcribe_parallel.sh`

A small `xargs -P` wrapper. Skips files that already have a `.txt`. Use
`-p 1` (single process) — see the orphan-conflict note below.

### `scripts/progress.sh`

```bash
#!/usr/bin/env bash
AUDIO_DIR="${1:-livestreams_audio}"
TRANSCRIPT_DIR="${2:-livestreams_transcripts}"
LATEST=$(basename "$(ls -t "$TRANSCRIPT_DIR"/*.txt | head -1)" .txt | cut -d_ -f2)
echo "[$(date +%H:%M)] $(ls "$TRANSCRIPT_DIR"/*.txt | wc -l) of $(ls "$AUDIO_DIR"/*.mp3 | wc -l) done ($(( $(ls "$TRANSCRIPT_DIR"/*.txt | wc -l) * 100 / $(ls "$AUDIO_DIR"/*.mp3 | wc -l) ))%) — latest: $LATEST"
```

---

## Step 4 — Choose your transcription compute

| Compute | Time per file (`small` model) | When to use |
|---------|-------------------------------|-------------|
| Laptop CPU | ~2 hours | <10 files, or testing |
| RunPod T4 (~$0.20/hr) | ~5-10 minutes | The whole archive |

> **Decision change:** We started on laptop CPU. After a week we were
> at 41% (70/167) on the livestreams batch. The pod did the same kind of
> work in hours. **For any archive larger than ~10 files, go straight
> to cloud GPU.** The setup is one-time and easy.

If you're going local, run:

```bash
export WHISPER_MODEL=small
bash scripts/transcribe_parallel.sh -p 1 -a livestreams_audio -t livestreams_transcripts
```

If cloud, continue to Step 5.

> **Lesson learned:** `-p 1`, not `-p 2`. We started with `-p 2`; when
> we needed to kill and resume, child Python processes orphaned and
> raced each other on the same files. With `-p 1`, kill is clean.

---

## Step 5 — RunPod cloud GPU setup

### 5a. Launch a pod

In the RunPod console:

1. Pods → **Deploy** → **Community Cloud**
2. **GPU**: any NVIDIA card with 8 GB+ VRAM. T4, A4000, RTX 4000 Ada,
   A40, A10G all work; sort by cheapest first.
3. **Template**: any **PyTorch + CUDA** image
   (e.g. `runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04`).
4. **Disk**: 30 GB minimum.
5. Click **Deploy**.

### 5b. Connect

The simplest path is **Web Terminal** (in the pod's *Connect* panel).
SSH-over-TCP also works but requires registering a public key.

> **Lesson learned:** RunPod injects SSH keys *only at pod launch*. If
> you add a key after the pod is running, it doesn't propagate. To use
> SSH on a running pod, log in via Web Terminal once and append your
> public key to `~/.ssh/authorized_keys` manually.

### 5c. Pod setup script

```bash
#!/usr/bin/env bash
set -euo pipefail
apt-get update -qq && apt-get install -y -qq ffmpeg
pip install --quiet --upgrade pip
pip install --quiet \
  whisperx \
  "yt-dlp[default,curl-cffi]" \
  pyannote.audio \
  hf_transfer
python3 -c "import nltk; nltk.download('punkt_tab', quiet=True)"
mkdir -p tmp
echo "$HF_TOKEN" > tmp/hf_token.txt
python3 -c "import torch; assert torch.cuda.is_available(); print(torch.cuda.get_device_name(0))"
```

> **Lessons learned:**
> - `yt-dlp[default,curl-cffi]` — bare `yt-dlp + curl_cffi` does **not**
>   make `--impersonate Chrome` work.
> - `hf_transfer` is required because RunPod's PyTorch image sets
>   `HF_HUB_ENABLE_HF_TRANSFER=1` but doesn't ship the package.
> - `nltk.download('punkt_tab')` — whisperX needs this and won't
>   download it on first call.

### 5d. Get audio onto the pod

Two options. **Prefer rsync from your laptop** if you've already
downloaded locally:

```bash
rsync -avP --no-o --no-g \
  -e "ssh -p POD_PORT -i ~/.ssh/your_pod_key" \
  livestreams_audio/ \
  root@POD_HOST:/workspace/REPO/livestreams_audio/
```

Otherwise re-download on the pod (slower due to Rumble's rate limits):

```bash
bash scripts/runpod_run.sh   # which calls download_audio.sh internally
```

> **Decision change:** The original plan was "the pod re-downloads on
> datacenter bandwidth, much faster than uploading." That's true for
> YouTube but **false for Rumble** because impersonation gets rate-
> limited. For Rumble, rsync from laptop is faster.

### 5e. Run the batch

```bash
cd /workspace/REPO
git pull   # if needed
export WHISPER_DEVICE=cuda
export WHISPER_MODEL=medium     # or small for speed; large-v3 not worth it
nohup bash scripts/transcribe_parallel.sh \
  -p 1 -a livestreams_audio -t livestreams_transcripts \
  > run.log 2>&1 &
tail -f run.log
```

> **Decision change:** We started on `WHISPER_MODEL=small` and bumped to
> `medium` for the videos batch — better accuracy on technical/medical
> jargon. ~2x slower but fine on a T4. `large-v3` is rarely worth the 4x
> cost.

`nohup` keeps the job alive after the terminal closes. Reattach any
time with `tail -f run.log` after reconnecting.

### 5f. Push results from the pod

```bash
git config user.email "you@example.com"
git config user.name "you"
git add livestreams_transcripts/
git commit -m "diarized livestream transcripts from runpod"
git push
```

> **Lesson learned:** GitHub blocks password auth for HTTPS. Use a
> Personal Access Token (https://github.com/settings/tokens →
> Fine-grained → repo `Contents: read/write`) and paste it as the
> password. Cache once with `git config --global credential.helper store`.

### 5g. Tear down

When the run finishes:

- **Stop** the pod from the console (cheap, preserves disk).
- Or **Terminate** for full cleanup (loses disk; do this once everything
  is pushed to git).

---

## Step 6 — Build the HTML video wall

`scripts/build_wall.py` reads `videos_meta/*.info.json` and writes
`videos.html` and `livestreams.html` — a grid of YouTube-style cards
with thumbnails, titles, dates, and links to transcripts.

```bash
python3 scripts/build_wall.py
```

Open `videos.html` in a browser to verify, then commit.

---

## Common pitfalls (collected from this build)

| Symptom | Cause | Fix |
|---|---|---|
| `Impersonate target "chrome" is not available` | yt-dlp curl_cffi extras missing | `pip install "yt-dlp[default,curl-cffi]"` |
| `no module named hf_transfer` | RunPod sets `HF_HUB_ENABLE_HF_TRANSFER=1` but doesn't ship it | `pip install hf_transfer` |
| Diarization model fails to download | HF license not accepted | Accept on huggingface.co (per-account, per-version) |
| `LANG` env var corruption | name collision with system locale | rename to `WHISPER_LANG` |
| `nltk.LookupError: punkt_tab` | NLTK data not pre-downloaded | `python3 -c "import nltk; nltk.download('punkt_tab')"` |
| Orphan transcribe processes after kill | `xargs -P 2+` doesn't propagate signals cleanly | use `-p 1` |
| RunPod SSH key not accepted | injected only at pod launch | append to running pod's `~/.ssh/authorized_keys` via Web Terminal |
| GitHub `password authentication is not supported` | as of 2021 GitHub requires tokens for HTTPS | use a fine-grained PAT |
| Pod download phase very slow (Rumble) | impersonation rate-limited | rsync audio from laptop instead |

---

## File layout (what you'll end up with)

```
my-channel-transcripts/
├── urls.txt                          # video URLs
├── livestream_urls.txt               # livestream URLs (if applicable)
├── audio/                            # gitignored — laptop only
├── livestreams_audio/                # gitignored — laptop only
├── videos_meta/*.info.json           # metadata for HTML wall
├── transcripts/*.{txt,json}          # diarized transcripts (videos)
├── livestreams_transcripts/*.{txt,json}
├── videos.html                       # video wall
├── livestreams.html                  # livestream wall
├── scripts/
│   ├── scrape_urls.sh
│   ├── download_audio.sh
│   ├── transcribe_one.py
│   ├── transcribe_parallel.sh
│   ├── runpod_setup.sh
│   ├── runpod_run.sh
│   ├── progress.sh
│   └── build_wall.py
├── tmp/hf_token.txt                  # gitignored
├── RUNPOD.md                         # user-facing pod instructions
└── plans/                            # plan docs (this file's source material)
```

`.gitignore`:

```
audio/
livestreams_audio/
tmp/
*.archive
.DS_Store
__pycache__/
nohup.out
run.log
transcripts_backup/
transcripts_backup_pod/
```

---

## Cost estimates

For a channel of ~500 videos, ~1 hour each:

| Setup | Time | Cost |
|---|---|---|
| Laptop CPU only | ~2 months | $0 (laptop unusable) |
| T4 cloud + `small` model | ~24 hr | ~$5 |
| T4 cloud + `medium` model | ~50 hr | ~$10 |
| A40 cloud + `medium` model | ~25 hr | ~$13 |

The `medium` model on a T4 is the sweet spot for talking-head content
with technical jargon.

---

## Future: as a Claude Code skill

The long-term plan is to package this whole workflow as two Claude Code
slash commands so it can be invoked against any channel without
re-deriving the pipeline:

- `/trr` — Rumble transcripts (this guide's exact flow)
- `/tryt` — YouTube transcripts (same shape, no `--impersonate Chrome`,
  audio re-download on the pod is fast)

Both should accept any of:

- A channel URL
- A playlist URL
- A single video URL
- A category page (`/livestreams`, `/shorts`, etc.)

`yt-dlp` already accepts all four shapes, so the skill mostly needs to:

1. Detect the URL type (or just defer to yt-dlp's playlist extractor).
2. Decide local vs cloud GPU based on file count (rule of thumb: ≤10
   files → local, >10 → RunPod).
3. Drive the run, monitor, push results.
4. Generate the HTML wall.

The skill files would live in this repo at `skills/trr/SKILL.md` and
`skills/tryt/SKILL.md`. To install, copy or symlink into
`~/.claude/skills/`. This keeps the source-of-truth versioned in the
repo while letting the Claude Code runtime find them globally.

Open design questions:

- **Auth from the skill** — likely a RunPod API token at
  `~/.claude/secrets/runpod_api.txt`.
- **Where transcripts go** — per-job repo? Subdirectory of one repo?
- **Skip diarization for single-speaker channels** — ~50% speed up. Want
  this opt-in via a flag, or auto-detected from `info.json`?

Not started. Will pick up after the videos batch finishes and the
RunPod recipe is fully proven.
