"""Gate

Two posts, an arch beam across the top and two open gate wings: the way
in, and the way the bear comes.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    for x in (-1.0, 1.0):
        block('Gate | post', (x, 0, .70), (.18, .18, 1.40), M['wood_dark'], .02)
        uv('Gate | post cap', (x, 0, 1.44), (.13, .13, .10), M['wood'], 14, 8)
    block('Gate | arch beam', (0, 0, 1.52), (2.3, .16, .16), M['wood'], .02)
    block('Gate | sign', (0, 0, 1.78), (.90, .08, .36), M['paper'], .02)
    for side in (-1, 1):
        wing_x = side * .55; wing_y = -.40
        for k in range(3):
            block('Gate | slat', (wing_x + side * (.25 - .25 * k), wing_y, .55), (.10, .08, 1.0), M['wood'], .01)
        block('Gate | rail', (wing_x, wing_y, .35), (.80, .07, .10), M['wood'], .01)
        block('Gate | rail top', (wing_x, wing_y, .95), (.80, .07, .10), M['wood'], .01)
