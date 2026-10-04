"""Stone

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a stone LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    # Faceted but rounded field stone, flattened at its ground contact.
    verts=[]; faces=[]; nlat=10; nlon=16; cx,cy,cz=0,0,.37
    random.seed(33)
    for i in range(nlat+1):
        phi=math.pi*i/nlat
        for j in range(nlon):
            th=2*math.pi*j/nlon; f=1+random.uniform(-.09,.09)
            x=.67*math.sin(phi)*math.cos(th)*f
            y=.54*math.sin(phi)*math.sin(th)*f
            z=.43*math.cos(phi)*f
            z=max(-.34,z)
            verts.append((cx+x,cy+y,cz+z))
    for i in range(nlat):
        for j in range(nlon):
            a=i*nlon+j; b=i*nlon+(j+1)%nlon; faces.append((a,b,b+nlon,a+nlon))
    o=mesh('Stone | soft irregular pebble',verts,faces,M['stone'],False)
    bevel=o.modifiers.new('Soft pebble edges','BEVEL'); bevel.width=.045; bevel.segments=2
    uv('Stone | pale facet',( .17,-.32,.63),(.20,.045,.13),M['stone2'],12,8)
