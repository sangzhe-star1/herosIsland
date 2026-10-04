"""Watermelon

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a watermelon LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    # Oval melon sits on its rind; pale longitudinal stripes track the curved skin.
    cx,cy,cz=0,0,.55; rx,ry,rz=.98,.65,.52
    uv('Watermelon | oval fruit',(cx,cy,cz),(rx,ry,rz),M['melon'],36,24)
    for k in range(7):
        th=2*math.pi*k/7
        pts=[]
        for i in range(13):
            u=-.94+1.88*i/12; f=math.sqrt(max(.01,1-u*u))
            pts.append((rx*u, ry*f*math.sin(th)*1.012, cz+rz*f*math.cos(th)*1.012))
        tube('Watermelon | pale rind stripe',pts,.023,M['melon2'],2)
