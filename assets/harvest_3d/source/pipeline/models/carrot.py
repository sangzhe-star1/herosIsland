"""Carrot

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a carrot LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    golden = bool(P.get("golden", False))
    color=M['gold'] if golden else M['carrot']; label='Golden carrot' if golden else 'Carrot'
    lathe(label+' | tapered root',(0,0,0),[(.035,.035),(.12,.13),(.30,.24),(.56,.34),(.80,.39),(.98,.32),(1.08,.20),(1.11,.08)],color,40,.025)
    # Slight lighter shoulder freckles/ridges remain soft at sprite size.
    for i in range(5):
        a=i*2*math.pi/5+.25
        leaf(label+' | crown leaf',(0,0,1.02),(math.cos(a),math.sin(a)),.44+(.07*(i%2)),.12,M['leaf2'] if i%2 else M['leaf'],.68)
    tube(label+' | crown stem',[(0,0,1.0),(0,0,1.14),(0,0,1.25)],.045,M['stem'])
