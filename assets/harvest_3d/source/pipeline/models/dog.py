"""Dog

The farm's golden dog, sitting and looking at the camera: round body, big
head, floppy ears, a red collar. He points at what needs doing.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    uv('Dog | body', (0, .10, .50), (.42, .50, .46), M['fur_gold'], 24, 16)
    uv('Dog | chest', (0, -.22, .42), (.30, .22, .34), M['fur_cream'], 20, 12)
    uv('Dog | head', (0, -.30, 1.02), (.36, .34, .33), M['fur_gold'], 24, 16)
    uv('Dog | muzzle', (0, -.60, .92), (.20, .16, .15), M['fur_cream'], 16, 10)
    uv('Dog | nose', (0, -.75, .98), (.07, .05, .05), M['black'], 12, 8)
    for side in (-1, 1):
        uv('Dog | eye', (side * .14, -.58, 1.10), (.045, .03, .05), M['black'], 10, 6)
        uv('Dog | ear', (side * .36, -.22, 1.02), (.10, .16, .24), M['bark'], 16, 10)
        uv('Dog | front paw', (side * .22, -.40, .10), (.13, .18, .10), M['fur_gold'], 14, 8)
        uv('Dog | back paw', (side * .40, .22, .10), (.14, .20, .10), M['fur_gold'], 14, 8)
    tube('Dog | tail', [(0, .58, .40), (.20, .78, .62), (.30, .84, .86)], .06, M['fur_gold'], 3)
    cyl('Dog | collar', (0, -.30, .74), .24, .08, M['collar_red'], 24)
    uv('Dog | tag', (0, -.52, .70), (.05, .02, .05), M['bloom_yellow'], 10, 6)
