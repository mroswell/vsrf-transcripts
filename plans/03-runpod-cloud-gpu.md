# Plan 03: Migrate transcription to RunPod cloud GPU

## Context

After a week of laptop CPU transcription on the diarized livestream batch,
progress was at 41% (70/167). At ~2 hours per file on CPU, finishing the
167 livestreams would have taken another two weeks. Renting a T4 on
RunPod (~$0.20/hr) does the same work in hours, not weeks.

## Approach

1. **Adapt `transcribe_one.py`** to honor `WHISPER_DEVICE` env var
   (defaults to `cpu`; we set `cuda` on the pod). Default
   `WHISPER_COMPUTE_TYPE` to `float16` on cuda, `int8` on cpu.

2. **Add pod-side scripts:**
   - `scripts/runpod_setup.sh` — installs ffmpeg + whisperx +
     `yt-dlp[default,curl-cffi]` + pyannote.audio + hf_transfer + nltk
     punkt_tab. Writes HF token. Verifies CUDA is visible.
   - `scripts/runpod_run.sh` — three phases: yt-dlp download → GPU
     transcription → git commit + push.

3. **`RUNPOD.md`** — user-facing instructions: sign up, add credit,
   launch a T4 PyTorch pod, SSH or web terminal in, run setup + run,
   tear down.

## Real-world adjustments

- **Audio re-download was rate-limited.** Rumble + `--impersonate Chrome`
  capped at ~5 min per file, so the download phase took ~7 hours for
  ~104 livestreams. Solution next time: rsync existing audio from laptop
  in parallel with the run (we did this for the videos batch — see plan 04).
- **Web Terminal** preferred over SSH for first-time users. SSH key
  registration in RunPod only injects at pod launch; for a running pod we
  appended the public key to `~/.ssh/authorized_keys` manually.
- **`hf_transfer` not installed by default** on RunPod's PyTorch image,
  but `HF_HUB_ENABLE_HF_TRANSFER=1` is set in the environment, so model
  downloads fail unless we install `hf_transfer`. Patched into
  `runpod_setup.sh`.
- **`yt-dlp` impersonate target** — needed `yt-dlp[default,curl-cffi]`
  not just `yt-dlp + curl_cffi`.
- **Two parallel processes during livestream batch:** ran
  `runpod_run.sh` (sequential download → transcribe), and once download
  was mostly done, a second `transcribe_parallel.sh` to start GPU work
  while download finished. Both share the same transcripts dir; idempotent.

## Status

Done. Livestreams diarized and pushed. Pod still running, audio for
videos already rsync'd.
