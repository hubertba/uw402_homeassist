#!/usr/bin/env sh
set -eu

python3 <<'PY'
from html import escape
from pathlib import Path

snapshot_dir = Path("/config/www/snapshots")
index_file = snapshot_dir / "index.html"
tmp_file = snapshot_dir / "index.html.tmp"

snapshot_dir.mkdir(parents=True, exist_ok=True)
files = sorted(
    snapshot_dir.glob("driveway_motion_*.jpg"),
    key=lambda path: path.stat().st_mtime,
    reverse=True,
)

items = []
for path in files:
    name = path.name
    label = name.removeprefix("driveway_motion_").removesuffix(".jpg")
    items.append(
        f'''    <a href="/local/snapshots/{escape(name)}" target="_blank" rel="noopener">
      <img src="/local/snapshots/{escape(name)}" loading="lazy" alt="{escape(label)}">
      <div class="label">{escape(label)}</div>
    </a>'''
    )

if items:
    body = "  <main class=\"grid\">\\n" + "\\n".join(items) + "\\n  </main>"
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
  <header><h1>Reolink Bewegungsbilder</h1><div class="count">{len(files)} Bilder</div></header>
{body}
</body>
</html>
"""

tmp_file.write_text(html, encoding="utf-8")
tmp_file.replace(index_file)
PY
