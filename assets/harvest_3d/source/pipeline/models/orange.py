"""Orange

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a orange LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    fruit_mesh('Orange | round fruit',(0,0,.60),(.62,.60,.57),M['orange'],.0,.035)
    uv('Orange | stem dimple',(0,0,1.16),(.105,.105,.035),M['orange2'],16,8)
    uv('Orange | small green stem',(0,0,1.20),(.065,.065,.08),M['stem'],12,8)
    leaf('Orange | small leaf',(0,0,1.20),(1,.25),.36,.13,M['leaf2'],.27)
    # Sparse shallow peel dimples, kept broad and low contrast.
    for x,y,z in [(-.30,-.47,.55),(.14,-.56,.72),(.39,-.38,.44),(-.08,-.56,.32)]:
        uv('Orange | subtle peel dot',(x,y,z),(.022,.016,.022),M['orange2'],8,6)
