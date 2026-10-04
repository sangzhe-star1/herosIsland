#!/usr/bin/env bash
# Run the original smoke suite in one temporary project and isolated save.
# Usage: ./tests/run_smoke.sh [qa_run options]
set -euo pipefail
cd "$(dirname "$0")/.."

find_godot() {
  # 1. Explicitly provided
  if [[ -n "${GODOT:-}" && -x "${GODOT:-}" ]]; then echo "$GODOT"; return; fi

  # 2. The usual places, including unzipped-but-never-moved
  local candidate
  for candidate in \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Desktop/Godot.app/Contents/MacOS/Godot" \
    "$(command -v godot 2>/dev/null || true)" \
    "$(command -v godot4 2>/dev/null || true)"
  do
    if [[ -n "$candidate" && -x "$candidate" ]]; then echo "$candidate"; return; fi
  done

  # 3. Ask Spotlight. Catches any location, including odd ones.
  if command -v mdfind >/dev/null 2>&1; then
    while IFS= read -r app; do
      [[ -x "$app/Contents/MacOS/Godot" ]] && { echo "$app/Contents/MacOS/Godot"; return; }
    done < <(mdfind "kMDItemFSName == 'Godot.app'" 2>/dev/null | head -5)
  fi

  # 4. Last resort: the path the editor recorded when it last opened this
  #    project. Works even for a translocated app, as long as that randomised
  #    mount still exists.
  local meta=".godot/editor/project_metadata.cfg"
  if [[ -f "$meta" ]]; then
    local recorded
    recorded=$(grep -o '"[^"]*Godot.app/Contents/MacOS/Godot"' "$meta" 2>/dev/null | tr -d '"' | head -1)
    if [[ -n "$recorded" && -x "$recorded" ]]; then echo "$recorded"; return; fi
  fi
}

GODOT="$(find_godot || true)"

if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
  cat <<'MSG'
Could not find Godot.

If you are on macOS and launched Godot straight from the download, macOS is
running it from a randomised read-only path (App Translocation) where nothing
can find it. Fix it once and it stays fixed:

    mv ~/Downloads/Godot.app /Applications/

That also clears the translocation, which can cause odd behaviour in the
editor itself.

Or point at it directly:

    GODOT=/path/to/Godot.app/Contents/MacOS/Godot ./tests/run_smoke.sh
MSG
  exit 2
fi

case "$GODOT" in
  *AppTranslocation*)
    echo "NOTE: Godot is running from a translocated path."
    echo "      Move it to /Applications to make this reliable."
    ;;
esac

exec python3 tests/qa_run.py --godot "$GODOT" --suite tests/smoke_suite.json "$@"
