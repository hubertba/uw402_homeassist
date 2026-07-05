#!/usr/bin/env sh
set -eu

config_dir="${CONFIG_DIR:-/homeassistant}"
request_file="$config_dir/www/reolink-gallery-refresh.request"
state_file="/tmp/reolink-gallery-refresh.last-request"
lock_dir="/tmp/reolink-gallery-refresh.lock"
delay_seconds="${REFRESH_DELAY_SECONDS:-90}"

[ -f "$request_file" ] || exit 0

request_mtime="$(stat -c %Y "$request_file" 2>/dev/null || stat -f %m "$request_file")"
last_mtime="0"
[ -f "$state_file" ] && last_mtime="$(cat "$state_file")"

[ "$request_mtime" -gt "$last_mtime" ] || exit 0

if ! mkdir "$lock_dir" 2>/dev/null; then
  exit 0
fi

cleanup() {
  rmdir "$lock_dir" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep "$delay_seconds"
"$config_dir/shell_commands/generate_snapshot_gallery.sh"
"$config_dir/shell_commands/generate_reolink_video_gallery.sh"
echo "$request_mtime" > "$state_file"
