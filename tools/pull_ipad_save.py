#!/usr/bin/env python3
"""Copy the game's save off an iPad (or the iPad simulator) without touching it.

Godot keeps `user://` in the app's Documents folder on iOS, so the files are
Documents/save_game.json and Documents/save_game.bak inside the data container
of com.family.heroesisland. This tool only reads them: it copies both into a
fresh dated folder outside the repository, prints their SHA-256, and can hand
the main file straight to the isolated migration audit.

    ./tools/pull_ipad_save.command                 # the one physical iPad that is connected
    ./tools/pull_ipad_save.command --audit         # ...then run tests/audit_garden_save.py
    ./tools/pull_ipad_save.command --simulator     # the booted iPad simulator (for rehearsal)
    ./tools/pull_ipad_save.command --list          # show devices and exit

A physical iPad must be connected by cable (or paired on the network), unlocked,
and trust this Mac. devicectl can only read the container of a build installed
from Xcode/Godot with a development signature; an App Store or TestFlight build
refuses, and then the save has to come from a Finder/iTunes backup instead.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_ID = "com.family.heroesisland"
SAVE_FILES = ("save_game.json", "save_game.bak")
DEFAULT_OUT = Path.home() / "HeroesIsland-saves"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def list_devices() -> list[dict]:
    """Every device devicectl knows, physical and simulated, as plain dicts."""
    with tempfile.TemporaryDirectory() as temp:
        out = Path(temp) / "devices.json"
        result = subprocess.run(
            ["xcrun", "devicectl", "list", "devices", "--json-output", str(out)],
            capture_output=True, text=True, check=False)
        if result.returncode != 0 or not out.is_file():
            raise SystemExit("xcrun devicectl 不可用：需要安装 Xcode。\n" + result.stderr.strip())
        devices = json.loads(out.read_text())["result"]["devices"]
    found = []
    for device in devices:
        hardware = device.get("hardwareProperties", {})
        found.append({
            "id": device.get("identifier", ""),
            "udid": hardware.get("udid", device.get("identifier", "")),
            "name": device.get("deviceProperties", {}).get("name", "?"),
            "model": hardware.get("marketingName", hardware.get("productType", "")),
            "simulated": hardware.get("reality") == "simulated",
            "state": device.get("connectionProperties", {}).get("tunnelState", ""),
        })
    return found


def pull_physical(device: dict, destination: Path) -> list[Path]:
    copied = []
    for name in SAVE_FILES:
        target = destination / name
        result = subprocess.run(
            ["xcrun", "devicectl", "device", "copy", "from",
             "--device", device["id"], "--domain-type", "appDataContainer",
             "--domain-identifier", BUNDLE_ID,
             "--source", f"Documents/{name}", "--destination", str(target)],
            capture_output=True, text=True, check=False)
        if result.returncode == 0 and target.is_file():
            copied.append(target)
        elif name == "save_game.json":
            raise SystemExit(
                "没能从 iPad 读到 save_game.json。\n"
                "检查：iPad 已解锁并信任这台 Mac；装的是从 Xcode/Godot 安装的开发版"
                "（App Store/TestFlight 版不允许读取）；游戏至少打开过一次。\n"
                + (result.stderr or result.stdout).strip())
    return copied


def pull_simulator(destination: Path, udid: str) -> list[Path]:
    result = subprocess.run(
        ["xcrun", "simctl", "get_app_container", udid, BUNDLE_ID, "data"],
        capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise SystemExit(f"模拟器 {udid} 上没有安装 {BUNDLE_ID}。\n{result.stderr.strip()}")
    documents = Path(result.stdout.strip()) / "Documents"
    copied = []
    for name in SAVE_FILES:
        source = documents / name
        if source.is_file():
            target = destination / name
            shutil.copy2(source, target)  # read-only on the source side
            copied.append(target)
    if not any(p.name == "save_game.json" for p in copied):
        raise SystemExit(f"模拟器里还没有存档：{documents}/save_game.json")
    return copied


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--simulator", action="store_true", help="read the booted iPad simulator instead")
    parser.add_argument("--device", help="devicectl identifier or name, when more than one iPad is connected")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT,
                        help=f"parent folder for the dated copy (default {DEFAULT_OUT})")
    parser.add_argument("--audit", action="store_true", help="run tests/audit_garden_save.py on the copy")
    parser.add_argument("--list", action="store_true", help="list devices and exit")
    options = parser.parse_args()
    sys.stdout.reconfigure(line_buffering=True)  # keep our lines ahead of the audit's

    if sys.platform != "darwin":
        parser.error("Needs macOS with Xcode command-line tools (xcrun devicectl / simctl).")
    out_parent = options.out.expanduser().resolve()
    if out_parent == ROOT or ROOT in out_parent.parents:
        parser.error("Keep the child's save outside the repository; choose another --out.")

    devices = list_devices()
    if options.list:
        for d in devices:
            kind = "模拟器" if d["simulated"] else "实体机"
            print(f"{kind}  {d['name']}  {d['model']}  {d['state']}  {d['id']}")
        return 0

    if options.simulator:
        booted = [d for d in devices if d["simulated"] and "iPad" in d["model"] + d["name"]
                  and d["state"] == "connected"]
        if not booted:
            print("没有正在运行的 iPad 模拟器。", file=sys.stderr)
            return 1
        source = booted[0]
    else:
        physical = [d for d in devices if not d["simulated"]]
        if options.device:
            physical = [d for d in physical if options.device in (d["id"], d["udid"], d["name"])]
        if not physical:
            print("没有连接实体 iPad。用数据线连上、解锁并点“信任”，再运行一次；"
                  "--list 可查看设备。", file=sys.stderr)
            return 1
        if len(physical) > 1:
            print("连接了多台设备，请用 --device 指定：", file=sys.stderr)
            for d in physical:
                print(f"  {d['name']}  {d['id']}", file=sys.stderr)
            return 1
        source = physical[0]

    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    kind = "simulator" if source["simulated"] else "ipad"
    destination = out_parent / f"{stamp}-{kind}"
    destination.mkdir(parents=True, exist_ok=False)
    copied = (pull_simulator(destination, source["udid"]) if source["simulated"]
              else pull_physical(source, destination))

    print(f"来源：{source['name']} ({source['id']})")
    for path in copied:
        print(f"  {path}  sha256={sha256(path)}")
    (destination / "SOURCE.txt").write_text(
        f"device={source['name']}\nid={source['id']}\nsimulated={source['simulated']}\n"
        f"bundle={BUNDLE_ID}\npulled={stamp}\n"
        + "".join(f"sha256 {p.name} {sha256(p)}\n" for p in copied), encoding="utf-8")

    if options.audit:
        main_save = destination / "save_game.json"
        report_dir = destination / "audit"
        return subprocess.run(
            [sys.executable, str(ROOT / "tests" / "audit_garden_save.py"),
             "--save", str(main_save), "--output-dir", str(report_dir)],
            check=False).returncode
    print(f"\n下一步：python3 tests/audit_garden_save.py --save {destination / 'save_game.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
