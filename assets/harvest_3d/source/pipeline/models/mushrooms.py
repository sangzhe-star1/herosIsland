"""Mushrooms

Three red-capped toadstools of different heights, the kind a child looks for.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    for i, (x, y, h, r) in enumerate([(-.22, .05, .30, .20), (.12, -.08, .42, .26), (.36, .12, .22, .15)]):
        cyl('Mushroom | stem %d' % i, (x, y, h * .5), r * .42, h, M['mushroom_stem'], 16)
        fruit_mesh('Mushroom | cap %d' % i, (x, y, h + r * .25), (r, r, r * .55), M['mushroom_cap'], 0, .0)
        for k in range(4):
            b = 2 * math.pi * k / 4 + i
            uv('Mushroom | spot', (x + r * .55 * math.cos(b), y + r * .55 * math.sin(b), h + r * .55), (r * .18, r * .18, r * .08), M['mushroom_stem'], 8, 6)
