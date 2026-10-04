"""Flower bed

A low patch of mixed flowers in a ring of leaves: colour between the beds.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    for i in range(10):
        a = 2 * math.pi * i / 10
        leaf('Flower bed | leaf %d' % i, (.42 * math.cos(a), .32 * math.sin(a), .02), (math.cos(a), math.sin(a)), .26, .10, M['grass_tuft' if i % 2 else 'grass_tuft2'], .6)
    blooms = ['bloom_yellow', 'bloom_pink', 'bloom_lilac']
    for k in range(9):
        a = 2 * math.pi * k / 9 + .4; r = .28 if k % 2 else .14
        x, y = r * math.cos(a) * 1.3, r * math.sin(a)
        tube('Flower bed | stalk %d' % k, [(x, y, .02), (x, y, .22 + .06 * (k % 3))], .014, M['stem'], 2)
        h = .22 + .06 * (k % 3)
        for j in range(5):
            b = 2 * math.pi * j / 5
            uv('Flower bed | petal', (x + .05 * math.cos(b), y + .05 * math.sin(b), h), (.04, .03, .02), M[blooms[k % 3]], 8, 6)
        uv('Flower bed | heart', (x, y, h + .02), (.025, .025, .02), M['bloom_heart'], 8, 6)
