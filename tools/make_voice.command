#!/bin/bash
# Fill only missing, referenced voice lines from docs/VOICE_SCRIPT.md with the
# Mac's built-in Chinese voice. Existing recordings are never overwritten.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 tools/make_missing_voice.py "$@"
