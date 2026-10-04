"""Wheat

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a wheat LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    for stalk_i,x in enumerate((-.35,0,.34)):
        y=(stalk_i-1)*.10; height=1.75+(.18 if stalk_i==1 else 0)
        tube('Wheat | slender stalk',[(x,y,.05),(x+.02,y,height*.40),(x-.015,y,height*.73),(x,y,height)],.027,M['stem'],2)
        leaf('Wheat | narrow blade',(x,y,.48),(1 if stalk_i%2 else -1,.25),.52,.075,M['leaf'],.45)
        leaf('Wheat | narrow blade',(x,y,.80),(-1 if stalk_i%2 else 1,-.18),.45,.065,M['leaf2'],.38)
        # A compact ear with paired, tapered seed grains and a few fine awns.
        uv('Wheat | central ear',(x,y,height-.10),(.14,.15,.30),M['wheat'],14,10)
        for j in range(6):
            z=height-.32+j*.095
            for side in (-1,1):
                uv('Wheat | plump grain',(x+side*(.12-.010*j),y-.025,z),(.105,.09,.13),M['wheat2'] if j%2 else M['wheat'],12,8)
                tube('Wheat | fine awn',[(x+side*.10,y,z+.015),(x+side*.22,y,z+.17)],.014,M['wheat2'],1)
