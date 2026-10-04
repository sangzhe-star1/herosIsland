"""Potato

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a potato LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    # A small cluster gives the digging root crop a distinct lumpy silhouette.
    uv('Potato | main tuber',(0,0,.40),(.61,.49,.39),M['potato'],28,18)
    uv('Potato | side tuber',(.36,.10,.30),(.39,.35,.29),M['potato2'],22,14)
    uv('Potato | rear tuber',(-.31,.20,.26),(.35,.32,.25),M['potato'],20,14)
    # A few shallow eyes on camera-facing surfaces.
    for x,y,z in [(-.31,-.44,.48),(.14,-.47,.61),(.40,-.23,.35),(-.12,-.43,.28)]:
        uv('Potato | tiny eye', (x,y,z),(.055,.025,.040),M['potato2'],12,8)
