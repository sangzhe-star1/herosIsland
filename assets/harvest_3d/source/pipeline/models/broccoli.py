"""Broccoli

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a broccoli LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    tube('Broccoli | thick edible stem',[(0,0,.06),(0,0,.38),(.02,0,.78)],.16,M['lettuce2'])
    uv('Broccoli | stem cap',(0,0,.69),(.36,.34,.27),M['lettuce2'],20,12)
    positions=[(-.40,0,1.18),(-.20,-.18,1.35),(.12,-.26,1.35),(.40,-.08,1.19),(.29,.20,1.20),(-.12,.23,1.27),(-.43,-.28,1.03),(.02,.02,1.52)]
    for i,p in enumerate(positions):
        uv('Broccoli | rounded crown floret',p,(.30,.28,.30),M['broccoli2'] if i%3==0 else M['broccoli'],20,14)
        # One or two smaller bumps enrich each floret without noisy detail.
        for j in range(3):
            a=2*math.pi*j/3
            uv('Broccoli | crown bump',(p[0]+.14*math.cos(a),p[1]+.14*math.sin(a),p[2]+.18),(.105,.10,.10),M['broccoli2'] if j==0 else M['broccoli'],12,8)
