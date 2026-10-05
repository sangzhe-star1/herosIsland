"""The garden's rabbit friend, built in the same frozen toy studio.

Long peach ears, a teal apron and a carrot basket stay readable at farm size.
All colours and geometry are generated locally; no external textures needed.
"""
import math


def build(S, P):
    uv, tube, block, M = S.uv, S.tube, S.block, S.M
    fur = S.material('Rabbit | warm ivory fur', (.92, .87, .76), .93)
    inner = S.material('Rabbit | peach inner ear', (.89, .47, .43), .88)
    apron = S.material('Rabbit | garden teal linen', (.13, .44, .40), .92)
    seam = S.material('Rabbit | mint apron stitches', (.62, .78, .58), .92)
    basket = S.material('Rabbit | woven honey basket', (.65, .39, .19), .9)
    rim = S.material('Rabbit | basket rim', (.86, .59, .30), .9)

    uv('Rabbit | body', (0, .02, .60), (.39, .31, .50), fur)
    uv('Rabbit | tail', (-.37, .23, .40), (.16, .15, .17), M['paper'], 16, 10)
    for side in (-1, 1):
        uv('Rabbit | foot', (side * .23, -.15, .095), (.18, .26, .095), fur, 20, 12)
        uv('Rabbit | toe pad', (side * .23, -.345, .105), (.10, .065, .043), inner, 12, 8)

    # The broad apron is one simple colour shape, not a tiny badge.
    uv('Rabbit | apron', (0, -.255, .55), (.32, .13, .36), apron, 24, 16)
    for side in (-1, 1):
        tube('Rabbit | apron strap', [(side * .17, -.23, .94),
             (side * .22, -.31, .79), (side * .22, -.34, .56)], .038, apron, 3)
        uv('Rabbit | apron button', (side * .20, -.357, .79),
           (.038, .022, .038), M['bloom_yellow'], 12, 8)
    block('Rabbit | pocket', (0, -.376, .48), (.24, .035, .18), seam, .025)
    tube('Rabbit | pocket seam', [(-.10, -.40, .55), (0, -.403, .535),
         (.10, -.40, .55)], .008, M['paper'], 2)

    uv('Rabbit | head', (0, -.075, 1.24), (.39, .33, .37), fur, 32, 20)
    for side in (-1, 1):
        ear = uv('Rabbit | long ear', (side * .205, -.015, 1.83),
                 (.12, .11, .43), fur, 24, 16)
        ear.rotation_euler.y = side * .18
        lining = uv('Rabbit | ear lining', (side * .21, -.102, 1.84),
                    (.066, .035, .31), inner, 20, 12)
        lining.rotation_euler.y = side * .18
        uv('Rabbit | muzzle', (side * .085, -.371, 1.14),
           (.125, .075, .10), M['paper'], 20, 12)
        uv('Rabbit | eye', (side * .15, -.364, 1.32),
           (.043, .027, .055), M['black'], 16, 10)
        uv('Rabbit | eye glint', (side * .15 - .010, -.39, 1.339),
           (.012, .009, .014), M['paper'], 10, 6)
        uv('Rabbit | rosy cheek', (side * .26, -.328, 1.16),
           (.07, .023, .037), inner, 12, 8)
    uv('Rabbit | nose', (0, -.444, 1.18), (.043, .027, .031), inner, 12, 8)
    tube('Rabbit | smile', [(-.058, -.414, 1.094), (0, -.433, 1.073),
         (.058, -.414, 1.094)], .009, M['wood_dark'], 2)

    # One open hand is raised in greeting; the other holds the picnic basket.
    tube('Rabbit | waving arm', [(-.31, -.005, .84), (-.50, -.02, 1.02),
         (-.59, -.07, 1.23)], .095, fur, 4)
    uv('Rabbit | waving paw', (-.61, -.08, 1.30), (.12, .095, .15), fur, 20, 12)
    uv('Rabbit | waving pad', (-.62, -.16, 1.30), (.060, .024, .081), inner, 16, 10)
    tube('Rabbit | basket arm', [(.31, -.005, .84), (.43, -.10, .69),
         (.49, -.16, .61)], .10, fur, 4)
    uv('Rabbit | basket paw', (.48, -.19, .62), (.115, .10, .11), fur, 16, 10)

    uv('Rabbit | basket body', (.53, -.13, .32), (.24, .23, .19), basket, 24, 16)
    for height, radius in [(.25, .20), (.33, .233), (.42, .22)]:
        points = [(.53 + radius * math.cos(i * math.tau / 24),
                   -.13 + radius * .91 * math.sin(i * math.tau / 24), height)
                  for i in range(25)]
        tube('Rabbit | basket weave', points, .018, rim, 2)
    tube('Rabbit | basket handle', [(.32, -.13, .41), (.37, -.12, .64),
         (.53, -.12, .73), (.69, -.12, .64), (.75, -.13, .41)], .026, rim, 3)
    for x, y, height in [(.45, -.23, .47), (.62, -.12, .49)]:
        carrot = uv('Rabbit | picnic carrot', (x, y, height),
                    (.066, .068, .17), M['carrot'], 16, 10)
        carrot.rotation_euler.y = -.28
        for lean in [-.055, .015, .065]:
            tube('Rabbit | carrot leaf', [(x, y, height + .13),
                 (x + lean, y + .018, height + .25),
                 (x + lean * 1.4, y, height + .28)], .017, M['leaf2'], 2)
