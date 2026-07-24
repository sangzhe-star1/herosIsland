#!/bin/bash
# Generates every voice line for Little Heroes Growth Island using the
# Chinese voice built into this Mac -- no recording, no internet, no installs.
#
# Double-click this file (or run it in Terminal). It writes .wav files into
# assets/audio/voice/level/ and the game picks them up automatically.
# Re-record any line with your own voice later by replacing its file --
# your voice will always beat a synthetic one.

set -euo pipefail
cd "$(dirname "$0")/.."
OUT="assets/audio/voice/level"
mkdir -p "$OUT"

# Prefer Tingting (zh-CN); fall back to whatever Chinese voice exists.
VOICE=""
for candidate in Tingting Meijia Sinji; do
  if say -v '?' | grep -q "^$candidate "; then VOICE="$candidate"; break; fi
done
if [[ -z "$VOICE" ]]; then
  echo "No Chinese voice found. Open System Settings -> Accessibility ->"
  echo "Spoken Content -> System Voice -> Manage Voices, add Tingting, rerun."
  exit 1
fi
echo "Using macOS voice: $VOICE"

make_line() {  # filename  "text"
  local name="$1" text="$2"
  say -v "$VOICE" -r 165 -o "/tmp/$name.aiff" "$text"
  afconvert -f WAVE -d LEI16@44100 "/tmp/$name.aiff" "$OUT/$name.wav"
  rm -f "/tmp/$name.aiff"
  echo "  $OUT/$name.wav  <- $text"
}

make_line well_done               "太棒了！"
make_line try_again               "没关系，再试一次！"
make_line car_coming              "小心，有车来了！"
make_line wrong_light             "红灯要等一等哦。"
make_line safety_traffic_01_intro "绿灯亮了才能过马路。准备好了吗？"
make_line hero_city_intro         "和奥特曼一起收集光之能量吧！"
make_line monster_arena_intro     "怪兽来啦！用光线打败它吧！"
make_line memory_intro            "翻开卡片，找到一样的两张吧！"

echo
echo "Done: 8 voice lines. Open the game -- it speaks now."
echo "(Godot may need a moment to import the new files on first launch.)"
