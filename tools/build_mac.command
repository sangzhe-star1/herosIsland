#!/bin/bash
# Double-click me: builds Little Heroes Growth Island.app on this Mac.
#
# One-time setup first (about two minutes, once per Godot version):
#   open the project in Godot -> Editor -> Manage Export Templates -> Download
#
# What this does: finds your Godot, exports the macOS build using the
# "macOS" preset (export_presets.cfg), unzips the .app into build/, strips
# the quarantine flag so Gatekeeper lets an unsigned family build run, and
# opens the folder. Drag the .app to /Applications if you want it there.

set -uo pipefail
cd "$(dirname "$0")/.."

find_godot() {
  for c in \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Downloads/Godot.app/Contents/MacOS/Godot"; do
    [ -x "$c" ] && { echo "$c"; return; }
  done
  command -v godot 2>/dev/null || true
}

GODOT="$(find_godot)"
if [ -z "$GODOT" ]; then
  echo "找不到 Godot。把 Godot.app 放进 /Applications 再试一次。"
  read -r -p "按回车关闭..." _; exit 1
fi

VER="$("$GODOT" --version | cut -d. -f1-2 | tr -d '\n')"
TPL="$HOME/Library/Application Support/Godot/export_templates"
if ! ls "$TPL" 2>/dev/null | grep -q "^${VER}"; then
  echo "还没安装导出模板（只需一次）："
  echo "  打开 Godot -> Editor -> Manage Export Templates -> Download and Install"
  read -r -p "装好后再双击本脚本。按回车关闭..." _; exit 1
fi

mkdir -p build
echo "正在导出……（第一次要一两分钟）"
"$GODOT" --headless --export-release "macOS" "build/LittleHeroesGrowthIsland.zip" || {
  echo "导出失败。打开 Godot 的 Project -> Export 看红字提示。"
  read -r -p "按回车关闭..." _; exit 1
}

cd build
rm -rf "Little Heroes Growth Island.app"
unzip -oq LittleHeroesGrowthIsland.zip
# Family build is unsigned: strip the quarantine flag so it opens normally.
xattr -cr "Little Heroes Growth Island.app" 2>/dev/null || true
echo
echo "完成！build/Little Heroes Growth Island.app"
echo "想放进启动台就把它拖到 /Applications。"
open .
