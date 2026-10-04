"""Meadow patch

An untilled bed: raised grass with daisies, the ground a shovel turns into
the soil patch. Same footprint as soil_grass_patch so the swap is quiet.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    fruit_mesh('Meadow | grass mound', (0, 0, -.02), (1.02, .62, .17), M['canopy2'], 0, .0)
    fruit_mesh('Meadow | lighter crown', (-.10, .06, .06), (.70, .40, .09), M['grass_tuft2'], 0, .0)
    for i, (x, y, a) in enumerate([(-.70, .18, .4), (.62, .26, 2.3), (-.40, -.36, 1.1), (.78, -.20, 3.0), (.05, .48, 1.9), (.20, -.40, .8), (-.85, -.05, 2.8)]):
        for k in range(5):
            leaf('Meadow | tuft %d-%d' % (i, k), (x, y, .12), (math.cos(a + k * 1.3), math.sin(a + k * 1.3)), .24, .055, M['grass_tuft2' if k % 2 else 'grass_tuft'], 1.15)
    for j, (x, y) in enumerate([(-.25, -.22), (.38, .08), (.00, .30)]):
        tube('Meadow | daisy stalk %d' % j, [(x, y, .12), (x, y, .34)], .012, M['stem'], 2)
        for k in range(6):
            b = 2 * math.pi * k / 6
            uv('Meadow | petal', (x + .05 * math.cos(b), y + .05 * math.sin(b), .35), (.035, .025, .015), M['paper'], 8, 6)
        uv('Meadow | heart', (x, y, .37), (.025, .025, .02), M['bloom_yellow'], 8, 6)
