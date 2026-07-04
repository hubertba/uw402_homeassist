#!/usr/bin/env sh
set -eu

python3 <<'PY'
from html import escape
from pathlib import Path
from shutil import copy2
from time import time
from urllib.parse import quote

source_dir = Path("/config/www/reolink-videos")
cache_dir = Path("/config/www/reolink-cache/images")
gallery_dir = Path("/config/www/snapshots")
index_file = gallery_dir / "index.html"
tmp_file = gallery_dir / "index.html.tmp"
max_files = 200
max_age_seconds = 14 * 24 * 60 * 60
min_age_seconds = 60
refresh_seconds = 120
image_extensions = {".jpg", ".jpeg"}

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
                and path.suffix.lower() in image_extensions
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
            if path.is_file() and path.suffix.lower() in image_extensions
        ),
        key=media_sort_key,
        reverse=True,
    )[:max_files]

groups = {}
for path in files:
    relative_path = path.relative_to(cache_dir)
    url_path = "/".join(quote(part) for part in relative_path.parts)
    url = f"/local/reolink-cache/images/{url_path}"
    name = path.name
    parts = path.stem.split("_")
    event = parts[0] if parts else "Reolink"
    stamp = "_".join(parts[2:]) if len(parts) >= 3 else path.stem
    date = stamp[:8] if len(stamp) >= 8 else "Unbekannt"
    label = f"{event} - {stamp}"
    groups.setdefault(date, []).append(
        f'''      <a href="{url}" target="_blank" rel="noopener">
      <img src="{url}" loading="lazy" alt="{escape(label)}">
      <div class="label">{escape(label)}</div>
    </a>'''
    )

if groups:
    sections = []
    for date, date_items in groups.items():
        title = f"{date[6:8]}.{date[4:6]}.{date[:4]}" if len(date) == 8 else date
        sections.append(
            f'''  <section>
    <h2>{escape(title)}</h2>
    <div class="grid">
{chr(10).join(date_items)}
    </div>
  </section>'''
        )
    body = "\n".join(sections)
else:
    body = '  <div class="empty">Keine JPGs im Reolink-Share gefunden.</div>'

html = f"""<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Reolink Bewegungsbilder</title>
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
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 12px;
    }}
    a {{
      color: inherit;
      text-decoration: none;
      background: #1f2937;
      border: 1px solid #374151;
      border-radius: 8px;
      overflow: hidden;
      display: block;
    }}
    img {{
      display: block;
      width: 100%;
      aspect-ratio: 16 / 10;
      object-fit: cover;
      background: #030712;
    }}
    .label {{
      padding: 10px;
      font-size: 0.85rem;
      color: #d1d5db;
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
  <header><h1>Reolink Bewegungsbilder</h1><div class="count">{len(files)} Bilder aus den letzten 14 Tagen</div></header>
{body}
</body>
</html>
"""

write_if_changed(index_file, tmp_file, html)
PY
