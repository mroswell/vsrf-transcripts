# Custom Claude Code commands for transcript pipelines

Two slash commands that drive the workflows documented in
`../GUIDE.md`:

- **`/tryt <YouTube URL>`** — sets up and runs a transcription pipeline
  for a YouTube channel, playlist, or video.
- **`/trr <Rumble URL>`** — same for Rumble.

Each one accepts any URL the underlying `yt-dlp` recognizes (channel,
playlist, single video, category page like `/livestreams` or `/shorts`).

## Install

Slash commands live at `~/.claude/commands/`. Copy them there:

```bash
cp commands/tryt.md ~/.claude/commands/
cp commands/trr.md  ~/.claude/commands/
```

After that, `/tryt` and `/trr` show up in Claude Code's slash-command
picker globally — usable from any project.

To update later, edit the originals here and re-copy. (Or symlink:
`ln -sf "$PWD/commands/tryt.md" ~/.claude/commands/tryt.md` so edits
apply live.)

## Why slash commands instead of skills

Skills auto-trigger when Claude judges them relevant. These workflows
are heavyweight (spin up cloud GPUs, push to GitHub) — explicit
invocation via `/` is the right shape. Type the command, pass the URL,
get a guided run.

## What the commands actually do

Both walk Claude through:

1. Parse the URL and any flags (`--diarize`, `--model`, `--dir`).
2. Confirm settings with you.
3. Set up a new project directory with the proven script templates.
4. Scrape URLs with `yt-dlp --flat-playlist`.
5. Decide local vs cloud GPU based on file count.
6. Drive the run, monitor progress, push results.
7. Remind you to tear down the pod when done.

## Source-of-truth

The commands reference `~/Projects/vsrf-transcripts/GUIDE.md` for the
detailed workflow and `~/Projects/vsrf-transcripts/campbell/` /
`~/Projects/vsrf-transcripts/scripts/` for proven script templates.
Keep this repo around — the commands assume it exists.
