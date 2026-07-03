#!/usr/bin/env sh
set -eu

python3 <<'PY'
from html import escape
from pathlib import Path
from time import time

snapshot_dir = Path("/config/www/snapshots")
index_file = snapshot_dir / "index.html"
tmp_file = snapshot_dir / "index.html.tmp"
max_files = 200
max_age_seconds = 14 * 24 * 60 * 60

snapshot_dir.mkdir(parents=True, exist_ok=True)
files = sorted(
    snapshot_dir.glob("driveway_*.jpg"),
    key=lambda path: path.stat().st_mtime,
    reverse=True,
)

cutoff = time() - max_age_seconds
for index, path in enumerate(files):
    if index >= max_files or path.stat().st_mtime < cutoff:
        path.unlink(missing_ok=True)

files = sorted(
    snapshot_dir.glob("driveway_*.jpg"),
    key=lambda path: path.stat().st_mtime,
    reverse=True,
)

items = []
groups = {}
for path in files:
    name = path.name
    parts = name.removesuffix(".jpg").split("_")
    event = parts[1].capitalize() if len(parts) >= 2 else "Erkennung"
    stamp = "_".join(parts[2:]) if len(parts) >= 4 else path.stem
    date = stamp[:8] if len(stamp) >= 8 else "Unbekannt"
    label = f"{event} - {stamp}"
    groups.setdefault(date, []).append(
        f'''      <a href="/local/snapshots/{escape(name)}" target="_blank" rel="noopener">
      <img src="/local/snapshots/{escape(name)}" loading="lazy" alt="{escape(label)}">
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
    body = '  <div class="empty">Noch keine gespeicherten Bewegungsbilder vorhanden.</div>'

html = f"""<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="60">
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
</head>
<body>
  <header><h1>Reolink Bewegungsbilder</h1><div class="count">{len(files)} Bilder, max. {max_files} / 14 Tage</div></header>
{body}
</body>
</html>
"""

tmp_file.write_text(html, encoding="utf-8")
tmp_file.replace(index_file)
PY
