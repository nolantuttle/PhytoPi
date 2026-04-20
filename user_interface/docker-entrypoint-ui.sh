#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="${BUNDLE_DIR:-/app/bundle}"
BINARY="$BUNDLE_DIR/phytopi_dashboard"

export DISPLAY="${DISPLAY:-:0}"

if [ ! -f "$BINARY" ]; then
  echo "[ui] ERROR: binary not found at $BINARY" >&2
  echo "[ui] Build with: flutter build linux --dart-define=..." >&2
  exit 1
fi

APP_PID=0

start_app() {
  echo "[ui] Starting phytopi_dashboard (DISPLAY=$DISPLAY)..."
  cd "$BUNDLE_DIR"
  ./phytopi_dashboard &
  APP_PID=$!
  echo "[ui] PID: $APP_PID"
}

start_app

# Restart whenever the binary is replaced (e.g. after 'flutter build linux')
while inotifywait -e close_write,moved_to,create "$BINARY" 2>/dev/null; do
  echo "[ui] Binary updated – restarting..."
  kill "$APP_PID" 2>/dev/null || true
  wait "$APP_PID" 2>/dev/null || true
  sleep 1
  start_app
done
