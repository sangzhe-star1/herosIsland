"""Flour

A small tied sack with flour spilling at its mouth: what the mill gives for
wheat. Rendered close so it reads as an icon.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    uv('Flour | sack', (0, 0, .24), (.20, .17, .24), M['sack'], 20, 12)
    cyl('Flour | neck', (0, 0, .50), .07, .06, M['sack'], 14)
    tube('Flour | tie', [(-.09, -.06, .49), (.0, -.09, .50), (.09, -.06, .49)], .012, M['wood_dark'], 2)
    uv('Flour | spill', (.0, -.14, .54), (.07, .05, .03), M['paper'], 12, 8)
    uv('Flour | dust', (.12, -.12, .04), (.06, .04, .015), M['paper'], 10, 6)
