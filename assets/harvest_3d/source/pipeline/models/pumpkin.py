"""Pumpkin

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a pumpkin LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    fruit_mesh('Pumpkin | squat ribbed squash',(0,0,.64),(.96,.88,.63),M['pumpkin'],9,.07)
    # Gentle pale ribs ride just above the orange lobes.
    for k in range(9):
        a=2*math.pi*k/9
        pts=[]
        for i in range(9):
            t=-1+2*i/8; rr=math.sqrt(max(.02,1-t*t))
            pts.append((.985*rr*math.cos(a),.90*rr*math.sin(a),.64+.645*t))
        tube('Pumpkin | soft rib',pts,.018,M['pumpkin2'],2)
    tube('Pumpkin | sturdy green stem',[(0,0,1.18),(0,0,1.32),(.03,0,1.42),(.10,0,1.45)],.095,M['stem'])
