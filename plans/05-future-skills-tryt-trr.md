# Plan 05 (future): /tryt and /trr as Claude Code skills

## Context

Once the cloud GPU pipeline is proven on this archive, package it as
reusable Claude Code slash commands so the same workflow can be pointed
at any YouTube channel (`/tryt`) or Rumble channel (`/trr`).

The existing `~/.claude/skills/video-content-pipeline/SKILL.md` is broader
(also does frame extraction, OCR, sentiment dashboards). These new skills
should be **focused transcription skills** that complement it.

## Inputs each skill should accept

- A channel URL (e.g. `https://rumble.com/c/...`)
- A playlist URL
- A single video URL
- A category URL (e.g. `/livestreams`, `/shorts`)

yt-dlp accepts all four shapes natively, so the skill just needs URL
type detection (or just delegate to yt-dlp's playlist-style extraction).

## Skill responsibilities

1. Pre-flight: ensure yt-dlp + whisperx + HF token are configured.
2. Scrape URLs from input → write to a per-job URL list.
3. Decide locally vs cloud GPU based on count (rule of thumb:
   `<= 10` files → local fine, `> 10` → RunPod).
4. Drive the run, monitor, and push transcripts to a chosen repo.
5. Generate a video wall HTML for the result.

## Decisions to defer

- Where transcripts live (per-job repo? subdirectory of one repo?)
- How the user authenticates with RunPod from the skill (likely a token
  stored at `~/.claude/secrets/runpod_api.txt`).
- Single-speaker channels — option to skip diarization for ~50% speedup
  (e.g. one-host teaching channels).

## Where the skill files would live (per user preference)

Drafted in `skills/tryt/SKILL.md` and `skills/trr/SKILL.md` inside this
project. User installs by `cp -r skills/tryt ~/.claude/skills/`
(keeps source-of-truth versioned in this repo, sandbox hook stays
intact).

## Status

Not started. Will pick up after the videos batch finishes and the
RunPod recipe is fully proven.
