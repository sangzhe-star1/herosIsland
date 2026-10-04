"""Well

A stone ring with water in it, two posts and a little gable roof, the
bucket hanging on its rope.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    ring = cyl('Well | stone ring', (0, 0, .30), .62, .60, M['stone'], 36)
    cyl('Well | water', (0, 0, .50), .50, .04, M['water'], 32)
    cyl('Well | rim', (0, 0, .61), .66, .08, M['stone2'], 36)
    for x in (-.55, .55):
        block('Well | post', (x, .05, 1.05), (.12, .12, 1.0), M['wood_dark'], .02)
    roof('Well | roof', (0, .05, 1.50), (1.3, .9, .42), M['roof_clay'])
    tube('Well | crossbar', [(-.6, .05, 1.42), (.6, .05, 1.42)], .05, M['wood'], 3)
    tube('Well | rope', [(0, .05, 1.42), (0, .05, .95)], .015, M['wood'], 2)
    cyl('Well | bucket', (0, .05, .84), .14, .22, M['metal'], 20)
