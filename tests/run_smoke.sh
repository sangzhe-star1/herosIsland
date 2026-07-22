#!/usr/bin/env bash
# Headless smoke test. Boots every scene and every level, checks the data
# files agree, and fails on any script error.
#
#   ./tests/run_smoke.sh
#
# Takes about thirty seconds. Run it after every change.

set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-}"
if [[ -z "$GODOT" ]]; then
  for candidate in \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
    "$(command -v godot 2>/dev/null || true)" \
    "$(command -v godot4 2>/dev/null || true)"
  do
    if [[ -n "$candidate" && -x "$candidate" ]]; then GODOT="$candidate"; break; fi
  done
fi

if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
  echo "Could not find Godot. Set it explicitly:"
  echo "  GODOT=/path/to/Godot ./tests/run_smoke.sh"
  exit 2
fi

echo "Using: $GODOT"
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

# --quit-after bounds the run if a scene hangs instead of finishing.
"$GODOT" --headless --path . res://tests/SmokeTest.tscn --quit-after 3000 2>&1 | tee "$OUT"
STATUS=${PIPESTATUS[0]}

echo
echo "──────────────────────────────────────────"

# Godot reports script faults on stdout without failing the process, so the
# exit code alone is not enough to trust.
if grep -qE "SCRIPT ERROR|Parse Error|Parser Error" "$OUT"; then
  echo "SCRIPT ERRORS FOUND:"
  grep -nE "SCRIPT ERROR|Parse Error|Parser Error" "$OUT" | head -25
  exit 1
fi

if grep -q "SMOKE TEST FAILED" "$OUT"; then
  exit 1
fi

if ! grep -q "SMOKE TEST PASSED" "$OUT"; then
  echo "Test did not reach the end — it probably crashed or hung."
  echo "Exit status was $STATUS."
  exit 1
fi

echo "All good."
