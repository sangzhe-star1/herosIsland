"""Market stall

A counter under a striped canopy on four posts, with the produce he can
sell lined up on top.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    block('Market | counter', (0, -.25, .40), (2.0, .70, .80), M['wood'], .03)
    block('Market | counter top', (0, -.25, .82), (2.1, .80, .06), M['wood_dark'], .01)
    for x in (-.95, .95):
        for y in (-.60, .50):
            block('Market | post', (x, y, .90), (.10, .10, 1.80), M['wood_dark'], .01)
    for i in range(7):
        x = -1.05 + .30 * i
        block('Market | canopy stripe %d' % i, (x + .15, 0, 1.86), (.30, 1.40, .06),
              M['canvas_red' if i % 2 == 0 else 'canvas_white'], .01)
    uv('Market | tomato', (-.55, -.30, .97), (.14, .14, .13), M['tomato'], 16, 10)
    uv('Market | orange', (-.15, -.30, .97), (.14, .14, .13), M['orange'], 16, 10)
    uv('Market | apple', (.25, -.30, .97), (.13, .13, .13), M['apple'], 16, 10)
    block('Market | basket', (.75, -.30, .96), (.36, .30, .20), M['wood'], .02)
