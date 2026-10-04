"""Butterfly

Two wings and a body, seen from the side as it flutters. Params: wing
(palette key).
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    wing = M[P.get("wing", "butterfly")]
    uv('Butterfly | body', (0, 0, .30), (.025, .09, .025), M['black'], 8, 6)
    for side in (-1, 1):
        uv('Butterfly | wing', (side * .11, .02, .34), (.11, .09, .015), wing, 12, 8)
        uv('Butterfly | lower wing', (side * .08, -.08, .31), (.07, .06, .012), wing, 10, 6)
