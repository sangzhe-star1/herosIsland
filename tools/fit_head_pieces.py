#!/usr/bin/env python3
"""Raise every hat until it stops covering the hero's eyes.

    python3 tools/fit_head_pieces.py [--write]

The brief has a hard rule -- a costume may not hide the eyes, the chest light,
or the head silhouette -- and eyeballing seventeen hats one screenshot at a
time is how three of them stayed wrong. The dino hood came down over the face
like a bucket; the space helmet blanked it out entirely.

So this measures instead. The hero's eyes sit at a known place in the head's
local coordinates (hero_art.gd draws them at head_centre + (±rx*0.42,
ry*0.14)), and a head piece is a sprite at a known scale and offset. Project
the eyes into the picture, read the alpha there, and you have a yes/no answer
per hat. Then walk the piece up until the answer is no.

It only ever raises. A hat that already clears the eyes is left exactly where
the artist's numbers put it.
"""

import json
import sys

from PIL import Image

SLOTS = "data/character_slots.json"

# hero_art.gd, _build_head: rx = _u(50), ry = _u(54), head centre at
# (0, -ry*0.96) in _head-local space, eye centres at
# centre + (±rx*0.42, ry*0.14). Nominal build_width 76 -> _u(v) == v.
RX, RY = 50.0, 54.0
HEAD_CENTRE_Y = -RY * 0.96
EYE = [(-RX * 0.42, HEAD_CENTRE_Y + RY * 0.14),
       (RX * 0.42, HEAD_CENTRE_Y + RY * 0.14)]
# A little above the pupil too, so a brim resting ON the eyelid still counts.
EYE_MARGIN = RY * 0.20
# How far a piece may be pushed up before we admit it is the wrong size rather
# than the wrong height. A hat 100 units above the head is not a hat.
CEILING = -170.0
STEP = 2.0


def covers_eyes(path, width, at):
    """Does this piece have opaque pixels over either eye?"""
    im = Image.open(path).convert("RGBA")
    tw, th = im.size
    alpha = im.getchannel("A")
    scale = width / tw
    for ex, ey in EYE:
        for dy in (-EYE_MARGIN, 0.0, EYE_MARGIN):
            px = int(round((ex - at[0]) / scale + tw / 2.0))
            py = int(round((ey + dy - at[1]) / scale + th / 2.0))
            if 0 <= px < tw and 0 <= py < th and alpha.getpixel((px, py)) > 128:
                return True
    return False


def main():
    write = "--write" in sys.argv
    table = json.load(open(SLOTS))
    items = json.load(open("data/shop_items.json"))
    default = table["slots"]["head"]
    over = table.setdefault("items", {})

    moved, ok = [], 0
    for entry in sorted(items, key=lambda e: e["id"]):
        if entry.get("slot") != "head" or not entry.get("art"):
            continue
        item_id = entry["id"]
        path = entry["art"].replace("res://", "")
        place = dict(default)
        place.update(over.get(item_id, {}))
        width = float(place["width"])
        at = [float(place["at"][0]), float(place["at"][1])]

        start = at[1]
        while covers_eyes(path, width, at) and at[1] > CEILING:
            at[1] -= STEP
        if covers_eyes(path, width, at):
            print("  ! %-18s 抬到 %.0f 还是挡着眼睛 -- 这件是尺寸不对，不是高度不对"
                  % (item_id, at[1]))
            continue
        if abs(at[1] - start) < 0.5:
            ok += 1
            continue
        moved.append((item_id, start, at[1]))
        over.setdefault(item_id, {})
        over[item_id]["width"] = width
        over[item_id]["at"] = [at[0], at[1]]

    for item_id, was, now in moved:
        print("  ↑ %-18s y %.0f -> %.0f（抬高 %.0f）" % (item_id, was, now, was - now))
    print("%d 顶本来就没挡眼睛，%d 顶抬了" % (ok, len(moved)))

    if write and moved:
        json.dump(table, open(SLOTS, "w"), ensure_ascii=False, indent=2)
        print("写回 %s" % SLOTS)
    elif moved:
        print("（没写。加 --write 才会改文件）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
