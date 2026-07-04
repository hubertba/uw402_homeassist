#!/usr/bin/env sh
set -eu

python3 <<'PY'
from html import escape
from pathlib import Path
from shutil import copy2
from urllib.parse import quote

source_dir = Path("/config/www/reolink-videos")
cache_dir = Path("/config/www/reolink-cache/videos")
gallery_dir = Path("/config/www/reolink-video-gallery")
index_file = gallery_dir / "index.html"
tmp_file = gallery_dir / "index.html.tmp"
video_extensions = {".mp4", ".avi", ".mov", ".mkv", ".m4v", ".webm", ".ts"}
max_files = 50

gallery_dir.mkdir(parents=True, exist_ok=True)
cache_dir.mkdir(parents=True, exist_ok=True)

if source_dir.exists():
    source_files = sorted(
        (
            path
            for path in source_dir.rglob("*")
            if path.is_file() and path.suffix.lower() in video_extensions
        ),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )[:max_files]
else:
    source_files = []

if source_files:
    wanted = set()
    for source_path in source_files:
        relative_path = source_path.relative_to(source_dir)
        cache_path = cache_dir / relative_path
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        if not cache_path.exists() or source_path.stat().st_mtime > cache_path.stat().st_mtime:
            copy2(source_path, cache_path)
        wanted.add(cache_path)

    for cache_path in cache_dir.rglob("*"):
        if cache_path.is_file() and cache_path not in wanted:
            cache_path.unlink(missing_ok=True)

    files = [cache_dir / path.relative_to(source_dir) for path in source_files]
else:
    files = sorted(
        (
            path
            for path in cache_dir.rglob("*")
            if path.is_file() and path.suffix.lower() in video_extensions
        ),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )[:max_files]

groups = {}
for path in files:
    relative_path = path.relative_to(cache_dir)
    url_path = "/".join(quote(part) for part in relative_path.parts)
    url = f"/local/reolink-cache/videos/{url_path}"
    label = relative_path.as_posix()
    parent = relative_path.parent.as_posix()
    group = parent if parent != "." else "Videos"
    groups.setdefault(group, []).append(
        f'''      <article>
        <video controls preload="metadata" src="{url}"></video>
        <a href="{url}" target="_blank" rel="noopener">{escape(label)}</a>
      </article>'''
    )

if groups:
    sections = []
    for group, items in groups.items():
        sections.append(
            f'''  <section>
    <h2>{escape(group)}</h2>
    <div class="grid">
{chr(10).join(items)}
    </div>
  </section>'''
        )
    body = "\n".join(sections)
else:
    body = '  <div class="empty">Keine Videodateien im Reolink-Share gefunden.</div>'

html = f"""<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="300">
  <title>Reolink Videos</title>
  <style>
    :root {{
      color-scheme: light dark;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #111827;
      color: #f9fafb;
    }}
    body {{
      margin: 0;
      padding: 16px;
      background: #111827;
    }}
    header {{
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 16px;
    }}
    h1 {{
      margin: 0;
      font-size: 1.15rem;
      font-weight: 650;
    }}
    h2 {{
      margin: 22px 0 10px;
      font-size: 0.95rem;
      font-weight: 650;
      color: #e5e7eb;
    }}
    .count {{
      color: #9ca3af;
      font-size: 0.9rem;
      white-space: nowrap;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
      gap: 12px;
    }}
    article {{
      background: #1f2937;
      border: 1px solid #374151;
      border-radius: 8px;
      overflow: hidden;
    }}
    video {{
      display: block;
      width: 100%;
      aspect-ratio: 16 / 10;
      object-fit: contain;
      background: #030712;
    }}
    a {{
      display: block;
      padding: 10px;
      color: #d1d5db;
      font-size: 0.85rem;
      text-decoration: none;
      overflow-wrap: anywhere;
    }}
    .empty {{
      color: #d1d5db;
      background: #1f2937;
      border: 1px solid #374151;
      border-radius: 8px;
      padding: 16px;
    }}
  </style>
</head>
<body>
  <header><h1>Reolink Videos</h1><div class="count">{len(files)} Videos</div></header>
{body}
</body>
</html>
"""

tmp_file.write_text(html, encoding="utf-8")
tmp_file.replace(index_file)
PY
