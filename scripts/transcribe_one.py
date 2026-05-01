#!/usr/bin/env python3
"""Transcribe a single audio file with whisper. Called by transcribe_parallel.sh."""
import sys
import os
import json
import whisper

audio_path = sys.argv[1]
model_name = os.environ.get("WHISPER_MODEL", "small")
lang = os.environ.get("WHISPER_LANG", "en")

base = os.path.splitext(os.path.basename(audio_path))[0]
out_dir = "transcripts"

model = whisper.load_model(model_name)
result = model.transcribe(audio_path, language=lang, fp16=False)

# Write .txt
with open(os.path.join(out_dir, f"{base}.txt"), "w") as f:
    f.write(result["text"].strip() + "\n")

# Write .json (with segments/timestamps)
with open(os.path.join(out_dir, f"{base}.json"), "w") as f:
    json.dump(result, f, indent=2, ensure_ascii=False, default=str)

print(f"<<< done {base}")
