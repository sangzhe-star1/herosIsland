"""Bear

The neighbour: a round brown teddy sitting up with one paw raised, as he
stands by his well. Lighter belly and muzzle, little round ears.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    uv('Bear | body', (0, 0, .62), (.58, .52, .62), M['fur_bear'], 24, 16)
    uv('Bear | belly', (0, -.30, .58), (.38, .22, .44), M['fur_bear2'], 20, 12)
    uv('Bear | head', (0, -.10, 1.42), (.46, .44, .42), M['fur_bear'], 24, 16)
    uv('Bear | muzzle', (0, -.46, 1.30), (.22, .16, .16), M['fur_bear2'], 16, 10)
    uv('Bear | nose', (0, -.62, 1.36), (.08, .05, .06), M['black'], 12, 8)
    for side in (-1, 1):
        uv('Bear | ear', (side * .36, 0, 1.78), (.14, .12, .14), M['fur_bear'], 14, 8)
        uv('Bear | inner ear', (side * .36, -.08, 1.78), (.08, .06, .08), M['fur_bear2'], 12, 8)
        uv('Bear | eye', (side * .16, -.48, 1.50), (.05, .03, .05), M['black'], 10, 6)
        uv('Bear | leg', (side * .40, -.30, .20), (.22, .30, .20), M['fur_bear'], 16, 10)
        uv('Bear | sole', (side * .42, -.56, .22), (.12, .06, .12), M['fur_bear2'], 12, 8)
    uv('Bear | arm down', (-.60, -.10, .80), (.16, .18, .34), M['fur_bear'], 16, 10)
    tube('Bear | arm up', [(.55, -.05, .90), (.80, -.10, 1.30), (.90, -.14, 1.56)], .15, M['fur_bear'], 4)
    uv('Bear | paw up', (.92, -.15, 1.64), (.17, .14, .15), M['fur_bear2'], 14, 8)
