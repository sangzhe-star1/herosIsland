import bpy, math, random, os
from mathutils import Vector
from math import sin, cos, pi

OUT='/private/tmp/heroes-island-toy-farm-parallel-v27'
random.seed(72)
bpy.ops.wm.read_factory_settings(use_empty=True)

# A restrained, matte toy-farm palette.
def mat(name, color, rough=.82):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough
    return m
soil=mat('Soil | warm loam',(0.29,.145,.067),.94)
leaf=mat('Leaf | garden green',(.16,.39,.095),.88)
vine=mat('Vine | deep green',(.10,.245,.055),.9)
red=mat('Tomato | ripe red',(.78,.025,.018),.76)
red_dark=mat('Tomato | shoulder red',(.43,.012,.012),.82)
calyx_mat=mat('Calyx | fresh green',(.19,.40,.075),.9)
straw=mat('Basket | honey straw',(.62,.335,.12),.86)
straw_light=mat('Basket | sunlit weave',(.78,.49,.22),.86)
straw_dark=mat('Basket | shadow weave',(.38,.19,.065),.9)

class Builder:
    def __init__(self): self.v=[]; self.f=[]; self.mi=[]; self.mats=[]
    def mindex(self,m):
        if m not in self.mats: self.mats.append(m)
        return self.mats.index(m)
    def face(self,ids,m): self.f.append(tuple(ids)); self.mi.append(self.mindex(m))
    def mesh(self,name,parent=None,location=(0,0,0),smooth=False):
        me=bpy.data.meshes.new(name+' Mesh'); me.from_pydata(self.v,[],self.f); me.update()
        ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
        ob.location=location
        if parent: ob.parent=parent
        for m in self.mats: me.materials.append(m)
        for p,i in zip(me.polygons,self.mi): p.material_index=i; p.use_smooth=smooth
        return ob
    def tube(self, pts, radii, material, sides=7):
        pts=[Vector(p) for p in pts]
        base=len(self.v)
        for i,p in enumerate(pts):
            tangent=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()
            ref=Vector((0,0,1)) if abs(tangent.z)<.91 else Vector((1,0,0))
            a=tangent.cross(ref).normalized(); b=tangent.cross(a).normalized()
            radius=radii[i] if hasattr(radii,'__len__') else radii
            for j in range(sides):
                q=p+radius*(cos(2*pi*j/sides)*a+sin(2*pi*j/sides)*b)
                self.v.append(tuple(q))
        for i in range(len(pts)-1):
            for j in range(sides): self.face((base+i*sides+j,base+i*sides+(j+1)%sides,base+(i+1)*sides+(j+1)%sides,base+(i+1)*sides+j),material)
        self.face(tuple(base+j for j in reversed(range(sides))),material)
        self.face(tuple(base+(len(pts)-1)*sides+j for j in range(sides)),material)
    def leaflet(self, base, axis, across, length, width, material=leaf, segs=9, bend=.035):
        base=Vector(base); axis=Vector(axis).normalized(); across=Vector(across).normalized()
        normal=axis.cross(across).normalized()
        start=len(self.v)
        for i in range(segs+1):
            t=i/segs
            base_env=min(1.0,t/.14)
            tip_env=max(0.0,min(1.0,(1.0-t)/.16))**.65
            env=base_env*(.74+.26*sin(pi*t))*tip_env
            serr=1+.035*cos(8*pi*t)
            w=width*env*serr
            c=base+axis*(length*t)+normal*(bend*sin(pi*t))
            self.v.extend([tuple(c-across*w),tuple(c+normal*(.018*sin(pi*t))),tuple(c+across*w)])
        for i in range(segs):
            a=start+i*3; b=a+3
            self.face((a,b,b+1,a+1),material); self.face((a+1,b+1,b+2,a+2),material)


def root(name, parent, loc=(0,0,0)):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.parent=parent; o.location=loc; o.empty_display_type='PLAIN_AXES'; o.empty_display_size=.16; return o

def ellipse_ring(builder, rx, ry, z, n=48, phase=0, irregular=0, material=soil):
    ids=[]
    for i in range(n):
        a=2*pi*i/n+phase; r=1+irregular*(.55*sin(5*a+.2)+.28*sin(9*a+1.1)+.17*sin(13*a-.5))
        ids.append(len(builder.v)); z_wobble=(.012*sin(5*a+.2)+.006*sin(9*a+1.1))*min(1.0,rx/2.58); builder.v.append((rx*r*cos(a),ry*r*sin(a),z+z_wobble))
    return ids

# Hierarchy root, organic mound and low, leafy perimeter.
scene_root=bpy.data.objects.new('Root',None); bpy.context.collection.objects.link(scene_root); scene_root.empty_display_type='CIRCLE'; scene_root.empty_display_size=.35
bed=root('GardenBed',scene_root)
m=Builder(); outer=ellipse_ring(m,2.58,1.35,.18,64,irregular=.04); side_mid=ellipse_ring(m,2.53,1.32,.09,64,irregular=.04); lower=ellipse_ring(m,2.38,1.24,.025,64,irregular=.04)
# Build an irregular domed surface as nested rings.
rings=[]
for ri in range(1,13):
    t=ri/12; z=.18+.54*(1-t**1.40)
    rings.append(ellipse_ring(m,2.58*t,1.35*t,z,64,irregular=.035))
center=len(m.v); m.v.append((0,0,.72))
for j in range(64): m.face((center,rings[0][j],rings[0][(j+1)%64]),soil)
for k in range(len(rings)-1):
    a,b=rings[k],rings[k+1]
    for j in range(64): m.face((a[j],b[j],b[(j+1)%64],a[(j+1)%64]),soil)
for j in range(64):
    m.face((lower[j],side_mid[j],side_mid[(j+1)%64],lower[(j+1)%64]),soil)
    m.face((side_mid[j],outer[j],outer[(j+1)%64],side_mid[(j+1)%64]),soil)
m.mesh('Mound | irregular domed loam',bed,smooth=True)
# Subtle low green fringe: overlapping compound sprays with varied heights and directions.
f=Builder()
for k in range(64):
    a=2*pi*k/64+random.uniform(-.055,.055); rr=1+random.uniform(-.035,.04)
    origin=Vector((2.49*rr*cos(a),1.28*rr*sin(a),.16+random.uniform(-.015,.035)))
    radial=Vector((cos(a),sin(a),0)); tangent=Vector((-sin(a),cos(a),0))
    for j in range(3):
        d=(radial*random.uniform(.28,.62)+tangent*random.uniform(-.68,.68)+Vector((0,0,random.uniform(.10,.36)))).normalized()
        side=d.cross(Vector((0,0,1)))
        if side.length<.01: side=Vector((1,0,0))
        f.leaflet(origin+Vector((0,0,j*.012)),d,side,.32+random.uniform(-.06,.10),.105+random.uniform(-.012,.022),segs=8,bend=.025)
f.mesh('Fringe | loose green leaf clusters',bed,smooth=True)

# Each plant has curved branching stems and compound serrated leaf fans, plus four low-poly harvest targets.
plant_positions=[(-1.42,-.22,0),(-.02,-.34,0),(1.34,-.18,0)]
for pi_idx,loc in enumerate(plant_positions,1):
    plant=root(f'Plant{pi_idx:02d}',scene_root,loc)
    plant.rotation_euler[2]=(-.25,.14,.34)[pi_idx-1]
    sb=Builder(); lb=Builder()
    # Main stem rises from the mound with a gentle S bend.
    xoff=random.uniform(-.10,.10); yoff=random.uniform(-.08,.08)
    main=[(xoff,yoff,.35),(xoff-.08,yoff+.02,.67),(xoff+.09,yoff+.04,.98),(xoff+.02,yoff+.02,1.31),(xoff-.10,yoff-.04,1.62),(xoff-.04,yoff-.06,1.92)]
    sb.tube(main,[.042,.038,.033,.028,.021,.014],vine,8)
    branch_data=[]
    for bi,zbase in enumerate([.70,1.02,1.34,1.60]):
        side=(-1 if (bi+pi_idx)%2 else 1)
        x0=xoff+(-.02 if bi<2 else .02); y0=yoff
        direction=side*(.48+random.random()*.16)
        end=(x0+direction,y0+random.uniform(-.1,.1),zbase+random.uniform(.08,.27))
        mid=(x0+direction*.55,y0+random.uniform(-.05,.06),zbase+random.uniform(.04,.15))
        pts=[(x0,y0,zbase),(x0+direction*.28,y0,zbase+.08),mid,(end[0],end[1],end[2]-.07),end]
        sb.tube(pts,[.027,.023,.019,.014,.009],vine,7)
        branch_data.append((Vector(end),Vector((direction,0,.25)).normalized()))
    # Additional inward-facing forks break the silhouette and fill gaps.
    for bi,(zbase,side) in enumerate([(0.91,-1),(1.24,1),(1.47,-1)]):
        start=(xoff,yoff,zbase); end=(xoff+side*.43,yoff+.17,zbase+.22)
        sb.tube([start,(xoff+side*.18,yoff+.04,zbase+.11),end],[.022,.015,.008],vine,7)
        branch_data.append((Vector(end),Vector((side*.55,.42,.52)).normalized()))
    sb.mesh(f'Plant{pi_idx:02d} | curved stems',plant,smooth=True)
    # Place fruit early so foliage can leave a clear visual and touch-sized pocket around each tomato.
    fruits=[(-.38,-.25,.91),(.38,-.11,1.18),(-.36,.21,1.47),(.39,.16,1.67)]
    fruit_positions=[]
    for fx,fy,fz in fruits:
        fruit_positions.append((fx+random.uniform(-.045,.045),fy+random.uniform(-.035,.035),fz+random.uniform(-.035,.035)))
    fruit_vectors=[Vector(p) for p in fruit_positions]
    def leaf_crosses_fruit(start,end):
        delta=end-start; denom=max(1e-8,delta.length_squared)
        for fruit_center in fruit_vectors:
            u=max(0.0,min(1.0,(fruit_center-start).dot(delta)/denom))
            if (fruit_center-(start+delta*u)).length < .31:
                return True
        return False
    # Leaves distributed along stem and branches. Each compound leaf has two opposed leaflet pairs and a rounded terminal blade.
    anchors=[]
    for h in [.51,.70,.91,1.12,1.34,1.57,1.78]:
        frac=(h-.35)/(1.92-.35); idx=min(4,int(frac*5)); q=frac*5-idx
        p0=Vector(main[min(idx,4)]); p1=Vector(main[min(idx+1,5)]); pos=p0.lerp(p1,q)
        angle=(pi_idx*1.3+h*2.6)
        d=Vector((cos(angle)*.84,sin(angle)*.84,random.uniform(.20,.48))).normalized()
        anchors.append((pos,d,.58+random.random()*.16))
    for end,d in branch_data:
        anchors.append((end-d*.10,d,.42+random.random()*.12))
    for ai,(origin,direction,length) in enumerate(anchors):
        side=direction.cross(Vector((0,0,1)))
        if side.length<.01: side=Vector((1,0,0))
        side.normalize()
        # Slightly varying orientation keeps leaves from forming flat fans.
        if ai%2: side=-side
        rachis=[origin+direction*(length*t) for t in [0,.25,.5,.75,1]]
        lb.tube(rachis,[.012,.011,.009,.007,.0035],vine,5)
        for pair in range(2):
            t=.27+pair*.31; p=origin+direction*(length*t)
            ll=length*(.49-.09*pair)
            for sign in [-1,1]:
                ax=(direction*.36+side*sign*.94+Vector((0,0,random.uniform(-.16,.18)))).normalized()
                across=direction.cross(ax)
                if across.length<.01: across=side
                if not leaf_crosses_fruit(p,p+ax*ll):
                    lb.leaflet(p,ax,across,ll,.132-(pair*.012),segs=9,bend=.045)
        tip=origin+direction*length
        ax=(direction+side*random.uniform(-.16,.16)).normalized(); across=direction.cross(ax)
        if across.length<.01: across=side
        if not leaf_crosses_fruit(tip,tip+ax*length*.46):
            lb.leaflet(tip,ax,across,length*.46,.155,segs=10,bend=.055)
    lb.mesh(f'Plant{pi_idx:02d} | compound serrated leaves',plant,smooth=True)
    # 4 separate ripe targets per plant; each is centered at its pivot and comfortably below 600 triangles.
    for fi,(fx,fy,fz) in enumerate(fruit_positions,1):
        fb=Builder()
        # Low-poly rounded tomato, 16x9 UV-like rings, with softly lobed shoulders.
        seg=16; nr=9; rings=[]
        for ri in range(nr+1):
            lat=-pi/2+pi*ri/(nr+1); z=.205*sin(lat)
            rr=cos(lat)
            row=[]
            for j in range(seg):
                a=2*pi*j/seg
                lobe=1+.035*cos(5*a+0.4)*max(0,sin(lat))
                row.append(len(fb.v)); fb.v.append((.205*rr*lobe*cos(a),.198*rr*lobe*sin(a),z))
            rings.append(row)
        bottom=len(fb.v); fb.v.append((0,0,-.205)); top=len(fb.v); fb.v.append((0,0,.205))
        for j in range(seg): fb.face((bottom,rings[0][(j+1)%seg],rings[0][j]),red)
        for r in range(nr):
            for j in range(seg): fb.face((rings[r][j],rings[r][(j+1)%seg],rings[r+1][(j+1)%seg],rings[r+1][j]),red if r<nr-2 else red_dark)
        for j in range(seg): fb.face((top,rings[-1][j],rings[-1][(j+1)%seg]),red_dark)
        # Green star-shaped calyx and short stem are in this named harvest mesh.
        for k in range(5):
            a=2*pi*k/5
            base=Vector((.055*cos(a),.055*sin(a),.175)); tip=Vector((.142*cos(a),.142*sin(a),.145))
            mid=Vector((.094*cos(a),.094*sin(a),.19)); n=len(fb.v); fb.v.extend([tuple(base),tuple(mid),tuple(tip)])
            fb.face((n,n+1,n+2),calyx_mat)
        fb.tube([(0,0,.16),(0,0,.22),(0.012,-.006,.27)],[.024,.018,.012],vine,6)
        fb.mesh(f'HarvestTarget Tomato P{pi_idx:02d} F{fi:02d}',plant,location=(fx,fy,fz),smooth=True)

# Open oval woven basket with a thick rim and arched handle; all static under the Basket group.
basket=root('Basket',scene_root,(1.93,-1.43,0)); basket.scale=(1.05,1.05,1.05)
bb=Builder(); seg=40; wallrings=[]
for ri in range(9):
    t=ri/8; z=.08+.64*t; rx=.37+.20*t; ry=.29+.15*t
    row=[]
    for j in range(seg):
        a=2*pi*j/seg; wave=1+.018*sin(7*a+.5)
        row.append(len(bb.v)); bb.v.append((rx*wave*cos(a),ry*wave*sin(a),z))
    wallrings.append(row)
# Bowl outer/inner wall, open at top.
for ri in range(8):
    for j in range(seg): bb.face((wallrings[ri][j],wallrings[ri][(j+1)%seg],wallrings[ri+1][(j+1)%seg],wallrings[ri+1][j]),straw)
# bottom inset closes the very base only.
base_center=len(bb.v); bb.v.append((0,0,.075))
for j in range(seg): bb.face((base_center,wallrings[0][j],wallrings[0][(j+1)%seg]),straw_dark)
bb.mesh('Basket | open tapered bowl',basket,smooth=True)
# Seven wavy continuous weave bands; alternating light/dark gives a chunky woven read at modest cost.
for band in range(7):
    wb=Builder(); z=.16+band*.078; pts=[]; radii=[]
    for j in range(97):
        a=2*pi*j/96; t=(z-.08)/.64; rx=.37+.20*t; ry=.29+.15*t
        wave=.026*sin(12*a+band*pi*.82)
        pts.append(((rx+wave)*cos(a),(ry+wave)*sin(a),z+.012*sin(12*a+band*pi*.82)))
        radii.append(.026 if band in (0,6) else .019)
    wb.tube(pts,radii,straw_light if band%2==0 else straw_dark,5)
    wb.mesh(f'Basket | woven course {band+1:02d}',basket,smooth=True)
# Upright ribs woven through courses.
rb=Builder()
for j in range(14):
    a=2*pi*j/14; points=[]
    for k in range(9):
        t=k/8; z=.11+.63*t; rx=.37+.20*t; ry=.29+.15*t
        points.append(((rx+.018)*cos(a),(ry+.018)*sin(a),z))
    rb.tube(points,[.026]*len(points),straw_dark if j%3==0 else straw_light,6)
rb.mesh('Basket | upright wicker ribs',basket,smooth=True)
# Braided rim: three low-poly cords winding around the oval mouth.
rim=Builder()
for strand in range(3):
    pts=[]
    for j in range(145):
        a=2*pi*j/144; phase=2*pi*strand/3; rx=.574; ry=.444
        off=.034*cos(3*a*14/(2*pi)+phase)
        z=.725+.034*sin(3*a*14/(2*pi)+phase)
        pts.append(((rx+off)*cos(a),(ry+off)*sin(a),z))
    rim.tube(pts,[.038]*len(pts),straw_light if strand!=1 else straw_dark,6)
rim.mesh('Basket | chunky braided rim',basket,smooth=True)
# Stout handle in the x-z plane, doubled subtly for a hand-crafted thickness.
h=Builder()
for y in [-.045,.045]:
    pts=[]
    for j in range(17):
        t=j/16; x=(t-.5)*.87; z=.69+.72*sin(pi*t)**.78
        pts.append((x,y,z))
    h.tube(pts,[.067]*len(pts),straw,8)
h.mesh('Basket | stout arched handle',basket,smooth=True)
# Two tomatoes are visible in the open bowl. They are static decorative contents.
for i,(x,y,z) in enumerate([(-.13,-.04,.51),(.12,.06,.53)],1):
    fb=Builder(); seg2=16; nr2=8; rrings=[]
    for ri in range(nr2+1):
        lat=-pi/2+pi*ri/(nr2+1); row=[]
        for j in range(seg2):
            a=2*pi*j/seg2; row.append(len(fb.v)); fb.v.append((.16*cos(lat)*cos(a),.15*cos(lat)*sin(a),.16*sin(lat)))
        rrings.append(row)
    lo=len(fb.v); fb.v.append((0,0,-.16)); hi=len(fb.v); fb.v.append((0,0,.16))
    for j in range(seg2): fb.face((lo,rrings[0][(j+1)%seg2],rrings[0][j]),red)
    for r in range(nr2):
        for j in range(seg2): fb.face((rrings[r][j],rrings[r][(j+1)%seg2],rrings[r+1][(j+1)%seg2],rrings[r+1][j]),red)
    for j in range(seg2): fb.face((hi,rrings[-1][j],rrings[-1][(j+1)%seg2]),red)
    fb.mesh(f'Basket Tomato {i:02d}',basket,location=(x,y,z),smooth=True)

# Studio lighting and cameras exist for the editable source and previews; cameras/lights are excluded from GLB.
world=bpy.data.worlds.new('Soft warm studio'); world.use_nodes=True; world.node_tree.nodes['Background'].inputs['Color'].default_value=(.72,.78,.68,1); world.node_tree.nodes['Background'].inputs['Strength'].default_value=.48; bpy.context.scene.world=world
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=20
scene.view_settings.view_transform='AgX'

def aim(obj,target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
cam_data=bpy.data.cameras.new('Preview Camera'); cam=bpy.data.objects.new('Preview Camera',cam_data); bpy.context.collection.objects.link(cam); cam.location=(7.5,-10.5,7.7); aim(cam,(0,-.05,1.02)); cam.data.type='ORTHO'; cam.data.ortho_scale=8.0; scene.camera=cam
for name,loc,power,size in [('Key',(-4,-5,8),700,5.0),('Fill',(4,-1,6),320,4.0),('Rim',(1,5,6),240,3.0)]:
    d=bpy.data.lights.new(name,'AREA'); d.energy=power; d.shape='DISK'; d.size=size; o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); o.location=loc; aim(o,(0,0,.9))
# Ground plane is render-only and excluded from the GLB; it is not a baked texture/shadow.
ground_mat=mat('Preview ground',(0.77,.79,.70),.96)
gb=Builder(); gb.v=[(-200,-200,-.035),(200,-200,-.035),(200,200,-.035),(-200,200,-.035)]; gb.face((0,1,2,3),ground_mat); ground=gb.mesh('Preview only | ground',None)
scene.render.image_settings.file_format='PNG'; scene.render.resolution_percentage=100
for aspect,w,h,path in [(16/9,1280,720,OUT+'/tomato_harvest_16x9.png'),(4/3,960,720,OUT+'/tomato_harvest_4x3.png')]:
    scene.render.resolution_x=w; scene.render.resolution_y=h; cam.data.ortho_scale=8.0 if aspect>=1.5 else 7.2
    # ortho_scale is vertical span in Blender; set it to include width with safe horizontal framing.
    bpy.context.view_layer.update(); scene.render.filepath=path; bpy.ops.render.render(write_still=True)
# Hide render helpers from export via temporary collection membership.
helpers=bpy.data.collections.new('Preview Helpers (excluded from GLB)'); scene.collection.children.link(helpers)
for ob in [ground,cam]+[o for o in scene.objects if o.type=='LIGHT']:
    for c in list(ob.users_collection): c.objects.unlink(ob)
    helpers.objects.link(ob)
# Merge static pieces inside each logical group. This preserves harvest fruit as individual meshes
# while limiting the non-interactive scene to a small number of material primitives.
def children_of(parent):
    out=[]
    for child in list(parent.children):
        out.append(child); out.extend(children_of(child))
    return out
for group_name in ['GardenBed','Basket','Plant01','Plant02','Plant03']:
    group=bpy.data.objects[group_name]
    static=[o for o in children_of(group) if o.type=='MESH' and not o.name.startswith('HarvestTarget')]
    if len(static)>1:
        bpy.ops.object.select_all(action='DESELECT')
        for ob in static: ob.select_set(True)
        active=next((o for o in static if o.location.length<1e-6),static[0])
        bpy.context.view_layer.objects.active=active
        bpy.ops.object.join()
        active.name=group_name+' | static geometry'
# Save editable Blender source with preview camera, lights, and render-only ground retained.
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/tomato_harvest_editable.blend')
# Export only modeled group roots and descendants. Preview helpers are not selected/exported.
bpy.ops.object.select_all(action='DESELECT')
asset_objects=[scene_root]+children_of(scene_root)
for ob in asset_objects:
    if ob.type in {'EMPTY','MESH'}: ob.select_set(True)
bpy.context.view_layer.objects.active=scene_root
# GLTF is Y-up; Blender z=0 ground contact maps to GLB Y=0.
bpy.ops.export_scene.gltf(filepath=OUT+'/tomato_harvest_editable.glb',export_format='GLB',use_selection=True,export_apply=False,export_cameras=False,export_lights=False,export_materials='EXPORT',export_yup=True,export_skins=False,export_animations=False)
print('ASSET_OUTPUT',OUT)
