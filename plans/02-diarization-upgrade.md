# Plan 02: whisperX + pyannote diarization

## Context

The original pipeline produced raw transcripts with no speaker labels. For
a multi-host show with guest interviews, we wanted `[SPEAKER_00]`,
`[SPEAKER_01]`, etc. tags and paragraph breaks per speaker.

## Approach

Replace plain Whisper with whisperX (Whisper + alignment + pyannote
diarization). All in `scripts/transcribe_one.py`:

```python
import whisperx
from whisperx.diarize import DiarizationPipeline

# 1. Transcribe
model = whisperx.load_model(model_name, device, compute_type=...)
result = model.transcribe(audio, batch_size=16)
# 2. Align word-level timestamps
align_model, metadata = whisperx.load_align_model(...)
result = whisperx.align(...)
# 3. Diarize and assign speakers
diarize_model = DiarizationPipeline(token=hf_token, device=device)
diarize_segments = diarize_model(audio)
result = whisperx.assign_word_speakers(diarize_segments, result)
# 4. Write .txt with speaker labels + paragraph breaks
# 5. Write .json with full segments + timestamps + speakers
```

Diarization model: `pyannote/speaker-diarization-community-1` (gated on
HuggingFace; license must be accepted per-account).

HF token lives in `tmp/hf_token.txt` (gitignored).

## Decisions made along the way

- Backed up pre-diarization transcripts to `transcripts_backup/` before
  re-running. Kept as safety copy.
- Switched env var name from `LANG` to `WHISPER_LANG` because `LANG`
  collided with system locale.
- Switched from `-p 2` to `-p 1` after we observed orphaned-process
  conflicts when killing parallel runs mid-batch.

## Status

Done for livestreams (167 transcripts diarized via the RunPod batch).
Pending for the 339 videos — see plan 04.
