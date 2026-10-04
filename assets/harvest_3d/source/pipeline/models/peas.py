"""Peas

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a peas LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    # Curved closed pod with three plump peas visible along the front opening seam.
    uv('Pea pod | curved shell',(0,0,.54),(.88,.36,.27),M['pod'],32,18)
    for i,x in enumerate((-.43,0,.43)):
        z=.73 + (.06 if i==1 else 0)
        uv('Pea | round pea',(x,-.025,z),(.23,.25,.22),M['peas2'] if i==1 else M['peas'],20,14)
    tube('Pea pod | seam',[(-.78,-.13,.66),(-.4,-.19,.75),(0,-.20,.79),(.4,-.19,.75),(.78,-.13,.66)],.027,M['leaf2'])
    leaf('Pea pod | tip leaf',(-.76,0,.58),(-1,-.25),.27,.09,M['leaf2'],.16)
    leaf('Pea pod | tip leaf',( .76,0,.58),(1,.25),.27,.09,M['leaf2'],.16)
