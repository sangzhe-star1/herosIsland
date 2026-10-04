"""Kennel

A small dog house with a round dark door and a bowl at the step.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    block('Kennel | walls', (0, 0, .42), (1.3, 1.1, .84), M['wall_tan'])
    roof('Kennel | roof', (0, 0, .82), (1.3, 1.1, .50), M['roof_red'])
    cyl('Kennel | round door', (0, -.56, .36), .26, .04, M['door_dark'], 24)
    S.scene.objects['Kennel | round door'].rotation_euler = (math.pi / 2, 0, 0)
    cyl('Kennel | bowl', (.70, -.62, .05), .16, .10, M['metal'], 20)
    cyl('Kennel | water', (.70, -.62, .10), .13, .02, M['water'], 20)
