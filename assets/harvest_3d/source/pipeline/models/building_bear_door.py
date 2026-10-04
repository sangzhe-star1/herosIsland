"""Bear door

A grassy mound with a round wooden door in it: the way to the bear's farm.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    fruit_mesh('Bear door | mound', (0, .30, .0), (1.30, 1.0, .62), M['mound_green'], 0, .0)
    cyl('Bear door | frame', (0, -.66, .40), .50, .10, M['wood_dark'], 28)
    cyl('Bear door | door', (0, -.71, .40), .43, .06, M['wood'], 28)
    for o in [x for x in S.scene.objects if x.name.startswith('Bear door | frame') or x.name.startswith('Bear door | door')]:
        o.rotation_euler = (math.pi / 2, 0, 0)
    uv('Bear door | knob', (.20, -.76, .40), (.05, .05, .05), M['metal'], 10, 6)
    for k, x in enumerate((-.6, .55)):
        leaf('Bear door | tuft %d' % k, (x, -.45, .02), (math.cos(k * 2.0), math.sin(k * 2.0)), .22, .05, M['grass_tuft2'], 1.0)
