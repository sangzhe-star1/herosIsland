"""Clearing

Land not yet cleared: a low grassy mound with earth showing through, a
few tufts and pebbles. The movable stones are the farm's own nodes.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    fruit_mesh('Clearing | grass mound', (0, 0, -.02), (1.05, .68, .16), M['grass_tuft'], 0, .0)
    fruit_mesh('Clearing | worn earth', (.08, -.04, .02), (.72, .42, .09), M['pond_edge'], 0, .0)
    fruit_mesh('Clearing | earth light', (-.18, .08, .04), (.30, .18, .05), M['sack'], 0, .0)
    for i, (x, y, a) in enumerate([(-.80, .20, .4), (.70, .30, 2.3), (-.55, -.42, 1.1), (.85, -.25, 3.0), (.10, .55, 1.9)]):
        for k in range(4):
            leaf('Clearing | tuft %d-%d' % (i, k), (x, y, .10), (math.cos(a + k), math.sin(a + k)), .20, .05, M['grass_tuft2' if k % 2 else 'grass_tuft'], 1.1)
    for j, (x, y) in enumerate([(-.30, -.30), (.40, .10), (.05, .32)]):
        uv('Clearing | pebble %d' % j, (x, y, .11), (.07, .05, .035), M['stone2'], 10, 6)
