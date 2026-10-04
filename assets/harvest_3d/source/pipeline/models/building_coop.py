"""Hen coop

A little house on short legs with a ramp down to the grass, a round hen
door and a nest box: where corn becomes eggs.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    for x, y in ((-.55, -.35), (.55, -.35), (-.55, .35), (.55, .35)):
        block('Coop | leg', (x, y, .20), (.10, .10, .40), M['wood_dark'], .01)
    block('Coop | floor', (0, 0, .42), (1.5, 1.0, .08), M['wood'], .02)
    block('Coop | walls', (0, 0, .92), (1.4, .9, .92), M['wall_tan'])
    roof('Coop | roof', (0, 0, 1.36), (1.4, .9, .46), M['roof_red'])
    door = cyl('Coop | hen door', (-.30, -.47, .78), .22, .04, M['door_dark'], 20)
    door.rotation_euler = (math.pi / 2, 0, 0)
    ramp = block('Coop | ramp', (-.30, -.95, .22), (.34, .90, .05), M['wood'], .01)
    ramp.rotation_euler = (.45, 0, 0)
    for k in range(4):
        step = block('Coop | ramp step', (-.30, -.62 - .19 * k, .40 - .11 * k), (.34, .04, .03), M['wood_dark'], .005)
        step.rotation_euler = (.45, 0, 0)
    block('Coop | nest box', (.78, .05, .70), (.36, .50, .40), M['wood_dark'], .02)
    roof('Coop | nest lid', (.78, .05, .90), (.36, .50, .14), M['roof_red'], .04)
    uv('Coop | straw', (-.62, -.42, .47), (.14, .10, .05), M['hay'], 10, 6)
    uv('Coop | straw two', (.20, -.42, .47), (.12, .09, .04), M['hay2'], 10, 6)
