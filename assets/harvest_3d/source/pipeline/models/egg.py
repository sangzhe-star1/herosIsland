"""Egg

One cream egg standing on its wide end: the barn's picture of what the
hens give. Rendered close so it fills the canvas like an icon.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    fruit_mesh('Egg | shell', (0, 0, .26), (.19, .19, .26), M['mushroom_stem'], 0, .0)
    for v in S.scene.objects['Egg | shell'].data.vertices:
        # An egg is narrower at the top than a sphere scaled is.
        t = (v.co.z - .26) / .26
        if t > 0:
            v.co.x *= 1.0 - .22 * t * t
            v.co.y *= 1.0 - .22 * t * t
    uv('Egg | freckle', (.09, -.14, .30), (.02, .012, .018), M['sack'], 8, 6)
    uv('Egg | freckle two', (-.06, -.16, .22), (.016, .01, .014), M['sack'], 8, 6)
