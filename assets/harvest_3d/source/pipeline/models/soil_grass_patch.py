"""Soil grass patch

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a soil_grass_patch LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    # Reusable low rounded patch: softly raised grass lip around exposed warm soil.
    n=64; verts=[]; faces=[]
    loops=[(1.02,.58,.20),(.80,.40,.34),(.98,.56,.07),(0.0,0.0,0.0)]
    for rx,ry,z in loops[:3]:
        for j in range(n):
            a=2*math.pi*j/n
            scallop=1+.012*math.sin(7*a)+.006*math.sin(13*a)
            verts.append((rx*scallop*math.cos(a),ry*scallop*math.sin(a),z+.012*math.sin(5*a)))
    for j in range(n):
        k=(j+1)%n
        faces.append((j,k,n+k,n+j))
        faces.append((2*n+j,2*n+k,k,j))
    grass=mesh('Soil bed | raised grassy lip',verts,faces,M['leaf'],True)
    grass.modifiers.new('Grass lip thickness','SOLIDIFY').thickness=.05
    # Soil disk gently crowns in the center and meets the grass inner edge.
    sv=[]; sf=[]
    for j in range(n):
        a=2*math.pi*j/n; sv.append((.80*math.cos(a),.40*math.sin(a),.34+.012*math.sin(5*a)))
    sv.append((0,0,.43))
    for j in range(n): sf.append((j,(j+1)%n,n))
    mesh('Soil bed | exposed cocoa soil',sv,sf,M['potato'],True)
    soil_light=material('Soil bed | toasted clods',(.45,.245,.105),.92)
    for x,y,z,s in [(-.42,-.16,.38,.075),(.24,-.22,.39,.065),(.49,.13,.36,.055),(-.08,.19,.39,.050)]:
        uv('Soil bed | small soft clod',(x,y,z),(s,s*.75,s*.55),soil_light,12,8)
    for i in range(8):
        a=2*math.pi*i/8
        leaf('Soil bed | tiny grass blade',(.91*math.cos(a),.49*math.sin(a),.16),(math.cos(a),math.sin(a)),.18,.045,M['leaf2'] if i%2 else M['leaf'],.20)
