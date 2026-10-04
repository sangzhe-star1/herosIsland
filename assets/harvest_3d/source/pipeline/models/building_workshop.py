"""Workshop

A sky-blue workshop with a slate roof, a chimney and a wide window: the
kitchen where the recipes are cooked.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    block('Workshop | walls', (0, 0, .62), (2.0, 1.3, 1.24), M['wall_blue'])
    roof('Workshop | roof', (0, 0, 1.22), (2.0, 1.3, .58), M['roof_blue'])
    block('Workshop | chimney', (.65, .20, 1.62), (.22, .22, .50), M['stone'], .02)
    block('Workshop | door', (-.55, -.66, .40), (.40, .04, .80), M['door_dark'], .02)
    block('Workshop | wide window', (.30, -.66, .78), (.70, .04, .34), M['paper'], .02)
    block('Workshop | window bar', (.30, -.68, .78), (.04, .05, .34), M['wood_dark'], .005)
    uv('Workshop | smoke', (.65, .20, 1.98), (.12, .12, .10), M['white'], 12, 8)
    uv('Workshop | smoke two', (.72, .16, 2.16), (.09, .09, .08), M['white'], 12, 8)
