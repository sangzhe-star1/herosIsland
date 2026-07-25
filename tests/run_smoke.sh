#!/usr/bin/env bash
# Headless smoke test. Boots every scene and every level, checks the data
# files agree, and fails on any script error.
#
#   ./tests/run_smoke.sh
#
# Takes about thirty seconds. Run it after every change.

set -uo pipefail
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

GODOT="$(find_godot)"

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

echo "Using: $GODOT"
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

# Refresh the global class cache before testing.
#
# Godot only rescans for new `class_name` scripts when the editor opens the
# project. Headless runs read .godot/global_script_class_cache.cfg as-is, so a
# class added since the editor last ran is simply unknown, and every script
# referencing it fails to parse. That looks exactly like a code bug and is not
# one -- it cost a full debugging round once already.
echo "Refreshing class cache..."
if ! "$GODOT" --headless --path . --import >/dev/null 2>&1; then
  # --import is newer; older builds need a full editor open-and-quit.
  "$GODOT" --headless --path . --editor --quit >/dev/null 2>&1 || true
fi

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

# The battle probe drives the Monster Arena the way a finger would: taps
# through the input handler, dud handling, meter fill, and the full win
# sequence through to level_finished. Scenes instantiating is not the same
# as a game playing; this covers the difference for the battle template.
echo
echo "Running battle interaction probe..."
BATTLE_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/BattleProbe.tscn 2>&1 | tee "$BATTLE_OUT"
if ! grep -q "BATTLE PROBE PASSED" "$BATTLE_OUT"; then
  rm -f "$BATTLE_OUT"
  echo "Battle probe failed."
  exit 1
fi
rm -f "$BATTLE_OUT"

# The progression probe guards the meta-layer: XP maths, improvement-only
# coins, the sticker economy, and challenge scaling actually gating
# completion (a bug the probe caught once already).
echo
echo "Running progression probe..."
PROG_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/ProgressionProbe.tscn 2>&1 | tee "$PROG_OUT"
if ! grep -q "PROGRESSION PROBE PASSED" "$PROG_OUT"; then
  rm -f "$PROG_OUT"
  echo "Progression probe failed."
  exit 1
fi
rm -f "$PROG_OUT"

# The duel probe drives the skill wheel like thumbs would: cooldown gates,
# the ult economy, shield reflections, and the harmless unshielded hit.
echo
echo "Running duel probe..."
DUEL_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/DuelProbe.tscn 2>&1 | tee "$DUEL_OUT"
if ! grep -q "DUEL PROBE PASSED" "$DUEL_OUT"; then
  rm -f "$DUEL_OUT"
  echo "Duel probe failed."
  exit 1
fi
rm -f "$DUEL_OUT"

# The save probe tears the save file the way a force-closed tablet does and
# proves the child's history survives. Runs LAST: it ends on a deliberately
# fresh save, and any probe after it would inherit that emptiness.
echo
echo "Running save probe..."
SAVE_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/SaveProbe.tscn 2>&1 | tee "$SAVE_OUT"
if ! grep -q "SAVE PROBE PASSED" "$SAVE_OUT"; then
  rm -f "$SAVE_OUT"
  echo "Save probe failed."
  exit 1
fi
rm -f "$SAVE_OUT"

echo "All good."
