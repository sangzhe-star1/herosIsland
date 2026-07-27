#!/usr/bin/env python3
"""Key a FLAT synthetic plate, not a photographed green screen.

    python3 tools/key_plate.py <in-folder> <out-folder>

This exists because tools/cut_monsters.py destroys vegetables.

cut_monsters.py decides "this pixel is background" by asking whether green
exceeds both red and blue. That is the right question for the monster art,
which was drawn over a green screen and has no pure green in it. It is the
wrong question for a broccoli. Run the 64-image harvest pack through it and
eighteen of them come out gutted -- cabbage, spinach, lettuce, cucumber, peas,
celery, watermelon, basil, mint and broccoli keep between 16% and 28% of what
was drawn. The broccoli is a black outline with nothing inside it.

The harvest art is not a photograph. It is drawn over an EXACT #00FF00 plate,
and the plants' own greens are nowhere near it. Measured on the broccoli:

    distance to #00FF00    0-4  : 846579 px    the plate
                          4-120 :   1919 px    the antialiased rim
                        120-inf : 200078 px    the drawing

Nothing at all lives between 120 and 240. So distance to the plate colour
separates them completely, where "is green dominant" cannot.

Both tools stay. Two kinds of background, two ways to cut them, and each one
used on the art it was written for.
"""

import sys, os, glob
import numpy as np
from PIL import Image

PLATE = np.array([0, 255, 0], dtype=np.int16)
SOLID = 120.0   # beyond this distance it is definitely the drawing
CLEAR = 12.0    # within this it is definitely the plate

def key(path):
    rgb = np.array(Image.open(path).convert("RGB")).astype(np.int16)
    d = np.abs(rgb - PLATE).sum(2).astype(np.float32)
    alpha = np.clip((d - CLEAR) / (SOLID - CLEAR), 0.0, 1.0)
    out = rgb.astype(np.float32)
    # despill only where the edge is partly transparent
    edge = (alpha > 0.0) & (alpha < 1.0)
    cap = np.maximum(out[:, :, 0], out[:, :, 2])
    g = out[:, :, 1]
    out[:, :, 1] = np.where(edge & (g > cap), cap, g)
    a = (alpha * 255).astype(np.uint8)
    im = Image.fromarray(np.dstack([out.astype(np.uint8), a]), "RGBA")
    return im.crop(im.getchannel("A").getbbox())

if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    for p in sorted(glob.glob(os.path.join(src, "*.png"))):
        key(p).save(os.path.join(dst, os.path.basename(p)))
    print("done", len(glob.glob(os.path.join(dst, "*.png"))))
