"""Sprig

A grass tuft with two small flowers: the quiet colour the corridors between
beds carry. Params: bloom = yellow | pink | lilac (palette keys bloom_*).
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    bloom = M['bloom_' + str(P.get("bloom", "yellow"))]
    for i in range(6):
        a = -2.0 + 4.0 * i / 5 + 1.57
        leaf('Sprig | blade %d' % i, (0, 0, .02), (math.cos(a) * .35, math.sin(a) * .35),
             .36 + .08 * (i % 2), .05, M['grass_tuft2' if i % 2 else 'grass_tuft'], 1.05, .0)
    for j, (x, y, h) in enumerate([(-.16, -.08, .46), (.18, .02, .52)]):
        tube('Sprig | stalk %d' % j, [(x * .3, y * .3, .05), (x, y, h)], .014, M['stem'], 2)
        for k in range(5):
            b = 2 * math.pi * k / 5
            uv('Sprig | petal', (x + .055 * math.cos(b), y + .055 * math.sin(b), h + .01),
               (.045, .035, .02), bloom, 10, 6)
        uv('Sprig | heart', (x, y, h + .025), (.03, .03, .022), M['bloom_heart'], 10, 6)
