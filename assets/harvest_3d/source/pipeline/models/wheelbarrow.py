"""Wheelbarrow

A red wheelbarrow with a sack and a pumpkin in it, handles toward the barn.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    block('Barrow | tub', (0, 0, .42), (.90, .60, .36), M['canvas_red'], .05)
    block('Barrow | tub inside', (0, 0, .52), (.78, .48, .20), M['door_dark'], .02)
    uv('Barrow | sack', (-.15, .02, .62), (.26, .20, .18), M['sack'], 16, 10)
    uv('Barrow | pumpkin', (.22, -.05, .64), (.18, .17, .15), M['pumpkin'], 16, 10)
    w = cyl('Barrow | wheel', (.55, 0, .20), .20, .08, M['wheel'], 20)
    w.rotation_euler = (math.pi / 2, 0, 0)
    for y in (-.18, .18):
        tube('Barrow | handle', [(-.40, y, .30), (-.95, y, .42)], .03, M['wood'], 3)
        tube('Barrow | leg', [(-.30, y, .25), (-.32, y, .0)], .03, M['wood_dark'], 2)
