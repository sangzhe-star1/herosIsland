import bpy, math, random, json, os
from mathutils import Vector
from pathlib import Path

OUT = Path(os.environ.get(
    'HARVEST_SPRITE_PACK_OUT',
    str(Path(__file__).resolve().parent / 'rendered'),
)).expanduser()
SPRITES = OUT / 'sprites'
SPRITES.mkdir(parents=True, exist_ok=True)
random.seed(7319)

# A single clean studio scene; all crop objects are modeled about a ground-level
# origin and share one orthographic camera, light rig, and render treatment.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for d in bpy.data.collections:
    if d.name != 'Collection':
        bpy.data.collections.remove(d)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'AgX'
scene.render.image_settings.color_depth = '8'
scene.world.color = (0.10, 0.10, 0.10)
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.55,0.58,0.60,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.62

def material(name, color, rough=.84):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    nodes=m.node_tree.nodes
    bs=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
    if bs is None: bs=nodes.new('ShaderNodeBsdfPrincipled')
    out=next((n for n in nodes if n.type=='OUTPUT_MATERIAL'),None)
    if out is None: out=nodes.new('ShaderNodeOutputMaterial')
    if not out.inputs['Surface'].is_linked: m.node_tree.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Roughness'].default_value=rough
    return m

M={
 'leaf': material('Leaf | meadow green',(0.12,.34,.07)),
 'leaf2': material('Leaf | sunlit green',(.24,.48,.11)),
 'leafdark': material('Leaf | deep green',(.055,.21,.035)),
 'stem': material('Stem | soft green',(.12,.30,.055)),
 'white': material('Eye | warm white',(.96,.91,.75),.56),
 'black': material('Charcoal | soft',(.055,.045,.035),.82),
 'seed': material('Seed | pale gold',(.94,.73,.30),.75),
 'carrot': material('Carrot | warm orange',(.96,.265,.045)),
 'gold': material('Golden carrot | honey yellow',(1.0,.63,.075)),
 'potato': material('Potato | toasted tan',(.57,.33,.15)),
 'potato2': material('Potato | lighter skin',(.72,.47,.24)),
 'tomato': material('Tomato | ripe red',(.83,.075,.035),.68),
 'tomato2': material('Tomato | warm highlight red',(.96,.16,.065),.68),
 'strawberry': material('Strawberry | ripe berry',(.88,.055,.075),.68),
 'corn': material('Corn | kernel gold',(1.0,.68,.08),.72),
 'corn2': material('Corn | light kernels',(1.0,.82,.25),.75),
 'husk': material('Corn | fresh husk',(.15,.41,.075)),
 'orange': material('Orange | sunny orange',(1.0,.32,.045),.83),
 'orange2': material('Orange | warm dimple',(1.0,.48,.11),.84),
 'apple': material('Apple | ruby red',(.75,.035,.035),.68),
 'apple2': material('Apple | blush side',(.94,.13,.06),.7),
 'peas': material('Peas | fresh green',(.25,.57,.11)),
 'peas2': material('Pea | soft lime',(.45,.72,.18)),
 'pod': material('Pea pod | deep green',(.13,.39,.065)),
 'pumpkin': material('Pumpkin | harvest orange',(1.0,.34,.045)),
 'pumpkin2': material('Pumpkin | soft golden rib',(1.0,.49,.09)),
 'melon': material('Watermelon | rind green',(.08,.30,.095)),
 'melon2': material('Watermelon | pale stripes',(.38,.62,.22)),
 'broccoli': material('Broccoli | florets',(.13,.37,.075)),
 'broccoli2': material('Broccoli | sunny crowns',(.25,.49,.10)),
 'lettuce': material('Lettuce | tender green',(.40,.66,.15)),
 'lettuce2': material('Lettuce | inner leaves',(.62,.78,.28)),
 'grape': material('Grape | plum purple',(.36,.13,.48)),
 'grape2': material('Grape | light purple',(.48,.21,.59)),
 'wheat': material('Wheat | ripe grain',(.90,.61,.16)),
 'wheat2': material('Wheat | pale awn',(1.0,.78,.32)),
 'stone': material('Stone | warm slate',(.39,.45,.47)),
 'stone2': material('Stone | soft highlights',(.54,.59,.59)),
 'bug': material('Ladybug | red shell',(.83,.045,.06),.65),
}

def soft_shadow_material():
    m=bpy.data.materials.new('Studio | soft contact shadow in alpha'); m.use_nodes=True
    n=m.node_tree.nodes; n.clear(); links=m.node_tree.links
    tex=n.new('ShaderNodeTexCoord')
    sub=n.new('ShaderNodeVectorMath'); sub.operation='SUBTRACT'; sub.inputs[1].default_value=(.5,.5,0)
    scale=n.new('ShaderNodeVectorMath'); scale.operation='MULTIPLY'; scale.inputs[1].default_value=(2,2,0)
    length=n.new('ShaderNodeVectorMath'); length.operation='LENGTH'
    ramp=n.new('ShaderNodeValToRGB'); ramp.color_ramp.interpolation='EASE'
    ramp.color_ramp.elements[0].position=0.0; ramp.color_ramp.elements[0].color=(.20,.20,.20,1)
    ramp.color_ramp.elements[1].position=1.0; ramp.color_ramp.elements[1].color=(0,0,0,1)
    e=ramp.color_ramp.elements.new(.36); e.color=(.15,.15,.15,1)
    e=ramp.color_ramp.elements.new(.72); e.color=(.055,.055,.055,1)
    transparent=n.new('ShaderNodeBsdfTransparent')
    ink=n.new('ShaderNodeEmission'); ink.inputs['Color'].default_value=(.12,.095,.065,1); ink.inputs['Strength'].default_value=.8
    mix=n.new('ShaderNodeMixShader'); out=n.new('ShaderNodeOutputMaterial')
    links.new(tex.outputs['UV'],sub.inputs[0]); links.new(sub.outputs['Vector'],scale.inputs[0]); links.new(scale.outputs['Vector'],length.inputs[0])
    links.new(length.outputs['Value'],ramp.inputs['Fac']); links.new(ramp.outputs['Color'],mix.inputs[0])
    links.new(transparent.outputs[0],mix.inputs[1]); links.new(ink.outputs[0],mix.inputs[2]); links.new(mix.outputs[0],out.inputs['Surface'])
    return m

SHADOW_MAT=soft_shadow_material()
SHADOW_SIZE={
 'carrot':(.36,.24),'golden_carrot':(.36,.24),'potato':(.47,.30),'tomato':(.40,.28),'strawberry':(.34,.24),
 'corn':(.40,.27),'orange':(.40,.28),'apple':(.40,.28),'peas':(.48,.24),'pumpkin':(.50,.32),
 'watermelon':(.50,.30),'broccoli':(.45,.30),'lettuce':(.48,.30),'grape':(.40,.27),'wheat':(.43,.26),
 'stone':(.42,.28),'bug':(.38,.25),'basket_empty':(.50,.32),'soil_grass_patch':(.50,.32)
}

def finish(obj, mat=None, smooth=True):
    if mat: obj.data.materials.append(mat)
    if obj.type=='MESH' and smooth:
        for p in obj.data.polygons: p.use_smooth=True
    return obj

def uv(name, loc, scale, mat, seg=24, rings=16, smooth=True):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o,mat,smooth)

def mesh(name, verts, faces, mat, smooth=True):
    me=bpy.data.meshes.new(name+' Mesh'); me.from_pydata(verts,[],faces); me.update()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o)
    return finish(o,mat,smooth)

def tube(name, points, radius, mat, resolution=3):
    cu=bpy.data.curves.new(name+' Curve','CURVE'); cu.dimensions='3D'; cu.resolution_u=16; cu.bevel_depth=radius; cu.bevel_resolution=resolution
    sp=cu.splines.new('BEZIER'); sp.bezier_points.add(len(points)-1)
    for bp,p in zip(sp.bezier_points,points): bp.co=p; bp.handle_left_type='AUTO'; bp.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,cu); bpy.context.collection.objects.link(o); o.data.materials.append(mat); return o

def leaf(name, base, direction, length, width, mat=None, lift=.22, wave=0.0):
    base=Vector(base); d=Vector((direction[0],direction[1],0)).normalized(); side=Vector((-d.y,d.x,0))
    verts=[]; faces=[]; rows=16; across=8
    for i in range(rows+1):
        t=i/rows; env=max(0.0,math.sin(math.pi*t))**.76
        env*=1.0+wave*math.sin(8*math.pi*t)
        center=base+d*(length*t); center.z += length*(lift*t + .10*math.sin(math.pi*t))
        for j in range(across+1):
            u=j/across*2-1
            p=center+side*(width*env*u)
            p.z += width*.22*env*(1-u*u)
            verts.append(tuple(p))
    for i in range(rows):
        for j in range(across):
            a=i*(across+1)+j; faces.append((a,a+1,a+across+2,a+across+1))
    o=mesh(name,verts,faces,mat or M['leaf'],True)
    sol=o.modifiers.new('Soft leaf thickness','SOLIDIFY'); sol.thickness=.018
    return o

def fruit_mesh(name, center, scale, mat, lobes=0, indent=.0, apple_shape=False):
    # Smooth hand-made radial fruit form with subtle top/bottom dimples and shoulders.
    cx,cy,cz=center; sx,sy,sz=scale; nlat=28; nlon=48; verts=[]; faces=[]
    for i in range(nlat+1):
        phi=math.pi*i/nlat; s=math.sin(phi); c=math.cos(phi)
        for j in range(nlon):
            th=2*math.pi*j/nlon
            ripple=1.0+(0.035*math.cos(lobes*th+0.2)*s**2 if lobes else 0)
            if apple_shape: ripple *= 1.0+0.075*math.cos(2*phi)*s
            r=s*ripple
            x=cx+sx*r*math.cos(th); y=cy+sy*r*math.sin(th)
            z=cz+sz*c
            if indent:
                top=max(0.0,c)**8; bottom=max(0.0,-c)**10
                z -= indent*top; z += indent*.28*bottom
            verts.append((x,y,z))
    for i in range(nlat):
        for j in range(nlon):
            a=i*nlon+j; b=i*nlon+(j+1)%nlon; faces.append((a,b,b+nlon,a+nlon))
    return mesh(name,verts,faces,mat,True)

def lathe(name, center, profile, mat, segments=32, wave=0.018):
    cx,cy,cz=center; verts=[]; faces=[]
    for k,(z,r) in enumerate(profile):
        for j in range(segments):
            th=2*math.pi*j/segments
            rr=r*(1+wave*math.sin(5*th+0.4)*math.sin(math.pi*k/max(1,len(profile)-1)))
            verts.append((cx+rr*math.cos(th),cy+rr*math.sin(th),cz+z))
    for k in range(len(profile)-1):
        for j in range(segments):
            a=k*segments+j; b=k*segments+(j+1)%segments; faces.append((a,b,b+segments,a+segments))
    faces.extend([tuple(range(segments-1,-1,-1)),tuple((len(profile)-1)*segments+j for j in range(segments))])
    return mesh(name,verts,faces,mat,True)

def asset_collection(asset_id, build):
    coll=bpy.data.collections.new('ASSET | '+asset_id); scene.collection.children.link(coll)
    before=set(bpy.data.objects); build(); made=set(bpy.data.objects)-before
    # A compact radial shadow stays under the pivot and fades cleanly into PNG alpha.
    verts=[(-1,-1,0),(1,-1,0),(1,1,0),(-1,1,0)]
    o=mesh('Shadow | '+asset_id,verts,[(0,1,2,3)],SHADOW_MAT,False)
    uv=o.data.uv_layers.new(name='Shadow radial UV')
    uvmap={0:(0,0),1:(1,0),2:(1,1),3:(0,1)}
    for poly in o.data.polygons:
        for li in poly.loop_indices: uv.data[li].uv=uvmap[o.data.loops[li].vertex_index]
    sx,sy=SHADOW_SIZE[asset_id]; o.scale=(sx,sy,1); o.location=(0,.08,.012)
    made.add(o)
    for o in made:
        for c in list(o.users_collection): c.objects.unlink(o)
        coll.objects.link(o)
    return coll

def make_carrot(golden=False):
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

def make_potato():
    # A small cluster gives the digging root crop a distinct lumpy silhouette.
    uv('Potato | main tuber',(0,0,.40),(.61,.49,.39),M['potato'],28,18)
    uv('Potato | side tuber',(.36,.10,.30),(.39,.35,.29),M['potato2'],22,14)
    uv('Potato | rear tuber',(-.31,.20,.26),(.35,.32,.25),M['potato'],20,14)
    # A few shallow eyes on camera-facing surfaces.
    for x,y,z in [(-.31,-.44,.48),(.14,-.47,.61),(.40,-.23,.35),(-.12,-.43,.28)]:
        uv('Potato | tiny eye', (x,y,z),(.055,.025,.040),M['potato2'],12,8)

def make_tomato():
    fruit_mesh('Tomato | gently lobed ripe fruit',(0,0,.61),(.58,.54,.55),M['tomato'],5,.045)
    uv('Tomato | calyx center',(0,0,1.12),(.12,.12,.06),M['leafdark'],16,10)
    for i in range(6):
        a=2*math.pi*i/6
        leaf('Tomato | pointed calyx',(0,0,1.10),(math.cos(a),math.sin(a)),.29,.085,M['leaf2'] if i%2 else M['leaf'],.20)
    tube('Tomato | short stem',[(0,0,1.10),(0,0,1.20),(0.03,0,1.27)],.035,M['stem'])

def make_strawberry():
    # Rounded, tapered berry with a broad shoulder and softly pointed tip.
    lathe('Strawberry | heart-shaped berry',(0,0,0),[(.035,.045),(.11,.15),(.26,.29),(.43,.40),(.62,.43),(.78,.36),(.90,.22),(.94,.08)],M['strawberry'],40,.025)
    for i in range(7):
        a=2*math.pi*i/7
        leaf('Strawberry | green crown',(0,0,.90),(math.cos(a),math.sin(a)),.34,.135,M['leaf'] if i%2 else M['leaf2'],.42)
    # Pale seeds set on the visible front curve.
    for row,(z,rad,count) in enumerate(((.19,.22,5),(.38,.34,6),(.59,.36,6),(.76,.25,4))):
        for j in range(count):
            x=rad*math.cos(2*math.pi*j/count+row*.34)
            yy=-rad*math.sqrt(max(.035,1-(x/rad)**2))-.012
            uv('Strawberry | seed', (x,yy,z),(.027,.016,.043),M['seed'],10,6)

def make_corn():
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

def make_orange():
    fruit_mesh('Orange | round fruit',(0,0,.60),(.62,.60,.57),M['orange'],.0,.035)
    uv('Orange | stem dimple',(0,0,1.16),(.105,.105,.035),M['orange2'],16,8)
    uv('Orange | small green stem',(0,0,1.20),(.065,.065,.08),M['stem'],12,8)
    leaf('Orange | small leaf',(0,0,1.20),(1,.25),.36,.13,M['leaf2'],.27)
    # Sparse shallow peel dimples, kept broad and low contrast.
    for x,y,z in [(-.30,-.47,.55),(.14,-.56,.72),(.39,-.38,.44),(-.08,-.56,.32)]:
        uv('Orange | subtle peel dot',(x,y,z),(.022,.016,.022),M['orange2'],8,6)

def make_apple():
    fruit_mesh('Apple | rounded ruby apple',(0,0,.66),(.59,.56,.61),M['apple'],5,.07,True)
    tube('Apple | brown stem',[(0,0,1.19),(0,0,1.32),(.04,.01,1.43)],.060,M['potato'])
    leaf('Apple | fresh leaf',(.025,0,1.29),(1,.25),.43,.16,M['leaf2'],.34)

def make_peas():
    # Curved closed pod with three plump peas visible along the front opening seam.
    uv('Pea pod | curved shell',(0,0,.54),(.88,.36,.27),M['pod'],32,18)
    for i,x in enumerate((-.43,0,.43)):
        z=.73 + (.06 if i==1 else 0)
        uv('Pea | round pea',(x,-.025,z),(.23,.25,.22),M['peas2'] if i==1 else M['peas'],20,14)
    tube('Pea pod | seam',[(-.78,-.13,.66),(-.4,-.19,.75),(0,-.20,.79),(.4,-.19,.75),(.78,-.13,.66)],.027,M['leaf2'])
    leaf('Pea pod | tip leaf',(-.76,0,.58),(-1,-.25),.27,.09,M['leaf2'],.16)
    leaf('Pea pod | tip leaf',( .76,0,.58),(1,.25),.27,.09,M['leaf2'],.16)

def make_pumpkin():
    fruit_mesh('Pumpkin | squat ribbed squash',(0,0,.64),(.96,.88,.63),M['pumpkin'],9,.07)
    # Gentle pale ribs ride just above the orange lobes.
    for k in range(9):
        a=2*math.pi*k/9
        pts=[]
        for i in range(9):
            t=-1+2*i/8; rr=math.sqrt(max(.02,1-t*t))
            pts.append((.985*rr*math.cos(a),.90*rr*math.sin(a),.64+.645*t))
        tube('Pumpkin | soft rib',pts,.018,M['pumpkin2'],2)
    tube('Pumpkin | sturdy green stem',[(0,0,1.18),(0,0,1.32),(.03,0,1.42),(.10,0,1.45)],.095,M['stem'])

def make_watermelon():
    # Oval melon sits on its rind; pale longitudinal stripes track the curved skin.
    cx,cy,cz=0,0,.55; rx,ry,rz=.98,.65,.52
    uv('Watermelon | oval fruit',(cx,cy,cz),(rx,ry,rz),M['melon'],36,24)
    for k in range(7):
        th=2*math.pi*k/7
        pts=[]
        for i in range(13):
            u=-.94+1.88*i/12; f=math.sqrt(max(.01,1-u*u))
            pts.append((rx*u, ry*f*math.sin(th)*1.012, cz+rz*f*math.cos(th)*1.012))
        tube('Watermelon | pale rind stripe',pts,.023,M['melon2'],2)

def make_broccoli():
    tube('Broccoli | thick edible stem',[(0,0,.06),(0,0,.38),(.02,0,.78)],.16,M['lettuce2'])
    uv('Broccoli | stem cap',(0,0,.69),(.36,.34,.27),M['lettuce2'],20,12)
    positions=[(-.40,0,1.18),(-.20,-.18,1.35),(.12,-.26,1.35),(.40,-.08,1.19),(.29,.20,1.20),(-.12,.23,1.27),(-.43,-.28,1.03),(.02,.02,1.52)]
    for i,p in enumerate(positions):
        uv('Broccoli | rounded crown floret',p,(.30,.28,.30),M['broccoli2'] if i%3==0 else M['broccoli'],20,14)
        # One or two smaller bumps enrich each floret without noisy detail.
        for j in range(3):
            a=2*math.pi*j/3
            uv('Broccoli | crown bump',(p[0]+.14*math.cos(a),p[1]+.14*math.sin(a),p[2]+.18),(.105,.10,.10),M['broccoli2'] if j==0 else M['broccoli'],12,8)

def make_lettuce():
    for i in range(9):
        a=2*math.pi*i/9
        leaf('Lettuce | broad ruffled outer leaf',(0,0,.23),(math.cos(a),math.sin(a)),.78,.29,M['lettuce'] if i%3 else M['lettuce2'],.34,.10)
    for i in range(6):
        a=2*math.pi*i/6+.2
        leaf('Lettuce | inner cup leaf',(0,0,.46),(math.cos(a),math.sin(a)),.46,.23,M['lettuce2'] if i%2 else M['lettuce'],.60,.055)
    uv('Lettuce | heart',(0,0,.77),(.20,.19,.22),M['lettuce2'],16,10)

def make_grapes():
    # Downward bunch with individual rounded grapes so its berry silhouette reads quickly.
    centers=[(0,0,1.32),(-.30,-.02,1.14),(0,-.05,1.15),(.30,-.02,1.14),(-.43,0,.83),(-.15,-.08,.85),(.16,-.08,.85),(.43,0,.83),(-.28,-.04,.54),(0,-.10,.55),(.28,-.04,.54),(0,0,.25)]
    for i,p in enumerate(centers):
        r=.23 if i<8 else .22
        uv('Grape | round purple berry',p,(r,r*.91,r),M['grape2'] if i%4==0 else M['grape'],20,14)
    tube('Grapes | cluster stem',[(0,0,1.48),(0,0,1.70),(.05,0,1.84)],.045,M['stem'])
    leaf('Grapes | canopy leaf',(.02,0,1.53),(1,.24),.49,.19,M['leaf2'],.20,.03)

def make_wheat():
    for stalk_i,x in enumerate((-.35,0,.34)):
        y=(stalk_i-1)*.10; height=1.75+(.18 if stalk_i==1 else 0)
        tube('Wheat | slender stalk',[(x,y,.05),(x+.02,y,height*.40),(x-.015,y,height*.73),(x,y,height)],.027,M['stem'],2)
        leaf('Wheat | narrow blade',(x,y,.48),(1 if stalk_i%2 else -1,.25),.52,.075,M['leaf'],.45)
        leaf('Wheat | narrow blade',(x,y,.80),(-1 if stalk_i%2 else 1,-.18),.45,.065,M['leaf2'],.38)
        # A compact ear with paired, tapered seed grains and a few fine awns.
        uv('Wheat | central ear',(x,y,height-.10),(.14,.15,.30),M['wheat'],14,10)
        for j in range(6):
            z=height-.32+j*.095
            for side in (-1,1):
                uv('Wheat | plump grain',(x+side*(.12-.010*j),y-.025,z),(.105,.09,.13),M['wheat2'] if j%2 else M['wheat'],12,8)
                tube('Wheat | fine awn',[(x+side*.10,y,z+.015),(x+side*.22,y,z+.17)],.014,M['wheat2'],1)

def make_stone():
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

def make_bug():
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

def make_empty_basket():
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

def make_soil_grass_patch():
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

builders={'carrot':lambda:make_carrot(False), 'golden_carrot':lambda:make_carrot(True)}
collections={k:asset_collection(k,v) for k,v in builders.items()}
extras={}

# Soft directional studio lighting; the short radial shadow mesh is composited into alpha.
studio=bpy.data.collections.new('STUDIO | shared render rig'); scene.collection.children.link(studio)
def put_studio(o):
    for c in list(o.users_collection): c.objects.unlink(o)
    studio.objects.link(o); return o
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.012)); plane=put_studio(bpy.context.object); plane.name='Studio | disabled background plane'; plane.hide_render=True
ld=bpy.data.lights.new('Studio | large warm softbox','AREA'); lo=bpy.data.objects.new('Studio | large warm softbox',ld); studio.objects.link(lo); lo.location=(-3.0,-4.0,12.0); ld.energy=1000; ld.shape='DISK'; ld.size=7.0
target=Vector((0,0,1.55)); lo.rotation_euler=(target-Vector(lo.location)).to_track_quat('-Z','Y').to_euler()
camd=bpy.data.cameras.new('Studio | fixed 3-4 orthographic'); cam=bpy.data.objects.new('Studio | fixed 3-4 orthographic',camd); studio.objects.link(cam)
cam.location=(4.3,-7.2,6.73); target=Vector((0,0,1.28)); cam.rotation_euler=(target-Vector(cam.location)).to_track_quat('-Z','Y').to_euler(); camd.type='ORTHO'; camd.ortho_scale=2.60; camd.lens=50; scene.camera=cam
scene.cycles.transparent_max_bounces=8
bpy.context.view_layer.update()
pivot_cam=cam.matrix_world.inverted() @ Vector((0,0,0))
pivot_px=[round((pivot_cam.x/camd.ortho_scale+.5)*scene.render.resolution_x),
          round((.5-pivot_cam.y/camd.ortho_scale)*scene.render.resolution_y)]
scene.render.filepath=str(SPRITES/'carrot.png')

manifest=[]
for asset_id,coll in collections.items():
    for other in collections.values(): other.hide_render=(other!=coll)
    scene.render.filepath=str(SPRITES/(asset_id+'.png'))
    bpy.ops.render.render(write_still=True)
    manifest.append({'id':asset_id,'file':'sprites/'+asset_id+'.png','resolution':[512,512],
                     'origin':'ground center at z=0; all assets share the same Blender world scale and camera',
                     'ground_pivot_pixel':pivot_px,'pivot_offset_from_texture_center_px':[pivot_px[0]-256,pivot_px[1]-256],
                     'camera':'fixed 3/4 orthographic','style':'rounded matte toy'})
    print('RENDERED',asset_id,flush=True)
for coll in collections.values(): coll.hide_render=True
for asset_id,coll in extras.items():
    coll.hide_render=False
    scene.render.filepath=str(SPRITES/(asset_id+'.png'))
    bpy.ops.render.render(write_still=True)
    manifest.append({'id':asset_id,'file':'sprites/'+asset_id+'.png','resolution':[512,512],
                     'origin':'ground center at z=0; same Blender world scale and studio camera',
                     'ground_pivot_pixel':pivot_px,'pivot_offset_from_texture_center_px':[pivot_px[0]-256,pivot_px[1]-256],
                     'camera':'fixed 3/4 orthographic','style':'rounded matte toy','kind':'supporting environment prop'})
    coll.hide_render=True
    print('RENDERED',asset_id,flush=True)
for coll in list(collections.values())+list(extras.values()): coll.hide_render=False
scene.render.filepath=str(OUT/'')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'harvest_sprite_pack.blend'))
(OUT/'manifest.json').write_text(json.dumps({
    'version':1,'sprite_size':512,'assets':manifest,
    'render':{'engine':'Blender Cycles','resolution':[512,512],'transparent':True,
              'camera':'fixed 3/4 orthographic','ortho_scale':2.60,
              'ground_pivot_pixel':pivot_px,
              'pivot_offset_from_texture_center_px':[pivot_px[0]-256,pivot_px[1]-256],
              'contact_shadow':'short radial alpha mesh; no scene background plane'}
},indent=2)+'\n')
print('SAVED',OUT/'harvest_sprite_pack.blend',flush=True)

# Export one reusable GLB per asset, without the sprite-only alpha contact mesh.
for asset_id, coll in collections.items():
    bpy.ops.object.select_all(action='DESELECT')
    dg=bpy.context.evaluated_depsgraph_get()
    export_objects=[]
    root=bpy.data.objects.new(asset_id+' | ground pivot',None)
    scene.collection.objects.link(root)
    root['asset_id']=asset_id; root['ground_pivot_pixel']=[256,467]
    export_objects.append(root)
    for obj in list(coll.objects):
        if obj.name.startswith('Shadow |') or obj.type not in {'MESH','CURVE'}: continue
        me=bpy.data.meshes.new_from_object(obj.evaluated_get(dg),depsgraph=dg)
        ex=bpy.data.objects.new(obj.name+' | export',me)
        scene.collection.objects.link(ex); ex.matrix_world=obj.matrix_world.copy(); ex.parent=root
        export_objects.append(ex)
    for obj in export_objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT/(asset_id+'.glb')),export_format='GLB',use_selection=True,export_materials='EXPORT',export_extras=True)
    for obj in export_objects: bpy.data.objects.remove(obj,do_unlink=True)
    print('EXPORTED',asset_id,flush=True)
