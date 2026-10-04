"""Corn

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a corn LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    # Short husk leaves cradle a kernel-packed golden cob.
    lathe('Corn | cob',(0,0,.20),[(.02,.08),(.10,.23),(.35,.31),(.68,.32),(.98,.26),(1.16,.14),(1.20,.04)],M['corn'],36,.012)
    # Six spiral-ish rows of large rounded kernels.
    for iz,z in enumerate((.34,.51,.68,.85,1.02)):
        radius=.285*(1-abs(z-.68)*.20)
        for j in range(8):
            th=2*math.pi*j/8+iz*.13
            x=radius*math.cos(th); y=radius*math.sin(th)
            uv('Corn | rounded kernel',(x,y,z+.20),(.105,.090,.095),M['corn2'] if (j+iz)%4==0 else M['corn'],12,8)
    for i in range(4):
        a=2*math.pi*i/4+.3
        leaf('Corn | parted husk',(0,0,.27),(math.cos(a),math.sin(a)),.72,.19,M['husk'] if i%2 else M['leaf'],.46)
    for i in range(3):
        a=2*math.pi*i/3
        leaf('Corn | top silk leaf',(0,0,1.35),(math.cos(a),math.sin(a)),.35,.075,M['leaf2'],.45)
