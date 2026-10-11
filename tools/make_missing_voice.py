#!/usr/bin/env python3
"""Generate missing, referenced game voice clips with macOS's offline voice.

The voice script is the text source of truth. This tool reads only table rows
from it, selects clips referenced by active levels or game code, and writes
mono 24 kHz PCM WAV files. Existing audio is skipped so a human recording is
never replaced by synthesis.

    ./tools/make_voice.command --dry-run
    ./tools/make_voice.command

The five unwired Hero House lines stay out of the default batch. The two
outdated clips documented in VOICE_SCRIPT.md are present but need the specified
XiaoxiaoNeural voice, which is a separate optional replacement workflow.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import wave


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "docs" / "VOICE_SCRIPT.md"
LEVELS_PATH = ROOT / "data" / "levels.json"
OUTPUT_DIR = ROOT / "assets" / "audio" / "voice" / "level"
AUDIO_SUFFIXES = (".ogg", ".wav", ".mp3")
VOICE_FILE = re.compile(r"`([^`/]+)\.(?:wav|ogg|mp3)`")
SCRIPT_CORRECTIONS = {"monster_valley_02_intro", "dark_castle_05_intro"}


def read_script_entries() -> dict[str, str]:
    """Return id -> spoken phrase for the audio-file rows in the voice tables."""
    entries: dict[str, str] = {}
    for line_number, line in enumerate(SCRIPT_PATH.read_text(encoding="utf-8").splitlines(), 1):
        if not line.lstrip().startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        names = [match.group(1) for cell in cells for match in VOICE_FILE.finditer(cell)]
        if not names:
            continue
        phrase = re.sub(r"`|\*\*", "", cells[-1]).strip()
        if not phrase or phrase.startswith(":---"):
            continue
        for name in names:
            old = entries.get(name)
            if old is not None and old != phrase and name not in SCRIPT_CORRECTIONS:
                raise ValueError(
                    f"Conflicting script text for {name!r} near line {line_number}."
                )
            entries[name] = phrase
    return entries


def find_referenced_ids(entries: dict[str, str]) -> set[str]:
    """Include all current level intros and voice ids named by game code/data."""
    import json

    levels = json.loads(LEVELS_PATH.read_text(encoding="utf-8"))
    referenced = {f"{level['id']}_intro" for level in levels if level.get("id")}
    source_text = "\n".join(
        path.read_text(encoding="utf-8", errors="ignore")
        for root in (ROOT / "scripts", ROOT / "data")
        for path in root.rglob("*")
        if path.suffix in {".gd", ".json"}
    )
    for name in entries:
        if re.search(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])", source_text):
            referenced.add(name)
    return referenced


def audio_exists(name: str) -> bool:
    return any((OUTPUT_DIR / f"{name}{suffix}").is_file() for suffix in AUDIO_SUFFIXES)


def verify_wav(path: Path) -> None:
    with wave.open(str(path), "rb") as stream:
        if stream.getnchannels() != 1 or stream.getframerate() != 24000 \
                or stream.getsampwidth() != 2 or stream.getnframes() == 0:
            raise RuntimeError(f"Unexpected WAV format for {path.name}.")


def make_line(name: str, phrase: str, voice: str, rate: int) -> Path:
    with tempfile.TemporaryDirectory(prefix="heroes-voice-") as temporary:
        temp = Path(temporary)
        aiff_path = temp / f"{name}.aiff"
        wav_path = temp / f"{name}.wav"
        subprocess.run(
            ["say", "-v", voice, "-r", str(rate), "-o", str(aiff_path), phrase],
            check=True,
        )
        subprocess.run(
            ["afconvert", "-f", "WAVE", "-d", "LEI16@24000", "-c", "1",
             str(aiff_path), str(wav_path)],
            check=True,
        )
        verify_wav(wav_path)
        output_path = OUTPUT_DIR / f"{name}.wav"
        os.replace(wav_path, output_path)
    return output_path


def voice_is_installed(voice: str) -> bool:
    result = subprocess.run(["say", "-v", "?"], check=True, capture_output=True, text=True)
    return any(line.startswith(f"{voice} ") for line in result.stdout.splitlines())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--voice", default="Tingting", help="Installed macOS voice name (default: Tingting)")
    parser.add_argument("--rate", type=int, default=165, help="macOS speech rate (default: 165)")
    parser.add_argument("--dry-run", action="store_true", help="List work without generating files")
    options = parser.parse_args()

    if sys.platform != "darwin":
        parser.error("Voice generation uses the local macOS say and afconvert tools.")
    if not SCRIPT_PATH.is_file() or not LEVELS_PATH.is_file():
        parser.error("Run this from a complete project checkout containing the voice script and levels.")
    if options.rate <= 0:
        parser.error("--rate must be a positive integer.")

    try:
        entries = read_script_entries()
    except (OSError, ValueError) as error:
        parser.error(str(error))

    referenced = find_referenced_ids(entries)
    undocumented = sorted(referenced - entries.keys())
    targets = sorted(name for name in referenced & entries.keys() if not audio_exists(name))
    unreferenced_missing = sorted(
        name for name in entries.keys() - referenced if not audio_exists(name)
    )
    print(f"Voice script: {len(entries)} ids; active references: {len(referenced)}")
    print(f"Missing active clips to generate: {len(targets)}")
    print(f"Unwired script entries left alone: {len(unreferenced_missing)}")
    if undocumented:
        print("Active voice ids without script text: " + ", ".join(undocumented))
        return 1
    for name in targets:
        print(f"  {name}: {entries[name]}")
    if options.dry_run or not targets:
        return 0
    if not shutil.which("say") or not shutil.which("afconvert"):
        print("Required local macOS tools 'say' and 'afconvert' were not found.", file=sys.stderr)
        return 2
    if not voice_is_installed(options.voice):
        print(f"The macOS voice {options.voice!r} is not installed.", file=sys.stderr)
        return 2

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    created = 0
    for name in targets:
        if audio_exists(name):
            print(f"Skipped (appeared during run): {name}")
            continue
        path = make_line(name, entries[name], options.voice, options.rate)
        created += 1
        print(f"Created {path.relative_to(ROOT)}")
    print(f"Generated {created} missing referenced clips; existing audio was not overwritten.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
