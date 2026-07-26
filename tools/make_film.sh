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

# Filming is the slow part (minutes, on a software renderer) and the audio mix
# is the part you actually iterate on. KEEP_FRAMES=1 leaves the stills behind,
# REUSE_FRAMES=<dir> encodes from them again -- so changing the mix costs
# seconds instead of another full capture.
if [[ -n "${REUSE_FRAMES:-}" ]]; then
  rmdir "$FRAMES_DIR" 2>/dev/null
  FRAMES_DIR="$REUSE_FRAMES"
  echo "Reusing frames in $FRAMES_DIR"
else
  echo "Filming $WORLD ..."
  FILM_DIR="$FRAMES_DIR" FILM_WORLD="$WORLD" FILM_SECONDS="$SECONDS_LONG" FILM_CLEAN=1 \
    "${RUNNER[@]}" "$GODOT" --path . --rendering-driver opengl3 \
    res://tests/LessonFilm.tscn >/dev/null 2>&1
fi

COUNT=$(ls "$FRAMES_DIR"/frame_*.png 2>/dev/null | wc -l)
if [[ "$COUNT" -lt 30 ]]; then
  echo "Only $COUNT frames came out -- something went wrong."
  exit 1
fi

# Pick the music that belongs to this world, falling back to the main theme.
MUSIC="assets/audio/music/${WORLD}.ogg"
[[ -f "$MUSIC" ]] || MUSIC="assets/audio/music/sunny_park.ogg"

# The narration, if it has been recorded.
#
# The film captures pictures, not the engine's audio, so the spoken lines have
# to be laid back on by hand -- but the lesson's timing is a constant (BEAT in
# mini_lesson.gd), so where each line goes is arithmetic, not guesswork. Beat 1
# at 0s, beat 2 at 4.6s, beat 3 at 9.2s, "记住了吗" at 13.8s.
#
# Nothing recorded yet means nothing mixed in and a music-only film, which is
# what this produced before and still produces. Record the files and re-run it
# and the same command gives you a narrated one.
VOICE_DIR="assets/audio/voice/level"
BEAT=4.6
case "$WORLD" in
  sunny_park)     KEYS=(lesson_park_1 lesson_park_2 lesson_park_3) ;;
  night_city)     KEYS=(lesson_city_1 lesson_city_2 lesson_city_3) ;;
  monster_valley) KEYS=(lesson_valley_1 lesson_valley_2 lesson_valley_3) ;;
  sky_base)       KEYS=(lesson_sky_1 lesson_sky_2 lesson_sky_3) ;;
  dark_castle)    KEYS=(lesson_castle_1 lesson_castle_2 lesson_castle_3) ;;
  *)              KEYS=() ;;
esac
KEYS+=(lesson_remember)

VOICE_IN=()
VOICE_FILTER=""
VOICE_LABELS=""
VOICE_N=0
for i in "${!KEYS[@]}"; do
  SRC=""
  for ext in ogg wav mp3; do
    [[ -f "$VOICE_DIR/${KEYS[$i]}.$ext" ]] && { SRC="$VOICE_DIR/${KEYS[$i]}.$ext"; break; }
  done
  [[ -n "$SRC" ]] || continue
  # 0.35s after the picture lands, so the drawing is on screen before the
  # voice starts -- a child looks first and listens second.
  MS=$(awk -v b="$BEAT" -v i="$i" 'BEGIN{printf "%d", (b*i + 0.35) * 1000}')
  VOICE_IN+=(-i "$SRC")
  VOICE_FILTER+="[$((VOICE_N + 2)):a]adelay=${MS}|${MS},volume=1.4[v${VOICE_N}];"
  VOICE_LABELS+="[v${VOICE_N}]"
  VOICE_N=$((VOICE_N + 1))
done

FADE_OUT=$((SECONDS_LONG - 2))
if [[ "$VOICE_N" -gt 0 ]]; then
  echo "  mixing in $VOICE_N spoken line(s)"
  # Music ducked under the voice, because the point of the film is the words.
  AUDIO_FILTER="[1:a]volume=0.28,afade=t=in:st=0:d=1,afade=t=out:st=${FADE_OUT}:d=2[bed];"
  AUDIO_FILTER+="$VOICE_FILTER"
  AUDIO_FILTER+="[bed]${VOICE_LABELS}amix=inputs=$((VOICE_N + 1)):duration=first:normalize=0[a]"
  MAP_AUDIO=(-filter_complex "$AUDIO_FILTER" -map 0:v -map "[a]")
else
  AUDIO_FILTER="[1:a]volume=0.55,afade=t=in:st=0:d=1,afade=t=out:st=${FADE_OUT}:d=2[a]"
  MAP_AUDIO=(-filter_complex "$AUDIO_FILTER" -map 0:v -map "[a]")
fi

mkdir -p "$(dirname "$OUT")"
ffmpeg -y -loglevel error \
  -framerate 30 -i "$FRAMES_DIR/frame_%05d.png" \
  -stream_loop -1 -i "$MUSIC" \
  "${VOICE_IN[@]}" \
  "${MAP_AUDIO[@]}" \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium \
  -c:a aac -b:a 128k -shortest \
  "$OUT"

if [[ -n "${KEEP_FRAMES:-}" || -n "${REUSE_FRAMES:-}" ]]; then
  echo "  frames kept in $FRAMES_DIR"
else
  rm -rf "$FRAMES_DIR"
fi
echo "  $COUNT frames -> $OUT ($(du -h "$OUT" | cut -f1))"
