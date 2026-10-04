"""Fence

One post with a rail running through it both ways: the edge of the world,
said gently. The farm places one per post position; `axis` is "x" for
the top and bottom runs and "y" for the sides.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    along_y = str(P.get("axis", "x")) == "y"
    rail = (.07, 1.30, .10) if along_y else (1.30, .07, .10)
    block('Fence | post', (0, 0, .42), (.14, .14, .84), M['wood'], .02)
    uv('Fence | post cap', (0, 0, .86), (.10, .10, .07), M['wood_dark'], 12, 8)
    block('Fence | rail', (0, 0, .58), rail, M['wood'], .01)
    block('Fence | lower rail', (0, 0, .28), rail, M['wood'], .01)
