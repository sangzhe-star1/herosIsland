#!/usr/bin/env python3
"""Record the game's voice lines in a real person's voice, one line at a time.

Reads the lines from docs/VOICE_SCRIPT.md (the same source the synthetic
generator uses), records from the Mac microphone, trims the silence, evens out
the loudness and writes the clip the game already looks for:
assets/audio/voice/level/<id>.wav (mono, 24 kHz, 16-bit PCM). No code changes.

    ./tools/record_voice.command                  # every active line not yet recorded
    ./tools/record_voice.command --section 一      # only section 一 (or titles containing the text)
    ./tools/record_voice.command --only battle_01_intro,harvest_02_intro
    ./tools/record_voice.command --list           # show progress, record nothing
    ./tools/record_voice.command --revert harvest_02_intro

The file a recording replaces (the Tingting placeholder, .wav or .ogg) is moved
to .voice_backup/ first, so --revert can put it back. AudioManager prefers .ogg
over .wav, which is why an old .ogg has to move out of the way.

Lines recorded here are listed in assets/audio/voice/human_recorded.txt, so a
later run resumes where the last one stopped and the synthetic generator's
outputs are never confused with a person's voice.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_missing_voice as voice_script  # noqa: E402  (shared script parsing)

ROOT = voice_script.ROOT
OUTPUT_DIR = voice_script.OUTPUT_DIR
BACKUP_DIR = ROOT / ".voice_backup"  # hidden: Godot does not import it
RECORDED_LIST = ROOT / "assets" / "audio" / "voice" / "human_recorded.txt"

# Trim leading/trailing silence, cut rumble, even out loudness, leave a short
# breath at the end so the line does not feel clipped.
CLEAN_FILTER = ",".join([
    "highpass=f=80",
    "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08",
    "areverse",
    "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08",
    "areverse",
    "loudnorm=I=-18:TP=-2:LRA=11",
    "apad=pad_dur=0.15",
])
MIN_SECONDS = 0.4  # anything shorter after trimming is almost surely silence


def read_sections() -> dict[str, str]:
    """Map each voice id to the '## ' section title it appears under first."""
    sections: dict[str, str] = {}
    title = ""
    for line in voice_script.SCRIPT_PATH.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            title = line[3:].strip()
        elif line.lstrip().startswith("|"):
            for match in voice_script.VOICE_FILE.finditer(line):
                sections.setdefault(match.group(1), title)
    return sections


def read_recorded() -> list[str]:
    if not RECORDED_LIST.is_file():
        return []
    return [l.strip() for l in RECORDED_LIST.read_text(encoding="utf-8").splitlines()
            if l.strip() and not l.startswith("#")]


def write_recorded(names: list[str]) -> None:
    header = ("# Voice lines recorded by a person with tools/record_voice.py.\n"
              "# Everything else in voice/level/ is the synthetic placeholder.\n")
    RECORDED_LIST.write_text(header + "".join(f"{n}\n" for n in sorted(set(names))),
                             encoding="utf-8")


def existing_clips(name: str) -> list[Path]:
    return [OUTPUT_DIR / f"{name}{s}" for s in voice_script.AUDIO_SUFFIXES
            if (OUTPUT_DIR / f"{name}{s}").is_file()]


def ask(prompt: str) -> str:
    try:
        return input(prompt).strip().lower()
    except EOFError:
        return "q"


def play(path: Path) -> None:
    subprocess.run(["afplay", str(path)], check=False)


def record_take(raw: Path, device: str) -> bool:
    """Record from the microphone until Enter. Returns False if ffmpeg failed."""
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
               "-f", "avfoundation", "-i", f":{device}",
               "-ac", "1", "-ar", "48000", "-c:a", "pcm_s16le", str(raw)]
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        input("  ● 正在录音……念完按回车停止 ")
    except EOFError:
        pass
    if process.poll() is None:
        process.communicate(b"q", timeout=10)  # 'q' lets ffmpeg finish the file
    else:
        error = process.stderr.read().decode(errors="ignore") if process.stderr else ""
        print(f"  录音没有启动：{error.strip()}")
        return False
    return raw.is_file() and raw.stat().st_size > 1000


def clean_take(raw: Path, out: Path) -> float:
    """Write the game-format clip and return its length in seconds."""
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                    "-i", str(raw), "-af", CLEAN_FILTER,
                    "-ac", "1", "-ar", "24000", "-c:a", "pcm_s16le", str(out)],
                   check=True)
    try:
        voice_script.verify_wav(out)
    except RuntimeError:
        return 0.0  # nothing left after trimming: the take was silent
    with wave.open(str(out), "rb") as stream:
        return stream.getnframes() / stream.getframerate()


def install(name: str, clip: Path) -> None:
    """Move the old clip(s) to the backup folder, then put the new one in place."""
    BACKUP_DIR.mkdir(exist_ok=True)
    (BACKUP_DIR / ".gdignore").touch()
    # Only the very first original is kept; a later take replaces a person's
    # earlier take, which is not something to restore on --revert.
    already_backed_up = bool(backups(name))
    for old in existing_clips(name):
        stale_import = old.with_name(old.name + ".import")
        if not already_backed_up:
            shutil.move(str(old), BACKUP_DIR / old.name)
            if stale_import.is_file():  # keep it so --revert leaves git clean
                shutil.move(str(stale_import), BACKUP_DIR / stale_import.name)
        else:
            old.unlink()
        if stale_import.is_file():
            stale_import.unlink()  # Godot re-imports the new file on next scan
    shutil.copyfile(clip, OUTPUT_DIR / f"{name}.wav")


def backups(name: str) -> list[Path]:
    if not BACKUP_DIR.is_dir():
        return []
    return [p for p in BACKUP_DIR.glob(f"{name}.*") if p.suffix in voice_script.AUDIO_SUFFIXES]


def revert(name: str) -> int:
    originals = backups(name)
    if not originals:
        print(f"{name}: .voice_backup/ 里没有原文件。也可以用 git checkout 恢复。")
        return 1
    for current in existing_clips(name):
        current.unlink()
        stale_import = current.with_name(current.name + ".import")
        if stale_import.is_file():
            stale_import.unlink()
    for original in originals:
        shutil.move(str(original), OUTPUT_DIR / original.name)
        saved_import = BACKUP_DIR / (original.name + ".import")
        if saved_import.is_file():
            shutil.move(str(saved_import), OUTPUT_DIR / saved_import.name)
        print(f"恢复 {original.name}")
    write_recorded([n for n in read_recorded() if n != name])
    return 0


def record_line(name: str, phrase: str, section: str, index: int, total: int,
                device: str, temp: Path) -> str:
    """Returns 'kept', 'skipped' or 'quit'."""
    print(f"\n[{index}/{total}] {section}  ·  {name}")
    print(f"\n      {phrase}\n")
    old = existing_clips(name)
    while True:
        hint = "回车=开始录  o=听现在的  s=跳过  q=退出" if old else "回车=开始录  s=跳过  q=退出"
        choice = ask(f"  {hint} > ")
        if choice == "q":
            return "quit"
        if choice == "s":
            return "skipped"
        if choice == "o" and old:
            play(old[0])
            continue
        if choice:
            continue
        raw, clip = temp / f"{name}_raw.wav", temp / f"{name}.wav"
        if not record_take(raw, device):
            print("  没录到声音。检查：系统设置 → 隐私与安全性 → 麦克风，允许“终端”。")
            continue
        seconds = clean_take(raw, clip)
        if seconds < MIN_SECONDS:
            print("  好像几乎是静音，再录一次吧。如果一直这样，检查：系统设置 → 隐私与安全性 → "
                  "麦克风，允许“终端”，然后重新打开终端。")
            continue
        print(f"  回放（{seconds:.1f} 秒）……")
        play(clip)
        while True:
            choice = ask("  回车=保留  r=重录  p=再听  s=跳过  q=退出 > ")
            if choice == "p":
                play(clip)
            elif choice in ("", "r", "s", "q"):
                break
        if choice == "":
            install(name, clip)
            print(f"  已保存 assets/audio/voice/level/{name}.wav")
            return "kept"
        if choice == "s":
            return "skipped"
        if choice == "q":
            return "quit"
        # 'r' falls through to another take


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--section", help="only lines under a '## ' title containing this text")
    parser.add_argument("--only", help="comma-separated voice ids")
    parser.add_argument("--all", action="store_true",
                        help="include script lines the game does not use yet")
    parser.add_argument("--redo", action="store_true",
                        help="also offer lines already recorded by a person")
    parser.add_argument("--list", action="store_true", help="show progress and exit")
    parser.add_argument("--revert", metavar="ID", help="put the original clip back")
    parser.add_argument("--device", default="0", help="avfoundation audio device index (default 0)")
    options = parser.parse_args()

    if sys.platform != "darwin":
        parser.error("This recorder uses the Mac microphone (avfoundation) and afplay.")
    if options.revert:
        return revert(options.revert)
    if not shutil.which("ffmpeg"):
        print("需要 ffmpeg：brew install ffmpeg", file=sys.stderr)
        return 2

    entries = voice_script.read_script_entries()  # script order, corrections applied
    sections = read_sections()
    referenced = voice_script.find_referenced_ids(entries)
    recorded = set(read_recorded())

    names = [n for n in entries if options.all or n in referenced]
    if options.only:
        wanted = [n.strip() for n in options.only.split(",") if n.strip()]
        unknown = [n for n in wanted if n not in entries]
        if unknown:
            parser.error("配音稿里没有：" + ", ".join(unknown))
        names = wanted
    if options.section:
        # "一" means the section numbered 一, not every title containing 一
        by_number = [n for n in names if sections.get(n, "").startswith(options.section + "、")]
        names = by_number or [n for n in names if options.section in sections.get(n, "")]

    done = [n for n in names if n in recorded]
    todo = names if options.redo else [n for n in names if n not in recorded]
    print(f"选中 {len(names)} 句，已真人录 {len(done)} 句，这次要录 {len(todo)} 句。")
    if options.list:
        current = ""
        for name in names:
            if sections.get(name, "") != current:
                current = sections.get(name, "")
                print(f"\n## {current}")
            print(f"  {'✓' if name in recorded else '·'} {name}: {entries[name]}")
        return 0
    if not todo:
        return 0

    print("念慢一点、笑着说，像在旁边陪着玩。离麦克风一拳到两拳远。")
    kept = 0
    with tempfile.TemporaryDirectory(prefix="heroes-record-") as temporary:
        for index, name in enumerate(todo, 1):
            result = record_line(name, entries[name], sections.get(name, ""),
                                 index, len(todo), options.device, Path(temporary))
            if result == "kept":
                kept += 1
                recorded.add(name)
                write_recorded(sorted(recorded))  # save progress after every line
            elif result == "quit":
                break
    print(f"\n这次保存了 {kept} 句。下次运行会从没录的那句接着来。")
    if kept:
        print("录完后请在项目里打开一次 Godot（或运行 ./tests/run_smoke.sh），让新文件被导入。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
