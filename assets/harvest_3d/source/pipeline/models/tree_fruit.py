"""Fruit tree

A round apple tree with red fruit on the camera side.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    trunk = lathe('Fruit tree | trunk', (0, 0, 0), [(0, .17), (.4, .13), (.95, .11), (1.1, .08)], M['bark'], 24, .03)
    for i, (c, s_, key) in enumerate([((-.30, .10, 1.55), (.56, .52, .50), 'canopy'),
                                      ((.32, .02, 1.60), (.58, .54, .50), 'canopy2'),
                                      ((.0, -.10, 1.98), (.50, .48, .44), 'canopy2')]):
        fruit_mesh('Fruit tree | lobe %d' % i, c, s_, M[key], 5, .02)
    for k, (x, y, z) in enumerate([(-.55, -.35, 1.45), (-.10, -.55, 1.30), (.40, -.45, 1.45), (.62, -.20, 1.75), (.05, -.42, 1.92), (-.40, -.30, 1.90)]):
        uv('Fruit tree | apple %d' % k, (x, y, z), (.10, .10, .10), M['apple'], 12, 8)
