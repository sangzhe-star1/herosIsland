#!/usr/bin/env bash
# Render every screen in the game to a PNG, without a person at the keyboard.
#
#   ./tests/shots.sh                 # -> /tmp/heroes-shots/
#   ./tests/shots.sh out/            # -> out/
#   ./tests/shots.sh out/ home map   # just those two
#
# Why this exists: this project was written for months without anyone able to
# SEE it. PLAN.md says so in its first paragraph, and it has already cost a
# full debug cycle. Static checking cannot catch a label that overlaps an icon,
# a prop that draws on top of a button, or a splash screen that comes out solid
# navy because a failsafe rectangle sits in front of the world. All three were
# real, and all three were found by looking at the output of this script.
#
# On a headless Linux box it needs a virtual display; on macOS it just works:
#   sudo apt-get install xvfb libgl1-mesa-dri     # Linux only
#
# Takes about twenty seconds for the full set.

set -uo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-/tmp/heroes-shots}"
shift || true
mkdir -p "$OUT"

# Same search as run_smoke.sh, so one GODOT= works for both.
find_godot() {
  if [[ -n "${GODOT:-}" && -x "${GODOT:-}" ]]; then echo "$GODOT"; return; fi
  local candidate
  for candidate in \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" \
    "$(command -v godot 2>/dev/null || true)" \
    "$(command -v godot4 2>/dev/null || true)"
  do
    if [[ -n "$candidate" && -x "$candidate" ]]; then echo "$candidate"; return; fi
  done
}

GODOT="$(find_godot)"
if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
  echo "Could not find Godot. Set GODOT=/path/to/Godot and try again."
  exit 1
fi

# A virtual display on Linux; the real one everywhere else. Software GL keeps
# it working on a machine with no GPU, which is what CI and a sandbox are.
RUNNER=()
if [[ "$(uname)" == "Linux" ]] && [[ -z "${DISPLAY:-}" ]]; then
  if ! command -v xvfb-run >/dev/null 2>&1; then
    echo "Needs xvfb on a headless Linux box: sudo apt-get install xvfb libgl1-mesa-dri"
    exit 1
  fi
  RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24")
  export LIBGL_ALWAYS_SOFTWARE=1
fi

# name | scene | level id. The level primes GameManager so a template renders
# as a real level rather than falling back to its debug data.
SHOTS=(
  "boot|res://scenes/boot/Boot.tscn|"
  "home|res://scenes/home/Home.tscn|"
  "map|res://scenes/map/WorldMap.tscn|"
  "house|res://scenes/house/HeroHouse.tscn|"
  "rewards|res://scenes/reward/RewardCenter.tscn|"
  "parent|res://scenes/parent/ParentCenter.tscn|"
  "result|res://scenes/ui/ResultScreen.tscn|"
  "traffic|res://scenes/minigames/traffic_crossing/TrafficCrossing.tscn|safety_traffic_01"
  "sorting|res://scenes/minigames/item_sorting/ItemSorting.tscn|piglet_town_01"
  "counting|res://scenes/minigames/item_sorting/ItemSorting.tscn|piglet_town_02"
  "energy|res://scenes/minigames/collect_energy/CollectEnergy.tscn|hero_city_01"
  "tower|res://scenes/minigames/collect_energy/CollectEnergy.tscn|hero_city_03"
  "rescue|res://scenes/minigames/animal_rescue/AnimalRescue.tscn|rescue_forest_01"
  "memory|res://scenes/minigames/memory_match/MemoryMatch.tscn|piglet_town_05"
  "battle|res://scenes/minigames/monster_battle/MonsterBattle.tscn|monster_arena_01"
  "duel|res://scenes/minigames/monster_duel/MonsterDuel.tscn|monster_arena_04"
  "echo|res://scenes/minigames/light_echo/LightEcho.tscn|hero_city_06"
  "trail|res://scenes/minigames/platformer/Platformer.tscn|adventure_valley_01"
)

wanted=("$@")
failures=0

for entry in "${SHOTS[@]}"; do
  IFS="|" read -r name scene level <<< "$entry"
  if [[ ${#wanted[@]} -gt 0 ]] && [[ ! " ${wanted[*]} " == *" $name "* ]]; then continue; fi

  SHOT_SCENE="$scene" SHOT_PATH="$OUT/$name.png" SHOT_LEVEL="$level" \
    SHOT_WAIT="${SHOT_WAIT:-1.8}" \
    timeout 120 "${RUNNER[@]}" "$GODOT" --path . --rendering-driver opengl3 \
    res://tests/Screenshot.tscn >"$OUT/$name.log" 2>&1

  if grep -q "SCRIPT ERROR\|Parse Error" "$OUT/$name.log"; then
    echo "  ERROR $name"
    grep -m 3 "SCRIPT ERROR\|Parse Error" "$OUT/$name.log" | sed 's/^/         /'
    failures=$((failures + 1))
  elif [[ -f "$OUT/$name.png" ]]; then
    echo "  ok    $name"
  else
    echo "  FAIL  $name  (see $OUT/$name.log)"
    failures=$((failures + 1))
  fi
done

echo
echo "screenshots in $OUT"
[[ $failures -eq 0 ]] || exit 1
