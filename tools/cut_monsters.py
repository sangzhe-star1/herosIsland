#!/usr/bin/env python3
"""Turn the #00FF00 monster art into transparent PNGs the game can draw.

    python3 tools/cut_monsters.py <in-folder> <out-folder>

This is a real chroma key, not a "keep the biggest blob" trick. The first
attempt did the blob thing and it looked fine in a contact sheet: every monster
came out cleanly outlined. Zoomed in, the gaps BETWEEN the legs and under the
arms were still solid green -- enclosed background is still background, and
filling holes had turned it into part of the creature. On a green screen it is
invisible; on the game's sky it would have been a green window in the monster's
armpit.

So: any pixel that is green is background, enclosed or not. What "green" means
is chroma, not distance to one colour -- the art has antialiased edges where
green blends into the outline over three or four pixels, and those need to come
out as partial alpha or the creature gets a hard green rim.

Despill matters for the same reason. A half-transparent edge pixel still holds
its green, and once composited over a pale sky it shows as a lime fringe. The
fix is to pull green down to the level of the other two channels wherever it is
the odd one out.
"""

import os
import sys
import glob

import numpy as np
import cv2
from PIL import Image


def key_green(rgb):
    """Alpha from a green screen. 0 = background, 255 = the creature."""
    r, g, b = (rgb[:, :, i].astype(np.float32) for i in range(3))
    # How much more green there is than the brighter of the other two. On the
    # flat background this is huge; on the creature it is at or below zero
    # even for its green parts, which are never pure green.
    excess = g - np.maximum(r, b)
    # Two thresholds so the antialiased rim comes out as partial alpha rather
    # than a hard cut: fully background above HIGH, fully creature below LOW.
    LOW, HIGH = 18.0, 70.0
    alpha = 1.0 - np.clip((excess - LOW) / (HIGH - LOW), 0.0, 1.0)
    return (alpha * 255.0).astype(np.uint8)


def despill(rgb, alpha):
    """Take the green back out of the edge pixels it bled into."""
    out = rgb.astype(np.float32).copy()
    r, g, b = out[:, :, 0], out[:, :, 1], out[:, :, 2]
    cap = np.maximum(r, b)
    over = g > cap
    # Only where the pixel is not fully opaque interior; the creature's own
    # greens (the crystal monster, the light bug's glow) must survive.
    edge = (alpha > 0) & (alpha < 250)
    fix = over & edge
    g[fix] = cap[fix]
    return np.clip(out, 0, 255).astype(np.uint8)


def drop_specks(alpha, min_area=64):
    """Lone survivors of the key -- compression noise, stray pixels."""
    solid = (alpha > 8).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(solid, 8)
    out = alpha.copy()
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] < min_area:
            out[lab == i] = 0
    return out


def cut(path):
    rgb = np.array(Image.open(path).convert("RGB"))
    alpha = key_green(rgb)
    alpha = drop_specks(alpha)
    # Half a pixel in, to eat the last of the rim without gnawing the outline.
    alpha = cv2.erode(alpha, np.ones((2, 2), np.uint8))
    alpha = cv2.GaussianBlur(alpha, (3, 3), 0)
    rgb = despill(rgb, alpha)

    ys, xs = np.where(alpha > 8)
    if len(ys) == 0:
        return None, None
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    out = np.dstack([rgb, alpha])[box[1]:box[3], box[0]:box[2]]
    return Image.fromarray(out, "RGBA"), box


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    files = sorted(glob.glob(os.path.join(src, "*.png")))
    done = 0
    for path in files:
        name = os.path.splitext(os.path.basename(path))[0]
        if name.lower() in ("preview", "readme"):
            continue
        im, box = cut(path)
        if im is None:
            print("  ✗ %-20s 抠不出东西" % name)
            continue
        # How much green is left where it should not be: a straight count of
        # opaque pixels that are still green-dominant.
        a = np.array(im)[:, :, 3]
        px = np.array(im)[:, :, :3].astype(np.int16)
        left = int((((px[:, :, 1] - np.maximum(px[:, :, 0], px[:, :, 2])) > 40)
                    & (a > 200)).sum())
        im.save(os.path.join(dst, name + ".png"))
        done += 1
        print("  ✓ %-20s %dx%d  残留绿点 %d" % (name, im.width, im.height, left))
    print("抠好 %d 张 -> %s" % (done, dst))
    return 0


if __name__ == "__main__":
    sys.exit(main())
