"""A timber barn with a tiled roof and a genuinely recessed entrance.

The original footprint, roof height and recipe framing are retained. Large
structural pieces carry the detail so it survives the small garden sprite.
"""
import math


def build(S, P):
    M, block, uv, mesh = S.M, S.block, S.uv, S.mesh
    timber = S.material('Barn | warm structural timber', (.40, .235, .115), .88)
    door_wood = S.material('Barn | honey door boards', (.64, .395, .18), .89)
    tile_light = S.material('Barn | warm clay tile', (.59, .285, .16), .86)
    tile_dark = S.material('Barn | shaded clay tile', (.49, .215, .115), .88)
    glass = S.material('Barn | muted blue window', (.22, .34, .34), .8)

    # Assemble the front around its opening, with the doors behind its face.
    block('Barn | rear walls', (0, .10, .68), (2.30, 1.18, 1.36), M['wall_tan'], .045)
    for side in (-1, 1):
        block('Barn | front wall bay', (side * .82, -.605, .67),
              (.66, .19, 1.34), M['wall_tan'], .025)
    block('Barn | wall over entrance', (0, -.605, 1.18),
          (.98, .19, .36), M['wall_tan'], .025)
    block('Barn | entrance shadow', (0, -.535, .49),
          (.98, .08, .96), M['door_dark'], .025)
    block('Barn | stone threshold', (0, -.67, .045),
          (1.00, .27, .09), M['stone2'], .025)

    for side in (-1, 1):
        x = side * .223
        block('Barn | inset double door', (x, -.604, .51),
              (.426, .068, .88), door_wood, .017)
        for k in (-1, 1):
            block('Barn | door plank seam', (x + k * .071, -.641, .51),
                  (.012, .009, .81), timber, .003)
        for z in (.18, .80):
            block('Barn | door cross rail', (x, -.666, z),
                  (.392, .052, .055), M['wood'], .014)
        brace = block('Barn | door diagonal brace', (x, -.672, .49),
                      (.058, .055, .66), M['wood'], .013)
        brace.rotation_euler[1] = side * math.atan2(.30, .59)
        uv('Barn | round door handle', (side * .065, -.702, .51),
           (.030, .025, .035), M['metal'], 12, 8)
        block('Barn | entrance jamb', (side * .49, -.715, .52),
              (.105, .14, 1.04), timber, .024)
        block('Barn | front corner post', (side * 1.075, -.707, .70),
              (.15, .14, 1.40), timber, .026)
        block('Barn | rear corner post', (side * 1.075, .615, .70),
              (.15, .14, 1.40), timber, .026)
        block('Barn | front foot beam', (side * .84, -.713, .13),
              (.59, .095, .13), timber, .024)
    block('Barn | entrance lintel', (0, -.718, 1.035),
          (1.10, .16, .125), timber, .025)
    block('Barn | front eaves beam', (0, -.725, 1.30),
          (2.27, .13, .12), timber, .025)
    for x in (-1.145, 1.145):
        for z in (.13, 1.30):
            block('Barn | side horizontal beam', (x, -.025, z),
                  (.095, 1.36, .12), timber, .025)

    # The frame stands proud of a dark reveal and recessed, matte glazing.
    block('Barn | side window recess', (1.164, .035, .84),
          (.030, .59, .48), M['door_dark'], .015)
    block('Barn | side window glass', (1.182, .035, .85),
          (.018, .44, .34), glass, .009)
    for y in (-.25, .32):
        block('Barn | side window jamb', (1.211, y, .86),
              (.100, .080, .49), M['wood'], .018)
    for z in (.62, 1.10):
        block('Barn | side window head and sill', (1.212, .035, z),
              (.108, .66, .075), M['wood'], .020)
    block('Barn | side window mullion', (1.220, .035, .86),
          (.055, .036, .40), M['wood'], .010)
    block('Barn | side window crossbar', (1.220, .035, .86),
          (.055, .48, .036), M['wood'], .010)

    # Three broad tile courses keep the large roof readable at game size.
    S.roof('Barn | roof underlay', (0, 0, 1.37), (2.26, 1.36, .64),
           timber, .12, .025)
    slope = math.atan2(.64, .80)
    for side in (-1, 1):
        for row, y in enumerate((.14, .399, .655)):
            for col in range(6):
                tile = block('Barn | roof tile', ((col - 2.5) * .402, side * y,
                             2.01 - .80 * y + .034),
                             (.395, .366, .062),
                             tile_light if (row + col) % 3 else tile_dark, .022)
                tile.rotation_euler[0] = -side * slope
        block('Barn | eaves fascia', (0, side * .77, 1.36),
              (2.50, .10, .13), timber, .022)
        for x in (-1.215, 1.215):
            rake = block('Barn | gable rake', (x, side * .396, 1.693),
                         (.09, 1.00, .095), timber, .020)
            rake.rotation_euler[0] = -side * slope
    block('Barn | rounded ridge cap', (0, 0, 2.047),
          (2.50, .15, .085), tile_light, .036)
    mesh('Barn | side gable infill',
         [(1.253, -.66, 1.405), (1.253, .66, 1.405), (1.253, 0, 1.933)],
         [(0, 1, 2)], M['wall_cream'], False)

    def crate(name, center, size):
        x, y, z = center
        w, d, h = size
        block(name + ' | box', center, size, door_wood, .024)
        for side in (-1, 1):
            block(name + ' | front corner strap',
                  (x + side * (w * .5 - .036), y - d * .5 - .008, z),
                  (.046, .034, h), M['wood'], .009)
        for dz in (-h * .26, h * .26):
            block(name + ' | front plank gap', (x, y - d * .5 - .009, z + dz),
                  (w - .084, .012, .012), timber, .003)
        block(name + ' | lid', (x, y, z + h * .5 + .015),
              (w + .035, d + .03, .055), M['wood'], .015)
        block(name + ' | lid strap', (x, y, z + h * .5 + .046),
              (.053, d + .012, .019), timber, .006)

    crate('Barn | large crate', (-1.04, -.945, .18), (.38, .35, .34))
    crate('Barn | small crate', (-.64, -.98, .16), (.33, .29, .30))
