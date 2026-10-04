"""Scarecrow

A friendly scarecrow on a pole: straw hat, blue shirt, a smile of a nose.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    tube('Scarecrow | pole', [(0, 0, 0), (0, 0, 1.9)], .05, M['wood_dark'], 3)
    tube('Scarecrow | arms', [(-.70, 0, 1.35), (.70, 0, 1.35)], .045, M['wood_dark'], 3)
    block('Scarecrow | shirt', (0, 0, 1.15), (.56, .40, .64), M['scarecrow_shirt'], .06)
    for side in (-1, 1):
        block('Scarecrow | sleeve', (side * .45, 0, 1.35), (.46, .24, .22), M['scarecrow_shirt'], .05)
        uv('Scarecrow | straw hand', (side * .72, 0, 1.35), (.09, .07, .07), M['hay'], 10, 6)
    uv('Scarecrow | head', (0, 0, 1.68), (.24, .22, .24), M['sack'], 20, 12)
    uv('Scarecrow | nose', (0, -.22, 1.66), (.05, .06, .05), M['carrot'], 10, 6)
    for side in (-1, 1):
        uv('Scarecrow | eye', (side * .09, -.20, 1.74), (.03, .02, .03), M['black'], 8, 6)
    cone('Scarecrow | hat', (0, 0, 2.02), .26, .36, M['scarecrow_hat'], 20)
    cyl('Scarecrow | brim', (0, 0, 1.86), .40, .04, M['scarecrow_hat'], 24)
    uv('Scarecrow | straw skirt', (0, 0, .78), (.22, .16, .18), M['hay'], 14, 8)
