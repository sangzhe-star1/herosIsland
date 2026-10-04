"""Hut

The plain farm hut: a cream box under a terracotta gable, a dark door on
the camera side and one window. Params: wall, roof (palette keys).
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    wall = M[P.get("wall", "wall_cream")]; top = M[P.get("roof", "roof_clay")]
    block('Hut | walls', (0, 0, .62), (2.0, 1.3, 1.24), wall)
    roof('Hut | roof', (0, 0, 1.22), (2.0, 1.3, .62), top)
    block('Hut | door', (-.35, -.66, .40), (.40, .04, .80), M['door_dark'], .02)
    block('Hut | window', (.45, -.66, .78), (.36, .04, .30), M['wall_blue'], .02)
    block('Hut | window sill', (.45, -.68, .61), (.44, .06, .05), M['wood_dark'], .01)
    block('Hut | step', (-.35, -.74, .05), (.50, .16, .10), M['stone2'], .02)
