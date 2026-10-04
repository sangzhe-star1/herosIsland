"""Notice board

A board on two posts with a sheet of paper pinned to it. Params: frame
(palette key) tells the orders board from the visitors' board.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    frame = M[P.get("frame", "wood")]
    for x in (-.55, .55):
        block('Board | post', (x, 0, .70), (.12, .12, 1.40), M['wood_dark'], .02)
    block('Board | board', (0, 0, 1.15), (1.4, .10, .95), frame, .03)
    block('Board | paper', (0, -.07, 1.17), (1.1, .02, .74), M['paper'], .005)
    for x, z in ((-.42, 1.45), (.42, 1.45)):
        uv('Board | pin', (x, -.10, z), (.04, .03, .04), M['pin_red'], 10, 6)
    roof('Board | little roof', (0, 0, 1.66), (1.4, .3, .22), frame)
