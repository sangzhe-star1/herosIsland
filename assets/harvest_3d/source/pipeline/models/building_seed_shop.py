"""Seed shop

A cream hut with a red-and-white striped awning over the counter and a
crate of seedlings by the door.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    block('Shop | walls', (0, 0, .62), (2.0, 1.3, 1.24), M['wall_cream'])
    roof('Shop | roof', (0, 0, 1.22), (2.0, 1.3, .60), M['roof_clay'])
    block('Shop | door', (.55, -.66, .40), (.40, .04, .80), M['door_dark'], .02)
    block('Shop | counter', (-.40, -.78, .32), (1.0, .26, .64), M['wood'], .03)
    for i in range(6):
        x = -.90 + .20 * i
        block('Shop | awning stripe %d' % i, (x + .1, -.82, 1.02), (.20, .50, .05),
              M['canvas_red' if i % 2 == 0 else 'canvas_white'], .01)
    block('Shop | crate', (1.25, -.55, .16), (.40, .36, .32), M['wood_dark'], .02)
    for j, (x, y) in enumerate([(1.14, -.62), (1.30, -.50), (1.36, -.64), (1.18, -.46)]):
        leaf('Shop | seedling %d' % j, (x, y, .32), (math.cos(j), math.sin(j)), .16, .05, M['leaf2'], 1.1)
