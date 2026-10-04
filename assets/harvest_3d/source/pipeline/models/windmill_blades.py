"""Windmill sails

Four sails about a hub at the origin, facing the camera. Rendered alone
so the farm can rotate the sprite about its hub.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    for k in range(4):
        a = k * math.pi / 2 + .3
        dx, dz = math.cos(a), math.sin(a)
        tube('Sail | spar %d' % k, [(0, 0, 0), (dx * 1.05, 0, dz * 1.05)], .035, M['wood_dark'], 3)
        o = block('Sail | cloth %d' % k, (dx * .62, .03, dz * .62), (.22, .03, .80), M['sail'], .01)
        o.rotation_euler = (0, -a + math.pi / 2, 0)
    uv('Sail | hub', (0, 0, 0), (.12, .10, .12), M['wood_dark'], 12, 8)
