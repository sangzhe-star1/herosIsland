"""Pond

A still pond with a muddy bank, two lily pads and a reed clump.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    cyl('Pond | bank', (0, 0, .03), 1.05, .06, M['pond_edge'], 40)
    o = cyl('Pond | water', (0, 0, .06), .92, .02, M['pond'], 40)
    o.scale = (1.0, .72, 1.0)
    bank = S.scene.objects['Pond | bank']; bank.scale = (1.0, .74, 1.0)
    for k, (x, y) in enumerate([(-.35, .15), (.30, -.20), (.55, .25)]):
        cyl('Pond | lily pad %d' % k, (x, y, .08), .14, .02, M['lily'], 16)
    uv('Pond | lily flower', (-.35, .15, .12), (.05, .05, .04), M['bloom_pink'], 8, 6)
    for k in range(5):
        a = 2.4 + .3 * k
        tube('Pond | reed %d' % k, [(-.80 + .06 * k, .40 - .04 * k, .02), (-.78 + .06 * k, .42 - .04 * k, .45 + .08 * (k % 2))], .018, M['grass_tuft'], 2)
        uv('Pond | reed head', (-.78 + .06 * k, .42 - .04 * k, .50 + .08 * (k % 2)), (.025, .025, .06), M['bark'], 8, 6)
