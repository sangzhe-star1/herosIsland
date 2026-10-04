"""Signpost

A post with two arrows pointing different ways, by the gate.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    block('Signpost | post', (0, 0, .70), (.12, .12, 1.40), M['wood_dark'], .02)
    block('Signpost | arrow up', (.30, -.02, 1.20), (.70, .06, .20), M['wood'], .02)
    block('Signpost | arrow down', (-.26, -.02, .92), (.62, .06, .20), M['wood'], .02)
    uv('Signpost | cap', (0, 0, 1.42), (.09, .09, .06), M['wood'], 10, 6)
