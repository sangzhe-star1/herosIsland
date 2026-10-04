"""Tree

A toy tree for the farm's edges: a leaning walnut trunk and three rounded
canopy lobes, lit like everything else. Round, matte, no outline. Params:
  lean   trunk lean in metres at the top (default .08)
  seed   which lobe is the bright one (0..2)
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    lean = float(P.get("lean", .08))
    bright = int(P.get("seed", 1)) % 3
    trunk = lathe('Tree | trunk', (0, 0, 0), [(0.0, .19), (.10, .17), (.55, .14),
        (1.05, .12), (1.35, .13), (1.45, .09)], M['bark'], 28, .03)
    for v in trunk.data.vertices:
        v.co.x += lean * (v.co.z / 1.45) ** 1.5
    # One flared root and a sunlit sliver give the trunk a side.
    uv('Tree | root flare', (-.12, -.05, .05), (.14, .11, .07), M['bark'], 14, 8)
    tube('Tree | sunlit bark', [(-.15, -.12, .12), (-.11, -.11, .70), (-.05, -.10, 1.15)],
         .028, M['bark2'], 2)
    lobes = [((-.36, .12, 1.72), (.60, .56, .52)),
             ((.34, .04, 1.78), (.62, .58, .54)),
             ((lean, -.14, 2.18), (.52, .50, .46))]
    for i, (centre, scale) in enumerate(lobes):
        mat = M['canopy2'] if i == bright else (M['canopy3'] if i == (bright + 1) % 3 else M['canopy'])
        fruit_mesh('Tree | canopy lobe %d' % i, centre, scale, mat, 6, .03)
