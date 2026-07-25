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

# The tap probe pushes ONE real click through the input pipeline and counts
# how many presses a pad hears. Touch emulation makes a click arrive twice;
# UiKit.is_press() is what keeps it at one, and this is its regression.
# Needs a window, so it is skipped on a headless box with no xvfb.
if [[ "$(uname)" != "Linux" ]] || [[ -n "${DISPLAY:-}" ]] || command -v xvfb-run >/dev/null 2>&1; then
  echo
  echo "Running tap probe..."
  TAP_RUNNER=()
  if [[ "$(uname)" == "Linux" ]] && [[ -z "${DISPLAY:-}" ]]; then
    TAP_RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24")
    export LIBGL_ALWAYS_SOFTWARE=1
  fi
  TAP_OUT=$(mktemp)
  "${TAP_RUNNER[@]}" "$GODOT" --path . --rendering-driver opengl3 \
    res://tests/TapProbe.tscn 2>&1 | tee "$TAP_OUT"
  if ! grep -q "TAP PROBE PASSED" "$TAP_OUT"; then
    rm -f "$TAP_OUT"
    echo "Tap probe failed."
    exit 1
  fi
  rm -f "$TAP_OUT"
fi

# The difficulty probe boots one level per template at Gentle and again at
# Brave and checks the knob each template promises to bend. A dial that
# changes a saved number and nothing else is the easiest bug to ship and
# the hardest to notice: everything still runs, it is just all the same.
if [[ "$(uname)" != "Linux" ]] || [[ -n "${DISPLAY:-}" ]] || command -v xvfb-run >/dev/null 2>&1; then
  echo
  echo "Running difficulty probe..."
  DIFF_RUNNER=()
  if [[ "$(uname)" == "Linux" ]] && [[ -z "${DISPLAY:-}" ]]; then
    DIFF_RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24")
    export LIBGL_ALWAYS_SOFTWARE=1
  fi
  DIFF_OUT=$(mktemp)
  "${DIFF_RUNNER[@]}" "$GODOT" --path . --rendering-driver opengl3 \
    res://tests/DifficultyProbe.tscn 2>&1 | tee "$DIFF_OUT"
  if ! grep -q "DIFFICULTY PROBE PASSED" "$DIFF_OUT"; then
    rm -f "$DIFF_OUT"
    echo "Difficulty probe failed."
    exit 1
  fi
  rm -f "$DIFF_OUT"
fi

# The upgrade probe proves a drafted skill actually changes the gun --
# cooldown, radius, damage, bolt count AND colour. Needs a window.
if [[ "$(uname)" != "Linux" ]] || [[ -n "${DISPLAY:-}" ]] || command -v xvfb-run >/dev/null 2>&1; then
  echo
  echo "Running upgrade probe..."
  UP_RUNNER=()
  if [[ "$(uname)" == "Linux" ]] && [[ -z "${DISPLAY:-}" ]]; then
    UP_RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24")
    export LIBGL_ALWAYS_SOFTWARE=1
  fi
  UP_OUT=$(mktemp)
  "${UP_RUNNER[@]}" "$GODOT" --path . --rendering-driver opengl3 \
    res://tests/UpgradeProbe.tscn 2>&1 | tee "$UP_OUT"
  if ! grep -q "UPGRADE PROBE PASSED" "$UP_OUT"; then
    rm -f "$UP_OUT"
    echo "Upgrade probe failed."
    exit 1
  fi
  rm -f "$UP_OUT"
fi

# The echo probe drives Dance Mode / Light Song the way thumbs do: phrase
# generation, the handover, the note lamps, and a completed phrase scoring.
echo
echo "Running echo probe..."
ECHO_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/EchoProbe.tscn 2>&1 | tee "$ECHO_OUT"
if ! grep -q "ECHO PROBE PASSED" "$ECHO_OUT"; then
  rm -f "$ECHO_OUT"
  echo "Echo probe failed."
  exit 1
fi
rm -f "$ECHO_OUT"

# The adventure probe walks a whole platform_adventure level with the two
# buttons a child has -- collect, spring, gem, shut gate, plate, chest -- and
# checks every placed thing is inside the hero's real jump.
# NOTE -- the battle and duel probes are parked, not deleted.
#
# They drive `monster_battle` and `monster_duel`, two of the twelve templates
# the 54-level rebuild took off the map. The templates and their scenes are
# still on disk and still work; nothing points a level at them any more. Put
# a `"game_type": "monster_duel"` level back into levels.json and restore the
# probe blocks from git history (they were removed in the Phase D commit) and
# both come straight back.

echo
echo "Running adventure probe..."
ADV_OUT=$(mktemp)
timeout 240 "$GODOT" --headless --path . res://tests/AdventureProbe.tscn 2>&1 | tee "$ADV_OUT"
if ! grep -q "ADVENTURE PROBE PASSED" "$ADV_OUT"; then
  rm -f "$ADV_OUT"
  echo "Adventure probe failed."
  exit 1
fi
rm -f "$ADV_OUT"

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
