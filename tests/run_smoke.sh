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
no_script_errors() {
  # $1 is a probe's captured output. A probe that faults halfway through
  # SKIPS the rest of its own checks and then prints PASSED, which is how a
  # broken companion test once reported success while never running. Any
  # probe output carrying a script fault fails the suite.
  # A missing file is not "no errors found", it is the check not running. That
  # is exactly how three of these went dead: the rm was moved above the call and
  # grep answered "no match" for a file that no longer existed, forever.
  if [[ ! -f "$1" ]]; then
    echo "HARNESS BUG: ${2:-a probe}'s output file is gone before it was checked."
    echo "  no_script_errors must run BEFORE the rm, and inside the same if."
    exit 1
  fi
  if grep -qE "SCRIPT ERROR|Parse Error|Parser Error" "$1"; then
    echo "SCRIPT ERRORS FOUND in ${2:-a probe}:"
    grep -nE "SCRIPT ERROR|Parse Error|Parser Error" "$1" | head -25
    exit 1
  fi
}

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
no_script_errors "$OUT" "Smoke Test"
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
no_script_errors "$PROG_OUT" "Progression Probe"
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
  # Inside the if, and BEFORE the rm. Both matter: outside the if this reads an
  # unset variable on a headless box with no xvfb (set -u kills the run), and
  # after the rm it greps a file that is gone, which grep answers "no match" --
  # so a probe that faulted halfway and still printed PASSED went unnoticed.
  no_script_errors "$TAP_OUT" "Tap Probe"
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
  no_script_errors "$DIFF_OUT" "Difficulty Probe"
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
  no_script_errors "$UP_OUT" "Upgrade Probe"
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
no_script_errors "$ECHO_OUT" "Echo Probe"
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

# The map probe opens the one door a child actually has. Every other test
# reaches a level the way a programmer does -- instantiating the scene with
# the id already set -- and the map was the one path nobody walked. It also
# plays a save from BEFORE the rebuild, full of level ids that no longer
# exist, which is the state every existing player is in.
# The voice check: every level finds its recorded line, the shared lines are
# all present, and asking for one really loads a stream. Cheap, and it is the
# difference between "the files are in the folder" and "a child hears them".
echo
echo "Running voice check..."
VOICE_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/VoiceCheck.tscn 2>&1 | tee "$VOICE_OUT"
if ! grep -q "VOICE CHECK PASSED" "$VOICE_OUT"; then
  rm -f "$VOICE_OUT"
  echo "Voice check failed."
  exit 1
fi
no_script_errors "$VOICE_OUT" "Voice Check"
rm -f "$VOICE_OUT"

# The result screen, loaded with everything it can possibly show at once. It
# is built out of ifs -- a badge line IF a badge was won, a level-up line IF
# the bar filled -- so the run that shows the most is the rarest one and the
# least looked at, and it was clipping all four buttons off the bottom.
echo
echo "Running result probe..."
RESULT_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/ResultProbe.tscn 2>&1 | tee "$RESULT_OUT"
if ! grep -q "RESULT PROBE PASSED" "$RESULT_OUT"; then
  rm -f "$RESULT_OUT"
  echo "Result probe failed."
  exit 1
fi
no_script_errors "$RESULT_OUT" "Result Probe"
rm -f "$RESULT_OUT"

# The one check that presses things. Every other check here answers "does it
# build" or "does it look right", and a level can pass both while being
# completely dead -- five templates shipped with a zero-sized tap area and
# twelve levels drew perfectly and ignored every press.
echo
echo "Running touch probe..."
TOUCH_OUT=$(mktemp)
timeout 240 "$GODOT" --headless --path . res://tests/TouchProbe.tscn 2>&1 | tee "$TOUCH_OUT"
if ! grep -q "TOUCH PROBE PASSED" "$TOUCH_OUT"; then
  rm -f "$TOUCH_OUT"
  echo "Touch probe failed."
  exit 1
fi
no_script_errors "$TOUCH_OUT" "Touch Probe"
rm -f "$TOUCH_OUT"

# 英雄基地 with a finger, at two screen shapes. The touch probe taps, and it
# taps by pushing a mouse event that the desktop emulates into a touch -- so
# the drag, which is the only thing this room is made of, was never tested the
# way an iPad delivers it. It did nothing at all.
echo
echo "Running studio probe..."
STUDIO_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/StudioProbe.tscn 2>&1 | tee "$STUDIO_OUT"
if ! grep -q "STUDIO PROBE PASSED" "$STUDIO_OUT"; then
  rm -f "$STUDIO_OUT"
  echo "Studio probe failed."
  exit 1
fi
no_script_errors "$STUDIO_OUT" "Studio Probe"
rm -f "$STUDIO_OUT"

# The parent's unlock-everything switch. It is only allowed to be a VIEW of the
# save: flip it both ways and his son's stars have to come out untouched.
echo
echo "Running unlock probe..."
UNLOCK_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/UnlockProbe.tscn 2>&1 | tee "$UNLOCK_OUT"
if ! grep -q "UNLOCK PROBE PASSED" "$UNLOCK_OUT"; then
  rm -f "$UNLOCK_OUT"
  echo "Unlock probe failed."
  exit 1
fi
no_script_errors "$UNLOCK_OUT" "Unlock Probe"
rm -f "$UNLOCK_OUT"

# The money. Above all: buying a thing must never cost him a 关卡星章 -- that
# is the first rule in the shop brief and the reason the currencies were
# collapsed, and a comment cannot keep it true.
echo
echo "Running shop probe..."
SHOP_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/ShopProbe.tscn 2>&1 | tee "$SHOP_OUT"
if ! grep -q "SHOP PROBE PASSED" "$SHOP_OUT"; then
  rm -f "$SHOP_OUT"
  echo "Shop probe failed."
  exit 1
fi
no_script_errors "$SHOP_OUT" "Shop Probe"
rm -f "$SHOP_OUT"

# How long a duel actually lasts, fought perfectly. Catches both ends: a boss
# that folds in fifteen seconds, and one that has no ending at all -- which is
# what the last fight in the game had.
echo
echo "Running duel length probe..."
DUEL_OUT=$(mktemp)
timeout 240 "$GODOT" --headless --path . res://tests/DuelLengthProbe.tscn 2>&1 | tee "$DUEL_OUT"
if ! grep -q "DUEL LENGTH PROBE PASSED" "$DUEL_OUT"; then
  rm -f "$DUEL_OUT"
  echo "Duel length probe failed."
  exit 1
fi
no_script_errors "$DUEL_OUT" "Duel Length Probe"
rm -f "$DUEL_OUT"

echo
echo "Running map probe..."
MAP_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/MapProbe.tscn 2>&1 | tee "$MAP_OUT"
if ! grep -q "MAP PROBE PASSED" "$MAP_OUT"; then
  rm -f "$MAP_OUT"
  echo "Map probe failed."
  exit 1
fi
no_script_errors "$MAP_OUT" "Map Probe"
rm -f "$MAP_OUT"

echo
echo "Running adventure probe..."
ADV_OUT=$(mktemp)
timeout 240 "$GODOT" --headless --path . res://tests/AdventureProbe.tscn 2>&1 | tee "$ADV_OUT"
if ! grep -q "ADVENTURE PROBE PASSED" "$ADV_OUT"; then
  rm -f "$ADV_OUT"
  echo "Adventure probe failed."
  exit 1
fi
no_script_errors "$ADV_OUT" "Adventure Probe"
rm -f "$ADV_OUT"

# 英雄小屋. A dressing-up room is almost entirely state -- what he owns, what
# he has on, which hero he is, what he was trying and did not buy -- and state
# is what a screenshot cannot show. The first thing it checks is that trying
# something on is free, because a room that charges for looking is a room a
# six-year-old stops touching.
echo
echo "Running hero house probe..."
HOUSE_OUT=$(mktemp)
timeout 240 "$GODOT" --headless --path . res://tests/HeroHouseProbe.tscn 2>&1 | tee "$HOUSE_OUT"
if ! grep -q "HERO HOUSE PROBE PASSED" "$HOUSE_OUT"; then
  rm -f "$HOUSE_OUT"
  echo "Hero house probe failed."
  exit 1
fi
no_script_errors "$HOUSE_OUT" "Hero House Probe"
rm -f "$HOUSE_OUT"

# 怪兽图鉴. A collection a child cannot finish is a broken promise, so this
# asks the only question that matters: is every one of the ten cards actually
# reachable by playing? It also checks the ten look like ten (all six bosses
# were one purple creature at six different sizes until this week) and that
# beating the same monster twice does not hand out the card twice.
echo
echo "Running album probe..."
ALBUM_OUT=$(mktemp)
"$GODOT" --headless --path . res://tests/AlbumProbe.tscn 2>&1 | tee "$ALBUM_OUT"
if ! grep -q "ALBUM PROBE PASSED" "$ALBUM_OUT"; then
  rm -f "$ALBUM_OUT"
  echo "Album probe failed."
  exit 1
fi
no_script_errors "$ALBUM_OUT" "Album Probe"
rm -f "$ALBUM_OUT"

# 星光菜园 with thumbs: turning earth, dragging a seed into a bed, picking a
# ripe one, and the way out -- in BOTH screen shapes, because a seed that lands
# in the right bed on a Mac can land in the wrong one on an iPad. Needs a
# window, so it is skipped on a headless box with no xvfb.
if [[ "$(uname)" != "Linux" ]] || [[ -n "${DISPLAY:-}" ]] || command -v xvfb-run >/dev/null 2>&1; then
  echo
  echo "Running garden touch probe..."
  GT_RUNNER=()
  if [[ "$(uname)" == "Linux" ]] && [[ -z "${DISPLAY:-}" ]]; then
    GT_RUNNER=(xvfb-run -a -s "-screen 0 1280x768x24")
    export LIBGL_ALWAYS_SOFTWARE=1
  fi
  GT_OUT=$(mktemp)
  timeout 240 "${GT_RUNNER[@]}" "$GODOT" --path . --rendering-driver opengl3 \
    res://tests/GardenTouchProbe.tscn 2>&1 | tee "$GT_OUT"
  if ! grep -q "GARDEN TOUCH PROBE PASSED" "$GT_OUT"; then
    rm -f "$GT_OUT"
    echo "Garden touch probe failed."
    exit 1
  fi
  no_script_errors "$GT_OUT" "Garden Touch Probe"
  rm -f "$GT_OUT"

  # 星光农场 as a place: panning, zooming, the go-home double tap, buttons that
  # stand over the ground without punching holes in it, and a seed that still
  # lands in the bed he aimed at AFTER the farm has been dragged sideways.
  # Everything the spatial farm added is a drag, and 丰收行动 already proved
  # that three layers of checks stay green while a drag is broken unless one
  # of them pushes a real InputEventScreenDrag. This is that layer.
  echo
  echo "Running farm world probe..."
  FW_OUT=$(mktemp)
  timeout 400 "${GT_RUNNER[@]}" "$GODOT" --path . --rendering-driver opengl3 \
    res://tests/FarmWorldProbe.tscn 2>&1 | tee "$FW_OUT"
  if ! grep -q "FARM WORLD PROBE PASSED" "$FW_OUT"; then
    rm -f "$FW_OUT"
    echo "Farm world probe failed."
    exit 1
  fi
  no_script_errors "$FW_OUT" "Farm World Probe"
  rm -f "$FW_OUT"

  # 丰收行动 with thumbs. harvest_probe checks the arithmetic of the gestures;
  # this one asks whether doing the move on a real screen picks anything up. It
  # was written the day the answer turned out to be NO for four of the eight
  # levels -- every one that sorts into more than one basket -- and for none of
  # the reasons a number could have told us.
  echo
  echo "Running harvest touch probe..."
  HT_OUT=$(mktemp)
  timeout 300 "${GT_RUNNER[@]}" "$GODOT" --path . --rendering-driver opengl3 \
    res://tests/HarvestTouchProbe.tscn 2>&1 | tee "$HT_OUT"
  if ! grep -q "HARVEST TOUCH PROBE PASSED" "$HT_OUT"; then
    rm -f "$HT_OUT"
    echo "Harvest touch probe failed."
    exit 1
  fi
  no_script_errors "$HT_OUT" "Harvest Touch Probe"
  rm -f "$HT_OUT"

  # The whole island on a tablet. Opens six templates, the map and the lesson
  # card twice each -- once at 1280x720 and once at the 1024x768 window that
  # gives the game a 1280x960 viewport -- and asserts that everything the child
  # touches sits in the same place on BOTH. This is the only check in the suite
  # that can see the bug this project has shipped twice: a game drawn into the
  # top three quarters of an iPad, working perfectly, with the bottom quarter
  # empty. Needs a big virtual screen, because a 768-tall window does not fit
  # on a 720-tall one.
  echo
  echo "Running tablet probe..."
  TB_RUNNER=()
  if [[ "$(uname)" == "Linux" ]] && [[ -z "${DISPLAY:-}" ]]; then
    TB_RUNNER=(xvfb-run -a -s "-screen 0 1920x1200x24")
    export LIBGL_ALWAYS_SOFTWARE=1
  fi
  TB_OUT=$(mktemp)
  timeout 300 "${TB_RUNNER[@]}" "$GODOT" --path . --rendering-driver opengl3 \
    res://tests/TabletProbe.tscn 2>&1 | tee "$TB_OUT"
  if ! grep -q "TABLET PROBE PASSED" "$TB_OUT"; then
    rm -f "$TB_OUT"
    echo "Tablet probe failed."
    exit 1
  fi
  no_script_errors "$TB_OUT" "Tablet Probe"
  rm -f "$TB_OUT"
fi

# 星光菜园's save. Runs late and before the save probe: it wipes the save file
# to walk the real first-launch path, and it puts everything back when it is
# done, but anything expecting to inherit a played-in game should come first.
echo
echo "Running garden probe..."
GARDEN_OUT=$(mktemp)
timeout 240 "$GODOT" --headless --path . res://tests/GardenProbe.tscn 2>&1 | tee "$GARDEN_OUT"
if ! grep -q "GARDEN PROBE PASSED" "$GARDEN_OUT"; then
  rm -f "$GARDEN_OUT"
  echo "Garden probe failed."
  exit 1
fi
no_script_errors "$GARDEN_OUT" "Garden Probe"
rm -f "$GARDEN_OUT"

# 丰收行动's gestures, as arithmetic. Every tolerance is a number -- how far off
# vertical a pull may be, how far a finger has to travel, how many reversals
# make a dig -- and a tolerance nobody asserts drifts until a six-year-old
# cannot pull a carrot up and nobody knows why.
echo
echo "Running harvest probe..."
HARVEST_OUT=$(mktemp)
timeout 240 "$GODOT" --headless --path . res://tests/HarvestProbe.tscn 2>&1 | tee "$HARVEST_OUT"
if ! grep -q "HARVEST PROBE PASSED" "$HARVEST_OUT"; then
  rm -f "$HARVEST_OUT"
  echo "Harvest probe failed."
  exit 1
fi
no_script_errors "$HARVEST_OUT" "Harvest Probe"
rm -f "$HARVEST_OUT"

# The clock. Everything here is unwatchable by playing: an app in a bag, a
# tablet whose date has been dragged backwards, a thing that grows overnight.
# It also carries the regression for the three-hours-in-a-bag bug, where time
# the app spent suspended was banked as time the child spent playing.
echo
echo "Running clock probe..."
CLOCK_OUT=$(mktemp)
timeout 240 "$GODOT" --headless --path . res://tests/ClockProbe.tscn 2>&1 | tee "$CLOCK_OUT"
if ! grep -q "CLOCK PROBE PASSED" "$CLOCK_OUT"; then
  rm -f "$CLOCK_OUT"
  echo "Clock probe failed."
  exit 1
fi
no_script_errors "$CLOCK_OUT" "Clock Probe"
rm -f "$CLOCK_OUT"

# The "what comes next" chain -- the big green button on the result screen.
# This probe existed for months without ever being wired in here, so nothing
# was checking that the chain does not loop back on itself or point at a level
# that was renamed away. It puts the save back when it is done.
echo
echo "Running next probe..."
NEXT_OUT=$(mktemp)
timeout 240 "$GODOT" --headless --path . res://tests/NextProbe.tscn 2>&1 | tee "$NEXT_OUT"
if ! grep -q "NEXT PROBE PASSED" "$NEXT_OUT"; then
  rm -f "$NEXT_OUT"
  echo "Next probe failed."
  exit 1
fi
no_script_errors "$NEXT_OUT" "Next Probe"
rm -f "$NEXT_OUT"

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
no_script_errors "$SAVE_OUT" "Save Probe"
rm -f "$SAVE_OUT"

echo "All good."
