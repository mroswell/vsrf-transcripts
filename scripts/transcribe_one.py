#!/usr/bin/env python3
"""Transcribe a single audio file with whisperX + speaker diarization."""
import sys
import os
import json
import whisperx
from whisperx.diarize import DiarizationPipeline

audio_path = sys.argv[1]
out_dir = sys.argv[2] if len(sys.argv) > 2 else "transcripts"
model_name = os.environ.get("WHISPER_MODEL", "small")
lang = os.environ.get("WHISPER_LANG", "en")
device = os.environ.get("WHISPER_DEVICE", "cpu")
compute_type = os.environ.get("WHISPER_COMPUTE_TYPE", "float16" if device == "cuda" else "int8")

# Read HF token for diarization
hf_token_path = os.path.join(os.path.dirname(__file__), "..", "tmp", "hf_token.txt")
with open(hf_token_path) as f:
    hf_token = f.read().strip()

base = os.path.splitext(os.path.basename(audio_path))[0]

# 1. Transcribe with whisperX
model = whisperx.load_model(model_name, device, compute_type=compute_type, language=lang)
audio = whisperx.load_audio(audio_path)
result = model.transcribe(audio, batch_size=16)

# 2. Align timestamps
align_model, metadata = whisperx.load_align_model(language_code=lang, device=device)
result = whisperx.align(result["segments"], align_model, metadata, audio, device, return_char_alignments=False)

# 3. Diarize (assign speakers)
diarize_model = DiarizationPipeline(token=hf_token, device=device)
diarize_segments = diarize_model(audio)
result = whisperx.assign_word_speakers(diarize_segments, result)

# 4. Write .txt with speaker labels and paragraph breaks
current_speaker = None
lines = []
for seg in result["segments"]:
    speaker = seg.get("speaker", "UNKNOWN")
    text = seg["text"].strip()
    if not text:
        continue
    if speaker != current_speaker:
        if current_speaker is not None:
            lines.append("")  # blank line between speakers
        lines.append(f"[{speaker}]")
        current_speaker = speaker
    lines.append(text)

with open(os.path.join(out_dir, f"{base}.txt"), "w") as f:
    f.write("\n".join(lines) + "\n")

# 5. Write .json (full segments with speaker info and timestamps)
with open(os.path.join(out_dir, f"{base}.json"), "w") as f:
    json.dump(result, f, indent=2, ensure_ascii=False, default=str)

print(f"<<< done {base}")
