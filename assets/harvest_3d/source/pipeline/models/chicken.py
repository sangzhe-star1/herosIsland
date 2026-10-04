"""Chicken

A brown hen pecking: round body, red comb, yellow beak and feet.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    uv('Hen | body', (0, 0, .34), (.30, .24, .24), M['hen'], 20, 12)
    uv('Hen | tail', (-.30, 0, .46), (.10, .06, .14), M['bark'], 10, 6)
    uv('Hen | head', (.26, 0, .54), (.12, .11, .12), M['hen'], 16, 10)
    uv('Hen | comb', (.26, 0, .66), (.05, .03, .06), M['comb'], 8, 6)
    uv('Hen | wattle', (.32, 0, .46), (.03, .02, .04), M['comb'], 8, 6)
    uv('Hen | beak', (.38, 0, .53), (.06, .035, .03), M['beak'], 8, 6)
    uv('Hen | eye', (.30, -.09, .57), (.02, .015, .02), M['black'], 8, 6)
    for y in (-.08, .08):
        tube('Hen | leg', [(0, y, .14), (.02, y, .0)], .015, M['beak'], 2)
