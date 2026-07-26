#!/usr/bin/env bash
# Turn a mini lesson into a watchable MP4.
#
#   ./tools/make_film.sh sunny_park out/park_lesson.mp4
#
# Films the real scene frame by frame (see tests/lesson_film.gd), then lays
# the island's own music underneath and encodes it. The point is a file a
# parent can send to a grandparent, or play on a phone in a waiting room --
# the lesson without the game around it.
set -uo pipefail
cd "$(dirname "$0")/.."

WORLD="${1:-sunny_park}"
OUT="${2:-build/film/${WORLD}_lesson.mp4}"
SECONDS_LONG="${FILM_SECONDS:-17}"
FRAMES_DIR="$(mktemp -d)"

GODOT="${GODOT:-$(command -v godot4 || command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
[[ -x "$GODOT" ]] || { echo "Set GODOT=/path/to/Godot"; exit 1; }

RUNNER=()
if [[ "$(uname)" == "Linux" ]] && [[ -z "${DISPLAY:-}" ]]; then
  RUNNER=(xvfb-run -a -s "-screen 0 1280x720x24")
  export LIBGL_ALWAYS_SOFTWARE=1
fi

echo "Filming $WORLD ..."
FILM_DIR="$FRAMES_DIR" FILM_WORLD="$WORLD" FILM_SECONDS="$SECONDS_LONG" FILM_CLEAN=1 \
  "${RUNNER[@]}" "$GODOT" --path . --rendering-driver opengl3 \
  res://tests/LessonFilm.tscn >/dev/null 2>&1

COUNT=$(ls "$FRAMES_DIR"/frame_*.png 2>/dev/null | wc -l)
if [[ "$COUNT" -lt 30 ]]; then
  echo "Only $COUNT frames came out -- something went wrong."
  exit 1
fi

# Pick the music that belongs to this world, falling back to the main theme.
MUSIC="assets/audio/music/${WORLD}.ogg"
[[ -f "$MUSIC" ]] || MUSIC="assets/audio/music/sunny_park.ogg"

mkdir -p "$(dirname "$OUT")"
ffmpeg -y -loglevel error \
  -framerate 30 -i "$FRAMES_DIR/frame_%05d.png" \
  -stream_loop -1 -i "$MUSIC" \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium \
  -c:a aac -b:a 128k -shortest \
  -af "volume=0.55,afade=t=in:st=0:d=1,afade=t=out:st=$((SECONDS_LONG-2)):d=2" \
  "$OUT"

rm -rf "$FRAMES_DIR"
echo "  $COUNT frames -> $OUT ($(du -h "$OUT" | cut -f1))"
