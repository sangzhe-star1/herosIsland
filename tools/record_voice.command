#!/bin/bash
# Record voice lines in your own voice from the Mac microphone.
# Double-click in Finder, or run from Terminal with options (see --help).
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 tools/record_voice.py "$@"
