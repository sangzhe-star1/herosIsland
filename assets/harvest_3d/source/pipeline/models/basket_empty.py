"""Basket empty

Geometry only. Camera, light, palette, shadow and output live in studio.py;
this file is the one place that decides what a basket_empty LOOKS like. Everything
it needs comes in through `S` (the studio) and `P` (the recipe's params).
Moved verbatim from build_pack.py so the render is unchanged.
"""
import math
import random


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    # Open tapered wicker basket with a visible interior, thick lip, woven bands and high handle.
    n=48
    outer=[(.06,.48),(.11,.55),(.57,.76),(.68,.79)]
    inner=[(.68,.65),(.57,.62),(.16,.39),(.11,.36)]
    verts=[]; faces=[]
    rings=outer+inner
    for z,r in rings:
        for j in range(n):
            a=2*math.pi*j/n
            verts.append((r*math.cos(a),r*math.sin(a),z))
    for k in range(len(rings)-1):
        for j in range(n):
            a=k*n+j; b=k*n+(j+1)%n; faces.append((a,b,b+n,a+n))
    wall=mesh('Basket | hollow woven body',verts,faces,M['potato'],True)
    solid=wall.modifiers.new('Woven wall thickness','SOLIDIFY'); solid.thickness=.06
    # A darker inner base makes the empty opening read as a cavity.
    uv('Basket | interior bottom',(0,0,.14),(.40,.40,.045),M['potato'],24,12)
    # Broad, softly rounded horizontal reeds.
    for z,r in ((.18,.57),(.32,.62),(.47,.68),(.62,.75)):
        pts=[(r*math.cos(2*math.pi*j/48),r*math.sin(2*math.pi*j/48),z) for j in range(49)]
        tube('Basket | honey wicker band',pts,.035,M['pumpkin2'],3)
    # Twelve vertical rods follow the taper.
    for j in range(12):
        a=2*math.pi*j/12
        pts=[]
        for z,r in ((.08,.52),(.25,.59),(.46,.69),(.67,.78)):
            pts.append((r*math.cos(a),r*math.sin(a),z))
        tube('Basket | vertical wicker',pts,.026,M['pumpkin2'] if j%2==0 else M['potato2'],2)
    pts=[(.0,-.52,.65),(.0,-.52,1.05),(.0,-.43,1.46),(.0,0,1.63),(.0,.43,1.46),(.0,.52,1.05),(.0,.52,.65)]
    tube('Basket | tall rounded handle',pts,.065,M['potato2'],4)
    # A broad oval rim visually separates the open mouth from the handle.
    rim=[(.73*math.cos(2*math.pi*j/64),.73*math.sin(2*math.pi*j/64),.69) for j in range(65)]
    tube('Basket | thick rolled rim',rim,.060,M['pumpkin2'],4)
