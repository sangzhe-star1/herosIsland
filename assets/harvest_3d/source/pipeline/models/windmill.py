"""Windmill

The tower only: a tapered cream body with a brown cap and a door. The sails
are their own prop (windmill_blades) so the farm can turn them.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    lathe('Windmill | tower', (0, 0, 0), [(0, .62), (.6, .56), (1.4, .48), (2.1, .42), (2.2, .40)], M['wall_cream'], 28, .0)
    cone('Windmill | cap', (0, 0, 2.48), .52, .60, M['roof_brown'], 28)
    block('Windmill | door', (0, -.58, .40), (.34, .06, .70), M['door_dark'], .02)
    block('Windmill | window', (.05, -.50, 1.45), (.26, .06, .30), M['wall_blue'], .02)
    uv('Windmill | hub', (0, -.46, 2.10), (.10, .08, .10), M['wood_dark'], 12, 8)
