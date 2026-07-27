#!/usr/bin/env python3
"""Accept (or reject) a folder of monster art, one file at a time.

    python3 tools/check_monster_art.py <folder>

Why this exists: the first art pack was fifteen good drawings that none of the
game could use. Every image had a frame, a name plate and a soft gradient
background baked in, so there was no way to get a creature out of one -- ten of
the fifteen failed automatic cut-out entirely. Nobody found that out until the
files were already made.

So this answers, per file, the only question that matters -- can I get a clean
transparent creature out of this? -- and says exactly what is wrong when the
answer is no. It is meant to run on the pack BEFORE anyone redraws anything.

It also writes the cut-outs it managed to make, so the result is inspectable
rather than a verdict you have to take on trust.
"""

import os
import sys
import glob

import numpy as np
import cv2
from PIL import Image

WANT = [
    "rock_horn", "steel_spine", "light_bug", "twin_horn", "flame_tail",
    "crystal_armor", "stone_cub", "blaze_claw", "sand_fist",
    "blue_wing_armor", "drill_armor", "red_wing", "moon_lizard",
    "thunder_wyvern", "shadow_wing",
]

# How flat a background has to be before a cut-out is reliable. The first pack
# measured about 38 on this scale and could not be keyed.
FLAT_LIMIT = 12.0
# How much of the frame the creature should fill, top to bottom.
FILL_MIN, FILL_MAX = 0.62, 0.94
# The feet belong on the floor of the image, not floating in the middle.
FEET_MIN = 0.86


def background_colour(rgb):
    """Sampled from the four corners, which is where the creature is not."""
    h, w, _ = rgb.shape
    k = max(8, min(h, w) // 20)
    corners = np.concatenate([
        rgb[:k, :k].reshape(-1, 3), rgb[:k, -k:].reshape(-1, 3),
        rgb[-k:, :k].reshape(-1, 3), rgb[-k:, -k:].reshape(-1, 3)])
    return np.median(corners, axis=0), float(corners.std(axis=0).mean())


def cut(rgb, bg, threshold=42.0):
    dist = np.sqrt(((rgb.astype(np.int16) - bg) ** 2).sum(axis=2))
    mask = (dist > threshold).astype(np.uint8) * 255
    n, lab, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    if n > 1:
        big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        mask = np.where(lab == big, 255, 0).astype(np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    return mask


def check(path, out_dir):
    """Returns (name, list of complaints, stats dict)."""
    name = os.path.splitext(os.path.basename(path))[0]
    bad = []
    im = Image.open(path)
    rgb = np.array(im.convert("RGB"))
    h, w, _ = rgb.shape

    if im.mode in ("RGBA", "LA"):
        alpha = np.array(im.convert("RGBA"))[:, :, 3]
        if alpha.min() < 250:
            # Already transparent -- nothing to key, use it as it is.
            mask = (alpha > 8).astype(np.uint8) * 255
            flat = 0.0
        else:
            bg, flat = background_colour(rgb)
            mask = cut(rgb, bg)
    else:
        bg, flat = background_colour(rgb)
        mask = cut(rgb, bg)

    if w != h:
        bad.append("不是正方形（%dx%d）" % (w, h))
    if min(w, h) < 512:
        bad.append("太小了（%dx%d，要 1024x1024）" % (w, h))
    if flat > FLAT_LIMIT:
        bad.append("背景不平（起伏 %.0f，要 <%.0f）：有渐变、光晕或者阴影，抠不干净"
                   % (flat, FLAT_LIMIT))

    ys, xs = np.where(mask > 8)
    if len(ys) == 0:
        bad.append("整张图抠不出任何东西")
        return name, bad, {}

    top, bottom = ys.min(), ys.max()
    fill = (bottom - top + 1) / h
    feet = (bottom + 1) / h
    # Anything still touching the edge means the creature is cropped, or the
    # background did not key and we are looking at the whole rectangle.
    edge = (mask[0, :] > 8).any() or (mask[-1, :] > 8).any() \
        or (mask[:, 0] > 8).any() or (mask[:, -1] > 8).any()

    if fill < FILL_MIN:
        bad.append("怪兽太小，只占画面高度的 %.0f%%（要 %.0f-%.0f%%）"
                   % (fill * 100, FILL_MIN * 100, FILL_MAX * 100))
    elif fill > FILL_MAX and edge:
        bad.append("怪兽顶到边了，四周要留约 8% 的空白")
    if feet < FEET_MIN:
        bad.append("脚没落在画面下缘（在 %.0f%% 的位置，要 >%.0f%%）"
                   % (feet * 100, FEET_MIN * 100))

    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
        soft = cv2.GaussianBlur(mask, (5, 5), 0)
        cutout = np.dstack([rgb, soft])[top:bottom + 1, xs.min():xs.max() + 1]
        Image.fromarray(cutout, "RGBA").save(os.path.join(out_dir, name + ".png"))

    return name, bad, {"fill": fill, "feet": feet, "flat": flat}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if not args:
        print(__doc__)
        return 2
    folder = args[0]
    out_dir = args[1] if len(args) > 1 else None
    # --outfit: clothes, not creatures. Two rules come off.
    #
    # A hat and a cape are not the same size and never will be, so the
    # "fifteen drawings at one scale" rule is wrong here -- each garment gets
    # its own mount offset anyway. And there is no fixed roster to be missing
    # from: the pack decides how many hats it has.
    #
    # Everything that actually matters stays on: flat background, square,
    # big enough, and something that can be keyed out cleanly.
    outfit = "--outfit" in flags
    files = sorted(glob.glob(os.path.join(folder, "**", "*.png"), recursive=True))
    if not files:
        print("没有找到 PNG：%s" % folder)
        return 2

    print("=== %s验收 ===" % ("换装素材" if outfit else "怪兽素材"))
    seen, failed = set(), 0
    fills = []
    for path in files:
        name, bad, stats = check(path, out_dir)
        seen.add(name)
        if outfit:
            # A garment lying on the floor of the frame is fine; a hat that
            # floats is fine too. Drop the feet-on-the-ground complaint.
            bad = [b for b in bad if "脚没落在画面下缘" not in b
                   and "怪兽太小" not in b]
        if bad:
            failed += 1
            print("  ✗ %-20s %s" % (name, "；".join(bad)))
        else:
            fills.append(stats["fill"])
            print("  ✓ %-20s 占高 %.0f%%，脚在 %.0f%%，背景平整"
                  % (name, stats["fill"] * 100, stats["feet"] * 100))

    missing = [] if outfit else [s for s in WANT if s not in seen]
    extra = sorted(seen - set(WANT))
    if missing:
        print("  ✗ 少了 %d 只：%s" % (len(missing), "、".join(missing)))
    if extra and not outfit:
        print("  · 多出来的（我会忽略）：%s" % "、".join(extra))

    # Fifteen drawings have to be fifteen drawings at the SAME scale, or the
    # small one and the boss come out the same size in the game.
    if not outfit and len(fills) >= 2 and (max(fills) - min(fills)) > 0.22:
        print("  ✗ 15 只的比例差太多（最小 %.0f%%，最大 %.0f%%）：同一批要统一"
              % (min(fills) * 100, max(fills) * 100))
        failed += 1

    ok = failed == 0 and not missing
    if out_dir and any(True for _ in glob.glob(os.path.join(out_dir, "*.png"))):
        print("  抠图结果写到了 %s，可以直接看" % out_dir)
    print("结果：%s（%d 张，%d 张不合格）"
          % ("通过" if ok else "不通过", len(files), failed))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
