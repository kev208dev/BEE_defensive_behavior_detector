#!/usr/bin/env bash
# Starts the backend for development, creating the venv on first run.
#
#   ./scripts/run_backend.sh            # listen on all interfaces, port 8000
#   PORT=9000 ./scripts/run_backend.sh  # different port
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../services/backend" && pwd)"
cd "$BACKEND_DIR"

PORT="${PORT:-8000}"
HOST="${HOST:-0.0.0.0}"

if [ ! -d .venv ]; then
  echo "Creating virtual environment..."
  python3 -m venv .venv
  ./.venv/bin/pip install --quiet --upgrade pip
  ./.venv/bin/pip install --quiet -r requirements.txt
fi

echo "Backend starting on http://${HOST}:${PORT}  (docs: /docs)"
echo
# Print the LAN address, because a phone cannot reach 127.0.0.1.
if command -v hostname >/dev/null 2>&1; then
  LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')" || true
  if [ -n "${LAN_IP:-}" ]; then
    echo "  Point the phone at: --dart-define=API_BASE_URL=http://${LAN_IP}:${PORT}"
    echo
  fi
fi

exec ./.venv/bin/uvicorn app.main:app --host "$HOST" --port "$PORT" --reload
