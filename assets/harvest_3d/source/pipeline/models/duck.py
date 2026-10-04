"""Duck

A small white duck, floating: body, head, orange beak. Bobs on the pond.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    uv('Duck | body', (0, 0, .16), (.30, .20, .16), M['duck'], 20, 12)
    uv('Duck | tail', (-.28, 0, .24), (.08, .06, .06), M['duck'], 10, 6)
    uv('Duck | head', (.22, 0, .40), (.13, .12, .13), M['duck'], 16, 10)
    uv('Duck | beak', (.36, 0, .38), (.08, .05, .035), M['beak'], 10, 6)
    uv('Duck | eye', (.27, -.09, .44), (.02, .015, .02), M['black'], 8, 6)
