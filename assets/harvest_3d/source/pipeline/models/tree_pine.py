"""Pine

A taller evergreen: three stacked cones on a short trunk, for the far edge.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    lathe('Pine | trunk', (0, 0, 0), [(0, .16), (.5, .12), (.9, .10)], M['bark'], 20, .02)
    for i, (z, r, h) in enumerate([(.75, .78, .95), (1.35, .62, .85), (1.90, .44, .75)]):
        cone('Pine | tier %d' % i, (0, 0, z + h * .5), r, h, M['pine2' if i == 1 else 'pine'], 28)
