"""Tuft

A clump of meadow grass: seven narrow blades fanning up from one root.
Scenery between the beds, never a target.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    for i in range(7):
        a = -2.2 + 4.4 * i / 6 + 1.57
        length = .42 + .10 * (i % 3 == 1)
        leaf('Tuft | blade %d' % i, (0, 0, .02), (math.cos(a) * .35, math.sin(a) * .35),
             length, .055, M['grass_tuft2' if i % 2 else 'grass_tuft'], 1.15 - .12 * abs(i - 3), .0)
