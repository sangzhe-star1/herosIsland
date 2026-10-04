"""Flowering bush

A hedge with pink blooms over it: the one by the pavilion.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    for i, (c, s_, key) in enumerate([((-.45, .18, .34), (.44, .38, .36), 'canopy'), ((.04, -.10, .42), (.54, .44, .44), 'canopy2'), ((.50, .20, .30), (.38, .34, .32), 'canopy3')]):
        fruit_mesh('Flower bush | lobe %d' % i, c, s_, M[key], 5, .02)
    for k, (x, y, z) in enumerate([(-.55, -.18, .55), (-.20, -.45, .60), (.15, -.50, .75), (.45, -.25, .50), (.60, -.05, .45), (-.10, -.25, .85), (.30, .05, .80)]):
        uv('Flower bush | bloom %d' % k, (x, y, z), (.07, .07, .05), M['bloom_pink' if k % 3 else 'bloom_lilac'], 10, 6)
        uv('Flower bush | heart %d' % k, (x, y, z + .03), (.03, .03, .02), M['bloom_heart'], 8, 6)
