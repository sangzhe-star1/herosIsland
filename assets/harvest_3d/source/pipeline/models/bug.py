"""Bug

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a bug LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    # A friendly ladybug clutter token: red shell, black head/spots, tiny legs and antennae.
    uv('Bug | red domed shell',(0,.06,.31),(.43,.47,.24),M['bug'],28,18)
    uv('Bug | head',(0,-.34,.25),(.27,.22,.20),M['black'],20,12)
    tube('Bug | shell center seam',[(0,-.30,.36),(0,0,.53),(0,.37,.37)],.018,M['black'],2)
    for x,y,z in [(-.23,-.08,.46),(.23,-.08,.46),(-.24,.19,.45),(.24,.19,.45)]:
        uv('Bug | black spot',(x,y,z),(.085,.075,.035),M['black'],12,8)
    for side in (-1,1):
        uv('Bug | bright eye',(side*.105,-.51,.30),(.055,.035,.060),M['white'],12,8)
        uv('Bug | pupil',(side*.11,-.54,.30),(.024,.018,.028),M['black'],10,6)
        tube('Bug | antenna',[(side*.10,-.50,.40),(side*.17,-.60,.52),(side*.22,-.62,.57)],.018,M['black'],2)
        for y in (-.19,.05,.28):
            tube('Bug | tiny leg',[(side*.30,y,.22),(side*.48,y-.04,.13),(side*.53,y-.09,.08)],.025,M['black'],2)
