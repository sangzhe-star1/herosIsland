"""Apple

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a apple LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    fruit_mesh('Apple | rounded ruby apple',(0,0,.66),(.59,.56,.61),M['apple'],5,.07,True)
    tube('Apple | brown stem',[(0,0,1.19),(0,0,1.32),(.04,.01,1.43)],.060,M['potato'])
    leaf('Apple | fresh leaf',(.025,0,1.29),(1,.25),.43,.16,M['leaf2'],.34)
