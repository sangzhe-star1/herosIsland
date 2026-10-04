"""Hay bale

Two round bales, one leaning on the other.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    a = cyl('Hay | bale', (-.25, .05, .40), .40, .70, M['hay'], 28)
    a.rotation_euler = (0, math.pi / 2, 0)
    b = cyl('Hay | second bale', (.45, -.05, .32), .32, .60, M['hay2'], 28)
    b.rotation_euler = (0, math.pi / 2, .5)
    for k in range(3):
        band = cyl('Hay | band %d' % k, (-.25 + (k - 1) * .22, .05, .40), .41, .04, M['hay2'], 28)
        band.rotation_euler = (0, math.pi / 2, 0)
