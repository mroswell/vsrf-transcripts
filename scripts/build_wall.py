#!/usr/bin/env python3
"""Generate video wall HTML pages from videos_meta/*.info.json."""
import json
import glob
import os

def load_videos(audio_dir, transcript_dir):
    """Load video metadata, matching against audio and transcript dirs."""
    # Get IDs from audio directory
    audio_ids = {}
    for f in glob.glob(f"{audio_dir}/*.mp3"):
        base = os.path.basename(f).replace(".mp3", "")
        parts = base.split("_", 1)
        if len(parts) == 2:
            audio_ids[parts[1]] = base  # vid_id -> date_vid_id

    videos = []
    for path in sorted(glob.glob("videos_meta/*.info.json")):
        with open(path) as f:
            info = json.load(f)
        vid_id = info.get("id", "")
        if vid_id not in audio_ids:
            continue

        base = audio_ids[vid_id]
        has_transcript = os.path.isfile(f"{transcript_dir}/{base}.txt")

        date_raw = info.get("upload_date", "????????")
        date_fmt = f"{date_raw[:4]}-{date_raw[4:6]}-{date_raw[6:8]}" if len(date_raw) == 8 else date_raw

        videos.append({
            "id": vid_id,
            "base": base,
            "title": info.get("title", "(no title)"),
            "date": date_fmt,
            "duration": info.get("duration_string", ""),
            "thumbnail": info.get("thumbnail", ""),
            "url": info.get("webpage_url", ""),
            "has_transcript": has_transcript,
            "transcript_dir": transcript_dir,
        })

    # Sort by date descending (newest first)
    videos.sort(key=lambda v: v["date"], reverse=True)
    return videos


def render_html(title, videos, output_path):
    """Render an HTML video wall."""
    cards = []
    for v in videos:
        transcript_link = ""
        if v["has_transcript"]:
            transcript_link = f'<a href="{v["transcript_dir"]}/{v["base"]}.txt" class="transcript-link">Read Transcript</a>'
        else:
            transcript_link = '<span class="no-transcript">Transcript pending</span>'

        cards.append(f"""
      <div class="card">
        <a href="{v['url']}" target="_blank" class="thumb-link">
          <img src="{v['thumbnail']}" alt="{v['title']}" loading="lazy">
          <span class="duration">{v['duration']}</span>
        </a>
        <div class="info">
          <a href="{v['url']}" target="_blank" class="title">{v['title']}</a>
          <div class="meta">
            <span class="date">{v['date']}</span>
            {transcript_link}
          </div>
        </div>
      </div>""")

    total = len(videos)
    transcribed = sum(1 for v in videos if v["has_transcript"])

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: system-ui, -apple-system, sans-serif; background: #1a1a2e; color: #e0e0e0; padding: 20px; }}
  h1 {{ font-size: 28px; margin-bottom: 6px; color: #fff; }}
  .stats {{ font-size: 14px; color: #888; margin-bottom: 20px; }}
  .grid {{
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 16px;
  }}
  .card {{
    background: #16213e;
    border-radius: 8px;
    overflow: hidden;
    transition: transform 0.15s;
  }}
  .card:hover {{ transform: translateY(-2px); }}
  .thumb-link {{
    display: block;
    position: relative;
    aspect-ratio: 16/9;
    overflow: hidden;
    background: #0f0f23;
  }}
  .thumb-link img {{
    width: 100%;
    height: 100%;
    object-fit: cover;
  }}
  .duration {{
    position: absolute;
    bottom: 6px;
    right: 6px;
    background: rgba(0,0,0,0.8);
    color: #fff;
    font-size: 12px;
    padding: 2px 6px;
    border-radius: 3px;
  }}
  .info {{ padding: 10px 12px; }}
  .title {{
    color: #e0e0e0;
    text-decoration: none;
    font-size: 14px;
    font-weight: 600;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    line-height: 1.3;
  }}
  .title:hover {{ color: #64b5f6; }}
  .meta {{
    margin-top: 8px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 12px;
  }}
  .date {{ color: #888; }}
  .transcript-link {{
    color: #4fc3f7;
    text-decoration: none;
    font-weight: 500;
  }}
  .transcript-link:hover {{ text-decoration: underline; }}
  .no-transcript {{ color: #666; font-style: italic; }}
</style>
</head>
<body>
  <h1>{title}</h1>
  <p class="stats">{total} videos &middot; {transcribed} transcribed</p>
  <div class="grid">
    {''.join(cards)}
  </div>
</body>
</html>"""

    with open(output_path, "w") as f:
        f.write(html)
    print(f"wrote {output_path} ({total} videos, {transcribed} transcribed)")


if __name__ == "__main__":
    videos = load_videos("audio", "transcripts")
    render_html("VSRF Videos", videos, "videos.html")

    livestreams = load_videos("livestreams_audio", "livestreams_transcripts")
    render_html("VSRF Livestreams", livestreams, "livestreams.html")
