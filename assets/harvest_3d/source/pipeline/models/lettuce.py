"""Lettuce

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a lettuce LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    for i in range(9):
        a=2*math.pi*i/9
        leaf('Lettuce | broad ruffled outer leaf',(0,0,.23),(math.cos(a),math.sin(a)),.78,.29,M['lettuce'] if i%3 else M['lettuce2'],.34,.10)
    for i in range(6):
        a=2*math.pi*i/6+.2
        leaf('Lettuce | inner cup leaf',(0,0,.46),(math.cos(a),math.sin(a)),.46,.23,M['lettuce2'] if i%2 else M['lettuce'],.60,.055)
    uv('Lettuce | heart',(0,0,.77),(.20,.19,.22),M['lettuce2'],16,10)
