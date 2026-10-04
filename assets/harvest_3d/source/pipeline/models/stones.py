"""Stones

Three field stones in a cluster, flattened where they meet the ground.
The single `stone` crop model is the thing a child pushes aside on a bed;
this is scenery and stays passive.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    rng = random.Random(int(P.get("seed", 5)))
    for i, (cx, cy, rx, ry, rz) in enumerate([(-.42, .06, .30, .24, .20),
                                              (.12, -.08, .38, .30, .26),
                                              (.58, .14, .24, .19, .15)]):
        verts = []; faces = []; nlat = 10; nlon = 16
        for a in range(nlat + 1):
            phi = math.pi * a / nlat
            for b in range(nlon):
                th = 2 * math.pi * b / nlon
                f = 1 + rng.uniform(-.08, .08)
                x = rx * math.sin(phi) * math.cos(th) * f
                y = ry * math.sin(phi) * math.sin(th) * f
                z = max(-rz * .75, rz * math.cos(phi) * f)
                verts.append((cx + x, cy + y, rz * .78 + z))
        for a in range(nlat):
            for b in range(nlon):
                p = a * nlon + b; q = a * nlon + (b + 1) % nlon
                faces.append((p, q, q + nlon, p + nlon))
        o = mesh('Stones | stone %d' % i, verts, faces, M['stone' if i != 1 else 'stone2'], False)
        bevel = o.modifiers.new('Soft edges', 'BEVEL'); bevel.width = .03; bevel.segments = 2
        uv('Stones | pale facet %d' % i, (cx + rx * .25, cy - ry * .55, rz * 1.2), (rx * .28, .03, rz * .3), M['stone2'], 10, 6)
