"""Orchard shed

A mint shed under a moss roof with a small fruit tree beside it.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    block('Orchard | walls', (-.35, 0, .55), (1.4, 1.1, 1.10), M['wall_mint'])
    roof('Orchard | roof', (-.35, 0, 1.08), (1.4, 1.1, .50), M['roof_green'])
    block('Orchard | door', (-.35, -.56, .36), (.36, .04, .72), M['door_dark'], .02)
    trunk = lathe('Orchard | trunk', (.75, .10, 0), [(0, .09), (.6, .07), (.9, .05)], M['bark'], 16, .02)
    fruit_mesh('Orchard | canopy', (.75, .10, 1.25), (.52, .48, .44), M['canopy2'], 5, .03)
    for k, (x, y, z) in enumerate([(.45, -.28, 1.15), (.95, -.30, 1.30), (.70, -.38, 1.42)]):
        uv('Orchard | fruit %d' % k, (x, y, z), (.08, .08, .08), M['orange'], 12, 8)
