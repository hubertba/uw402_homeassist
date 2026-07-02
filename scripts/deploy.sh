#!/usr/bin/env bash
set -euo pipefail

REMOTE="${REMOTE:-ha}"
REMOTE_DIR="${REMOTE_DIR:-/homeassistant}"
CHECK_CONFIG="${CHECK_CONFIG:-1}"
RESTART_HA="${RESTART_HA:-1}"
DRY_RUN=0

usage() {
  cat <<'EOF'
Deploy the local Home Assistant config to the HA host over SSH.

Usage:
  scripts/deploy.sh [--dry-run] [--no-check] [--no-restart]

Environment:
  REMOTE=ha                  SSH host alias
  REMOTE_DIR=/homeassistant  Remote Home Assistant config directory
  CHECK_CONFIG=1             Run "ha core check" before restarting
  RESTART_HA=1               Run "ha core restart" after deploy
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --no-check)
      CHECK_CONFIG=0
      ;;
    --no-restart)
      RESTART_HA=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

cd "$(dirname "$0")/.."

RSYNC_ARGS=(
  -az
  --delete
  --omit-dir-times
  --no-owner
  --no-group
  --rsync-path='sudo rsync'
  --exclude='.git/'
  --exclude='.gitignore'
  --exclude='README.md'
  --exclude='scripts/'
  --exclude='.HA_VERSION'
  --exclude='.ha_run.lock'
  --exclude='.cache/'
  --exclude='.cloud/'
  --exclude='.storage/'
  --exclude='deps/'
  --exclude='tts/'
  --exclude='codex_tasks/'
  --exclude='home-assistant*.log*'
  --exclude='home-assistant_v2.db*'
  --exclude='secrets.yaml'
  --exclude='secrets.example.yaml'
  --exclude='*.bak'
  --exclude='*.backup'
  --exclude='*.tmp'
  --exclude='configuration.yaml.bak-*'
  --exclude='__pycache__/'
  --exclude='*.py[cod]'
  --exclude='custom_components/hacs/'
  --exclude='www/'
)

if [[ "$DRY_RUN" == "1" ]]; then
  RSYNC_ARGS+=(--dry-run --itemize-changes)
fi

echo "Deploying to ${REMOTE}:${REMOTE_DIR}/"
rsync "${RSYNC_ARGS[@]}" ./ "${REMOTE}:${REMOTE_DIR}/"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run complete. Nothing was changed."
  exit 0
fi

if [[ "$CHECK_CONFIG" == "1" ]]; then
  echo "Checking Home Assistant configuration..."
  if [[ -n "${HASS_SERVER:-}" && -n "${HASS_TOKEN:-}" ]] && command -v hass-cli >/dev/null 2>&1; then
    hass-cli service call homeassistant.check_config
  else
    ssh "$REMOTE" "ha core check"
  fi
fi

if [[ "$RESTART_HA" == "1" ]]; then
  echo "Restarting Home Assistant..."
  if [[ -n "${HASS_SERVER:-}" && -n "${HASS_TOKEN:-}" ]] && command -v hass-cli >/dev/null 2>&1; then
    hass-cli service call homeassistant.restart
  else
    ssh "$REMOTE" "ha core restart"
  fi
fi

echo "Deploy complete."
