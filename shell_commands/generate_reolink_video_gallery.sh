#!/usr/bin/env sh
set -eu

python3 <<'PY'
from html import escape
from pathlib import Path
from shutil import copy2
from time import time
from urllib.parse import quote

source_dir = Path("/config/www/reolink-videos")
cache_dir = Path("/config/www/reolink-cache/videos")
gallery_dir = Path("/config/www/reolink-video-gallery")
index_file = gallery_dir / "index.html"
tmp_file = gallery_dir / "index.html.tmp"
video_extensions = {".mp4", ".avi", ".mov", ".mkv", ".m4v", ".webm", ".ts"}
max_files = 50
max_age_seconds = 14 * 24 * 60 * 60
min_age_seconds = 60
refresh_seconds = 120

gallery_dir.mkdir(parents=True, exist_ok=True)
cache_dir.mkdir(parents=True, exist_ok=True)

def copy_if_needed(source_path, cache_path):
    if cache_path.exists() and source_path.stat().st_mtime <= cache_path.stat().st_mtime:
        return

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = cache_path.with_name(f"{cache_path.name}.tmp")
    copy2(source_path, tmp_path)
    tmp_path.replace(cache_path)

def prune_empty_dirs(root):
    for directory in sorted((path for path in root.rglob("*") if path.is_dir()), reverse=True):
        try:
            directory.rmdir()
        except OSError:
            pass

def write_if_changed(path, tmp_path, content):
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return False

    tmp_path.write_text(content, encoding="utf-8")
    tmp_path.replace(path)
    return True

def media_sort_key(path):
    for part in reversed(path.stem.split("_")):
        if len(part) == 14 and part.isdigit():
            return part

    return f"{path.stat().st_mtime:014.0f}"

if source_dir.exists():
    cutoff = time() - max_age_seconds
    min_mtime = time() - min_age_seconds
    source_files = sorted(
        (
            path
            for path in source_dir.rglob("*")
            if (
                path.is_file()
                and path.suffix.lower() in video_extensions
                and path.stat().st_mtime >= cutoff
                and path.stat().st_mtime <= min_mtime
            )
        ),
        key=media_sort_key,
        reverse=True,
    )[:max_files]
else:
    source_files = []

if source_files:
    wanted = set()
    for source_path in source_files:
        relative_path = source_path.relative_to(source_dir)
        cache_path = cache_dir / relative_path
        copy_if_needed(source_path, cache_path)
        wanted.add(cache_path)

    for cache_path in cache_dir.rglob("*"):
        if cache_path.is_file() and cache_path not in wanted:
            cache_path.unlink(missing_ok=True)
    prune_empty_dirs(cache_dir)

    files = [cache_dir / path.relative_to(source_dir) for path in source_files]
else:
    files = sorted(
        (
            path
            for path in cache_dir.rglob("*")
            if path.is_file() and path.suffix.lower() in video_extensions
        ),
        key=media_sort_key,
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
  <script>
    setTimeout(() => {{
      const url = new URL(window.location.href);
      url.searchParams.set("refresh", Date.now().toString());
      window.location.replace(url.toString());
    }}, {refresh_seconds * 1000});
  </script>
</head>
<body>
  <header><h1>Reolink Videos</h1><div class="count">{len(files)} Videos aus den letzten 14 Tagen</div></header>
{body}
</body>
</html>
"""

write_if_changed(index_file, tmp_file, html)
PY
