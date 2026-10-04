"""Bench

A wooden bench facing the beds, for a grown-up to sit on.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    block('Bench | seat', (0, 0, .42), (1.20, .36, .07), M['wood'], .02)
    block('Bench | back', (0, .18, .68), (1.20, .06, .34), M['wood'], .02)
    for x in (-.48, .48):
        block('Bench | leg', (x, 0, .20), (.10, .34, .40), M['wood_dark'], .02)
