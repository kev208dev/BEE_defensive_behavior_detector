#!/usr/bin/env bash
# Runs every check: backend tests, Flutter analysis, Flutter tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

echo "=============================================="
echo " Backend — pytest"
echo "=============================================="
cd "$ROOT/services/backend"
if [ ! -d .venv ]; then
  python3 -m venv .venv
  ./.venv/bin/pip install --quiet --upgrade pip
  ./.venv/bin/pip install --quiet -r requirements.txt
fi
./.venv/bin/python -m pytest || FAILED=1

echo
echo "=============================================="
echo " Mobile — flutter analyze"
echo "=============================================="
cd "$ROOT/apps/mobile"
if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not on PATH — skipping mobile checks."
  exit "$FAILED"
fi
flutter pub get >/dev/null
flutter analyze || FAILED=1

echo
echo "=============================================="
echo " Mobile — flutter test"
echo "=============================================="
flutter test || FAILED=1

echo
if [ "$FAILED" -eq 0 ]; then
  echo "All checks passed."
else
  echo "Some checks FAILED."
fi
exit "$FAILED"
