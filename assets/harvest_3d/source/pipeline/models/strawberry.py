"""Strawberry

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a strawberry LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    # Rounded, tapered berry with a broad shoulder and softly pointed tip.
    lathe('Strawberry | heart-shaped berry',(0,0,0),[(.035,.045),(.11,.15),(.26,.29),(.43,.40),(.62,.43),(.78,.36),(.90,.22),(.94,.08)],M['strawberry'],40,.025)
    for i in range(7):
        a=2*math.pi*i/7
        leaf('Strawberry | green crown',(0,0,.90),(math.cos(a),math.sin(a)),.34,.135,M['leaf'] if i%2 else M['leaf2'],.42)
    # Pale seeds set on the visible front curve.
    for row,(z,rad,count) in enumerate(((.19,.22,5),(.38,.34,6),(.59,.36,6),(.76,.25,4))):
        for j in range(count):
            x=rad*math.cos(2*math.pi*j/count+row*.34)
            yy=-rad*math.sqrt(max(.035,1-(x/rad)**2))-.012
            uv('Strawberry | seed', (x,yy,z),(.027,.016,.043),M['seed'],10,6)
