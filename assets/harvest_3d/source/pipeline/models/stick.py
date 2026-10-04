"""Stick

A thrown stick for the dog: a short branch with one fork.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    tube('Stick | branch', [(-.30, .0, .04), (.0, .02, .05), (.32, -.01, .04)], .028, M['bark'], 3)
    tube('Stick | fork', [(.10, .01, .05), (.24, .08, .12)], .018, M['bark2'], 2)
