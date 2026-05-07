# Running the transcription pipeline on RunPod

A T4 GPU pod (~$0.20/hr) finishes the remaining ~104 diarized livestreams in
roughly 6-10 hours instead of two more weeks on a laptop CPU.

## One-time setup

1. **Sign up** at https://www.runpod.io and add **$10-25 credit** (prepaid, no
   subscription).
2. **Add an SSH public key** under *Settings → SSH Public Keys*. Paste your
   `~/.ssh/id_ed25519.pub` (or RSA equivalent).
3. **Hugging Face token**: you already have one in `tmp/hf_token.txt` locally.
   You'll paste its value into the pod environment in step 5 below.

## Each run

### 1. Launch a pod

- Pods → **Deploy** → **Community Cloud**
- GPU: **RTX 4000 Ada** or **T4** (~$0.20-0.30/hr is fine; bigger doesn't help
  much for the `small` whisper model).
- Template: **runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04** (or
  any PyTorch + CUDA template).
- Volume disk: **30 GB** (for whisper models, cached HF assets, audio).
- Click **Deploy**.

### 2. Connect

In the pod's *Connect* panel, click **SSH over exposed TCP**. You'll get a
command like:

```
ssh root@<host> -p <port> -i ~/.ssh/id_ed25519
```

### 3. Clone the repo and configure

On the pod:

```bash
git clone https://github.com/mroswell/vsrf-transcripts.git
cd vsrf-transcripts
export HF_TOKEN="<paste your HF token here>"
bash scripts/runpod_setup.sh
```

The setup script installs ffmpeg + whisperx + yt-dlp + pyannote, writes the
HF token, and verifies CUDA is visible.

### 4. Run

```bash
# Livestreams (default — 104 remaining)
bash scripts/runpod_run.sh

# Or to also (re)do the videos set:
bash scripts/runpod_run.sh urls.txt audio transcripts
```

This downloads any missing audio, transcribes on the GPU, then commits and
pushes transcripts back to GitHub. Safe to re-run if the pod restarts.

To run it in the background and disconnect:

```bash
nohup bash scripts/runpod_run.sh > run.log 2>&1 &
tail -f run.log   # ctrl-c to stop tailing; the job keeps running
```

### 5. Watch progress

From the pod:

```bash
bash scripts/progress.sh
```

From your laptop (after the pod has pushed at least once):

```bash
git pull
bash scripts/progress.sh
```

### 6. Tear down

When the run finishes, **stop the pod from the RunPod console**. You're billed
per second the pod is running. Stopped pods incur ~$0.01/hr storage; if you're
not coming back soon, click **Terminate** to fully delete the volume.

## Troubleshooting

- **HF token rejected**: re-accept the licenses for `pyannote/speaker-diarization-3.1`
  and `pyannote/speaker-diarization-community-1` on huggingface.co (the gates
  are per-account, per-version).
- **Pod kicked offline / preempted**: just relaunch and re-run; everything is
  idempotent. Audio that was downloaded sticks (community cloud preserves the
  volume by default; secure cloud may not).
- **Disk full during download**: bump volume disk to 50 GB on launch. The 167
  livestreams together are ~10 GB.
- **Want even faster?**: switch to an A40 or A10G and set `WHISPER_MODEL=medium`.
  The `small` model is fine for this content and saves money.

## Cost estimate

| GPU | $/hr | Time for 104 files | Total |
|-----|------|--------------------|-------|
| T4 (community) | ~$0.20 | 8-10 hr | ~$2 |
| RTX 4000 Ada   | ~$0.30 | 6-8 hr  | ~$2-3 |
| A40            | ~$0.50 | 3-5 hr  | ~$2-3 |
