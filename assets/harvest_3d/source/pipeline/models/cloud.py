"""Rain cloud

A soft grey-white cloud he can drag over a thirsty bed. Floats; placed by
its centre.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    for i, (c, s_) in enumerate([((-.42, .0, .62), (.36, .30, .30)), ((.0, .05, .70), (.44, .36, .36)),
                                 ((.42, -.02, .62), (.34, .28, .28)), ((-.15, -.18, .52), (.30, .24, .22)),
                                 ((.22, -.20, .52), (.30, .24, .22))]):
        uv('Cloud | puff %d' % i, c, s_, M['paper'] if i != 3 and i != 4 else M['stone2'], 20, 12)
