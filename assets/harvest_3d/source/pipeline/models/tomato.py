"""Tomato

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a tomato LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    fruit_mesh('Tomato | gently lobed ripe fruit',(0,0,.61),(.58,.54,.55),M['tomato'],5,.045)
    uv('Tomato | calyx center',(0,0,1.12),(.12,.12,.06),M['leafdark'],16,10)
    for i in range(6):
        a=2*math.pi*i/6
        leaf('Tomato | pointed calyx',(0,0,1.10),(math.cos(a),math.sin(a)),.29,.085,M['leaf2'] if i%2 else M['leaf'],.20)
    tube('Tomato | short stem',[(0,0,1.10),(0,0,1.20),(0.03,0,1.27)],.035,M['stem'])
