#!/usr/bin/env sh
set -eu

request_file="/config/www/reolink-gallery-refresh.request"

mkdir -p "$(dirname "$request_file")"
date -Iseconds > "$request_file"
