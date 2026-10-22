#!/bin/bash
# Copy the game's save off a connected iPad (read-only) and optionally audit it.
# Double-click in Finder to pull and audit, or run from Terminal (see --help).
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -eq 0 ]; then set -- --audit; fi
exec python3 tools/pull_ipad_save.py "$@"
