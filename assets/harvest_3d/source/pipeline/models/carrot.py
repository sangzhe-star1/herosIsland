"""Carrot (long root)

The carrot the game ships: carrot_shape_candidate/build_carrots.py's
make_carrot, which replaced the stubby sprite-pack carrot because the long
crown-to-tip body still reads as a carrot at the dense level's 72 px. Moved
verbatim; the golden carrot is the same shape with the golden palette.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    golden = bool(P.get("golden", False))
    # Long crown-to-tip body reads as carrot at the dense level's 72px scale.
    label='Golden carrot' if golden else 'Carrot'
    color=material(label+' | vivid matte orange',(1.0,.61,.05) if golden else (1.0,.22,.007),.79)
    ridge=material(label+' | shallow root marking',(.82,.245,.008) if golden else (.74,.082,.002),.91)
    root=lathe(label+' | long softly tapered root',(0,0,0),[
      (0.0,.008),(.085,.025),(.22,.050),(.42,.081),(.65,.115),
      (.89,.15),(1.12,.18),(1.32,.215),(1.44,.218),(1.51,.16),
      (1.55,.080),(1.556,.035)],color,48,.016)
    # Subtle hand-grown center line; the contact tip remains exactly at world 0.
    for v in root.data.vertices:
        t=v.co.z/1.556
        v.co.x += -.07*math.sin(math.pi*t)**1.2
    # Three shallow growth creases sit on the camera-facing root, not rings.
    for iz,(z,r) in enumerate(((.61,.109),(.93,.155),(1.24,.199))):
        a0=-1.36; pts=[]
        for j in range(9):
            a=a0+(-.25+.50*j/8)
            pts.append((r*math.cos(a)-.07*math.sin(math.pi*z/1.556)**1.2,
                        r*math.sin(a)-.002,z+.015*math.sin(math.pi*j/8)))
        tube(label+' | gentle short root crease '+str(iz),pts,.0055,ridge,2)
    # Chunky leaf crown, with a clear upward fan instead of a generic fruit calyx.
    crown_z=1.545
    for i,(a,length,width,lift) in enumerate((
      (-.52,.40,.080,1.06),(.42,.47,.087,1.15),
      (1.76,.43,.085,1.20),(2.90,.43,.080,1.12),
      (4.05,.34,.085,.92))):
        leaf(label+' | carrot crown leaf '+str(i),(0,0,crown_z),
             (math.cos(a),math.sin(a)),length,width,
             M['leaf2'] if i%2 else M['leaf'],lift,.08)
    tube(label+' | crown stems',[(0,0,1.51),(0,0,1.62),(.018,.015,1.72)],.027,M['stem'])
