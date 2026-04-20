#!/usr/bin/env bash
# PhytoPi auto-updater
# Run via systemd timer (phytopi-updater.timer) or manually: bash scripts/update.sh
#
# What it does on each run:
#   1. git pull (if new commits exist)
#   2. user_interface/** changed  → flutter build linux  (ui container auto-restarts via inotifywait)
#   3. Controller/camera/ai/updater sources changed → docker compose build + up -d that service
set -euo pipefail

PHYTO_DIR="${PHYTO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
FLUTTER="${FLUTTER_BIN:-/home/phytopi/flutter/bin/flutter}"
COMPOSE_FILE="$PHYTO_DIR/docker-compose.rpi.yml"
COMPOSE_CMD="docker compose"

log() { echo "[phytopi-update] $(date '+%H:%M:%S') $*"; }

cd "$PHYTO_DIR"

# ── 1. Check for upstream changes ────────────────────────────────────────────
git fetch origin --quiet

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse "@{u}")

if [ "$LOCAL" = "$REMOTE" ]; then
  log "Already up to date ($(git rev-parse --short HEAD))."
  exit 0
fi

CHANGED=$(git diff --name-only "$LOCAL" "$REMOTE")
log "Updating $(git rev-parse --short "$LOCAL") → $(git rev-parse --short "$REMOTE")"
log "Changed files:"
echo "$CHANGED" | sed 's/^/    /'

git pull --ff-only --quiet

# ── 2. UI: rebuild Flutter Linux bundle if dart/assets changed ────────────────
UI_FILES=$(echo "$CHANGED" | grep -c "^user_interface/" || true)
if [ "$UI_FILES" -gt 0 ]; then
  log "UI source changed ($UI_FILES file(s)) – rebuilding Flutter Linux bundle..."

  # Parse key=value env files; strips quotes and ignores comments
  load_env() {
    local file="$1"
    [ -f "$file" ] || return 0
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ "$line" =~ ^[[:space:]]*$ ]] && continue
      key="${line%%=*}"
      val="${line#*=}"
      val="${val%\"}"
      val="${val#\"}"
      val="${val%\'}"
      val="${val#\'}"
      export "$key=$val"
    done < "$file"
  }

  # Load credentials: .env first (device-specific), then .env.kiosk (UI-specific)
  load_env "$PHYTO_DIR/.env"
  load_env "$PHYTO_DIR/user_interface/.env.kiosk"

  cd "$PHYTO_DIR/user_interface"
  "$FLUTTER" build linux --release \
    --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
    --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
    --dart-define=KIOSK_MODE=true \
    --dart-define=PHYTOPI_STREAM_URL="${PHYTOPI_STREAM_URL:-http://phytopi.local:8000/stream.mjpg}"
  cd "$PHYTO_DIR"

  # inotifywait inside the ui container detects the new binary and auto-restarts
  log "Flutter build done – ui container will auto-restart."
fi

# ── 3. Docker services: rebuild only what changed ────────────────────────────
rebuild() {
  local svc="$1"
  log "Rebuilding + restarting Docker service: $svc"
  $COMPOSE_CMD -f "$COMPOSE_FILE" build "$svc"
  $COMPOSE_CMD -f "$COMPOSE_FILE" up -d "$svc"
}

echo "$CHANGED" | grep -qE "^controller/(Dockerfile\.sensors|src/|libs/)" \
  && rebuild sensors || true

echo "$CHANGED" | grep -qE "^controller/(Dockerfile\.camera|scripts/stream)" \
  && rebuild camera || true

echo "$CHANGED" | grep -qE "^controller/(Dockerfile\.ai|scripts/ai_worker)" \
  && rebuild ai || true

echo "$CHANGED" | grep -qE "^docker/updater/" \
  && rebuild updater || true

log "Update complete."
