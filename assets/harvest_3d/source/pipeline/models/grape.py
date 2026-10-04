"""Grape

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a grape LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    # Downward bunch with individual rounded grapes so its berry silhouette reads quickly.
    centers=[(0,0,1.32),(-.30,-.02,1.14),(0,-.05,1.15),(.30,-.02,1.14),(-.43,0,.83),(-.15,-.08,.85),(.16,-.08,.85),(.43,0,.83),(-.28,-.04,.54),(0,-.10,.55),(.28,-.04,.54),(0,0,.25)]
    for i,p in enumerate(centers):
        r=.23 if i<8 else .22
        uv('Grape | round purple berry',p,(r,r*.91,r),M['grape2'] if i%4==0 else M['grape'],20,14)
    tube('Grapes | cluster stem',[(0,0,1.48),(0,0,1.70),(.05,0,1.84)],.045,M['stem'])
    leaf('Grapes | canopy leaf',(.02,0,1.53),(1,.24),.49,.19,M['leaf2'],.20,.03)
