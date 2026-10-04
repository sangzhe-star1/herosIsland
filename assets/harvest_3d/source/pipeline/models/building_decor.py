"""Decor pavilion

A round gazebo: four posts, a lilac cone roof with a little flag, and a
pale floor disk. The door to the decorating room.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    cyl('Pavilion | floor', (0, 0, .05), .95, .10, M['stone2'], 36)
    for k in range(5):
        a = math.pi * 2 * k / 5 + .3
        block('Pavilion | post %d' % k, (.78 * math.cos(a), .78 * math.sin(a), .70), (.10, .10, 1.30), M['wall_lilac'], .01)
    cone('Pavilion | roof', (0, 0, 1.78), 1.12, .80, M['roof_purple'], 36)
    uv('Pavilion | finial', (0, 0, 2.22), (.08, .08, .08), M['bloom_yellow'], 12, 8)
    for k in range(5):
        a = math.pi * 2 * k / 5 + .3
        uv('Pavilion | bunting', (.95 * math.cos(a), .95 * math.sin(a), 1.30), (.07, .07, .06), M['bloom_pink' if k % 2 else 'bloom_yellow'], 10, 6)
