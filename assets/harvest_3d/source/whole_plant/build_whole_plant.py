"""同源整株番茄候选：复用 v28 网格及 v33 曲面叶，不含玩法代码。"""
import ast
import argparse
import bpy
import bmesh
import hashlib
import importlib.util
import json
import math
import random
import struct
import sys
from pathlib import Path
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view

SCRIPT_ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--source',type=Path,default=SCRIPT_ROOT/'inputs/tomato_seed.blend')
parser.add_argument('--out',type=Path,default=SCRIPT_ROOT/'rendered')
shared_validator = SCRIPT_ROOT.parent/'validation/audit_glb.py'
parser.add_argument('--validator',type=Path,default=shared_validator)
options = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
if not options.validator.is_file():
    parser.error('找不到共用 GLB 检查脚本，请使用 --validator 指定路径')
OUT = options.out.resolve()
SOURCE = options.source.resolve()
LEAF_SOURCE = SCRIPT_ROOT/'inputs/curved_leaf_source.py'
BUILDER_SOURCE = SCRIPT_ROOT/'inputs/plant_builder_source.py'
generator_sha256 = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene

def set_mat(name, color, roughness=.88):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (*color, 1)
    bsdf = next(node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    for link in list(material.node_tree.links):
        if link.to_node == bsdf and link.to_socket == bsdf.inputs['Base Color']:
            material.node_tree.links.remove(link)
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = 0
    return material

leaf = set_mat('Leaf | garden green', (.105,.325,.045), .88)
vine = set_mat('Vine | deep green', (.070,.215,.025), .90)
soil = set_mat('Soil | warm loam', (.29,.145,.067), .94)
set_mat('Tomato | ripe red', (.80,.030,.016), .79)
set_mat('Tomato | shoulder red', (.80,.030,.016), .79)
calyx = set_mat('Calyx | fresh green', (.11,.29,.035), .87)
straw = set_mat('Basket | honey straw', (.59,.315,.10), .86)
set_mat('Basket | sunlit weave', (.73,.435,.16), .88)
set_mat('Basket | shadow weave', (.43,.235,.07), .90)

# 从既有脚本 AST 只加载造型函数，避免触发原脚本渲染与写入旧版本。
helpers = {'bpy':bpy, 'math':math, 'Vector':Vector, 'sin':math.sin,
           'cos':math.cos, 'pi':math.pi, 'leaf':leaf, 'soil':soil}
for file, symbol in ((LEAF_SOURCE,'curved_leaf_mesh'),(BUILDER_SOURCE,'Builder')):
    tree = ast.parse(file.read_text())
    node = next(node for node in tree.body if getattr(node,'name',None) == symbol)
    exec(compile(ast.Module(body=[node], type_ignores=[]), str(file), 'exec'), helpers)
Builder = helpers['Builder']
curved_leaf_mesh = helpers['curved_leaf_mesh']

def join_into(target, parts):
    bpy.ops.object.select_all(action='DESELECT')
    target.select_set(True)
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()

leaf_surface_preparation = []

def prepare_leaf_surface(obj):
    """先修叶尖曲面再厚化，避免重合端点让 Solidify 产生翻折侧壁。"""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    before_vertices, before_faces = len(bm.verts), len(bm.faces)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    collapsed = [face for face in bm.faces if face.calc_area() < 1e-12]
    if collapsed:
        bmesh.ops.delete(bm, geom=collapsed, context='FACES_ONLY')
    # 曲面叶的 quad 并不共面；在 Solidify 前固定真实三角曲面，
    # 不让导出时的分割与挤出时的 polygon 法线解释互相矛盾。
    bmesh.ops.triangulate(bm, faces=list(bm.faces),
                         quad_method='BEAUTY', ngon_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.normal_update()
    leaf_surface_preparation.append({'object':obj.name,
        'vertices_before':before_vertices, 'vertices_after':len(bm.verts),
        'faces_before':before_faces, 'triangles_before_thickness':len(bm.faces),
        'method':'先焊叶端和删退化面，再固定三角曲面、重算法线，最后 Solidify'})
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()

# v28 原有土面与草缘保留，缩成较短种植区，不复制 v33 的气球草环。
bed = bpy.data.objects['GardenBed | static geometry']
for attr in list(bed.data.color_attributes):
    bed.data.color_attributes.remove(attr)
for vertex in bed.data.vertices:
    vertex.co.y *= .78
    vertex.co.z *= .55

plants = [bpy.data.objects[f'Plant{i:02d}'] for i in range(1,4)]
plant_locations = [(-1.28,.08,0),(.0,.02,0),(1.25,.10,0)]
fruit_slots = [(-.43,-.43,.79),(.38,-.40,1.08),(-.33,-.32,1.38),(.34,-.27,1.65)]
# 叶片沿枝干连接，左右成簇但保留红果的前方窗口。
leaf_specs = [
    ((-.04,.09,.43),(-1.0,.18),.67,.245,.25,.055),
    (( .03,.10,.48),( 1.0,.30),.70,.235,.20,.060),
    ((-.04,.12,.72),(-1.0,.32),.70,.245,.18,.070),
    (( .04,.13,.89),( 1.0,.37),.69,.240,.23,.060),
    ((-.04,.15,1.05),(-1.0,.45),.68,.250,.21,.055),
    (( .02,.14,1.22),( 1.0,.42),.66,.245,.26,.070),
    ((-.05,.12,1.44),(-1.0,.50),.62,.225,.28,.055),
    (( .02,.15,1.65),( 1.0,.44),.60,.230,.20,.060),
    ((-.03,.18,1.72),(-.30,1.0),.57,.215,.26,.045),
    (( .03,.18,1.66),( .30,1.0),.57,.215,.30,.050),
    ((-.02,.10,.60),(-.25,1.0),.56,.215,.25,.060),
    (( .02,.10,1.12),( .20,1.0),.62,.230,.20,.060),
]
for index, (plant, location) in enumerate(zip(plants, plant_locations),1):
    plant.location = location
    plant.rotation_euler.z = (-.10,.07,.18)[index-1]
    foliage = bpy.data.objects[f'Plant{index:02d} | static geometry']
    # 移除旧薄纸叶，只保留既有主茎与分枝；目标果实子节点不合并。
    bm = bmesh.new()
    bm.from_mesh(foliage.data)
    # 原网格的主茎为连续独立长条；保留它，删掉旧叶柄的无叶尖刺。
    unseen = set(bm.verts)
    keep_vertices = set()
    while unseen:
        seed = unseen.pop()
        component,queue = {seed},[seed]
        while queue:
            vertex = queue.pop()
            for edge in vertex.link_edges:
                neighbor = edge.other_vert(vertex)
                if neighbor not in component:
                    component.add(neighbor)
                    unseen.discard(neighbor)
                    queue.append(neighbor)
        ranges = [max(vertex.co[axis] for vertex in component)-min(vertex.co[axis] for vertex in component) for axis in range(3)]
        if ranges[2] > 1.2 and ranges[0] < .36 and ranges[1] < .36:
            keep_vertices.update(component)
    if not keep_vertices:
        raise RuntimeError('不能找到 v28 连续主茎，停止而非重造植株')
    bmesh.ops.delete(bm, geom=[vertex for vertex in bm.verts if vertex not in keep_vertices],context='VERTS')
    bm.to_mesh(foliage.data)
    bm.free()
    # 复用 v33 曲面叶，厚度加到可辨的 0.035m；应用后才导出真实几何。
    variation = random.Random(710+index)
    varied_specs = []
    for base,direction,length,width,lift,wave in leaf_specs:
        yaw = variation.uniform(-.14,.14)
        dx,dy = direction
        direction = (dx*math.cos(yaw)-dy*math.sin(yaw),dx*math.sin(yaw)+dy*math.cos(yaw))
        base = (base[0],base[1],base[2]+variation.uniform(-.065,.065))
        varied_specs.append((base,direction,length*variation.uniform(.90,1.12),
            width*variation.uniform(.88,1.10),lift+variation.uniform(-.055,.055),wave))
    leaves = curved_leaf_mesh(f'Plant{index:02d} | thick curved leaves', varied_specs, leaf)
    scene.collection.objects.link(leaves)
    leaves.parent = plant
    prepare_leaf_surface(leaves)
    leaves.modifiers['Soft leaf thickness'].thickness = .035
    leaves.modifiers['Soft leaf thickness'].offset = 0
    bpy.context.view_layer.objects.active = leaves
    bpy.ops.object.modifier_apply(modifier='Soft leaf thickness')
    # 将原植株接地端补到 z=0，木支架属于各株，不属于篮子。
    stem_parts = Builder()
    # 极细同材质叶脉，只以短软阴影表达曲面，不增加新材质。
    for base,direction,length,width,lift,wave in varied_specs:
        dx,dy = direction
        magnitude = math.hypot(dx,dy)
        dx,dy = dx/magnitude,dy/magnitude
        vein = []
        for step in range(7):
            t = .08+.84*step/6
            env = math.sin(math.pi*t)**.76*(1+wave*math.sin(8*math.pi*t))
            vein.append((base[0]+dx*length*t,base[1]+dy*length*t,
                base[2]+length*(lift*t+.10*math.sin(math.pi*t))+width*.22*env+.020))
        stem_parts.tube(vein,[.007-.004*step/6 for step in range(7)],leaf,5)
    stem_parts.tube([(0,0,.02),(-.025,.015,.22),(0,.035,.49)], [.050,.046,.038], vine,8)
    # 温和木桩沿用 v33 支架造型；加实际 tie 环，把支架关系读出来。
    stem_parts.tube([(0,.18,0),(0,.18,1.05),(0,.18,2.11)], [.075,.075,.070], straw,12)
    for height in (.63,1.18,1.73):
        points = [(.066*math.cos(t*math.tau/28), .092+.130*math.sin(t*math.tau/28), height)
                  for t in range(29)]
        stem_parts.tube(points,.015,vine,6)
    targets = sorted((child for child in plant.children if child.name.startswith('HarvestTarget')),key=lambda ob:ob.name)
    for target, slot in zip(targets, fruit_slots):
        target.location = slot
        target.scale = (1.13,1.13,1.13)
        fx,fy,fz = slot
        # 旧萼片是陷进果肩的三角平面；以同一 Builder 叶形厚化它。
        fruit_bm = bmesh.new()
        fruit_bm.from_mesh(target.data)
        bmesh.ops.delete(fruit_bm, geom=[face for face in fruit_bm.faces
            if target.data.materials[face.material_index] == calyx], context='FACES')
        fruit_bm.to_mesh(target.data)
        fruit_bm.free()
        calyx_builder = Builder()
        for blade in range(5):
            angle = blade*math.tau/5
            calyx_builder.leaflet((0,0,.221),(math.cos(angle),math.sin(angle),-.38),
                (-math.sin(angle),math.cos(angle),0),.180,.044,calyx,segs=3,bend=.015)
        calyx_mesh = calyx_builder.mesh(target.name+' | raised calyx',target,smooth=True)
        prepare_leaf_surface(calyx_mesh)
        modifier = calyx_mesh.modifiers.new('Calyx thickness','SOLIDIFY')
        modifier.thickness = .011
        bpy.context.view_layer.objects.active = calyx_mesh
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        join_into(target,[calyx_mesh])
        for polygon in target.data.polygons:
            polygon.use_smooth = True
        # 果梗从真实主茎发出，终点进入果实萼梗，不悬浮。
        stem_parts.tube([(0,.025,fz+.22),(fx*.46,-.08,fz+.27),
                         (fx*.82,fy*.66,fz+.29),(fx,fy,fz+.27)],
                        [.022,.020,.018,.015],vine,7)
        target['visual_only_target'] = True
        target['existing_component_owner'] = 'HarvestTarget'
    supports = stem_parts.mesh(f'Plant{index:02d} | stake ties and pedicels',plant,smooth=True)
    join_into(foliage,[leaves,supports])
    # 静态单株只保留绿植/木桩两种材质；目标果实材质不受影响。
    green_index = next(i for i,m in enumerate(foliage.data.materials) if m == leaf)
    for polygon in foliage.data.polygons:
        if foliage.data.materials[polygon.material_index].name.startswith('Vine |'):
            polygon.material_index = green_index
    foliage['passive_appearance'] = True
    plant['ground_pivot_m'] = [0,0,0]
    plant['source'] = 'main-v28 plant + parallel-v33 curved_leaf_mesh'

# 已有粗藤编篮独立移动；不新增篮子模型或规则。
basket = bpy.data.objects['Basket']
basket.location = (2.25,-1.27,0)
basket.scale = (1.03,1.03,1.03)
basket['source'] = 'main-v28 woven basket, empty contents, repaired original handle ring vertices, matte material'
basket['owns_stakes'] = False
basket_geometry = bpy.data.objects['Basket | static geometry']
# 复用旧篮提手原网格，修 tube 的参照轴切换造成的相邻环扭转。
# 提手是两个 17×8 顶点的连通弧；沿固定 Y 轴重排原环，不造新篮。
handle_bm = bmesh.new()
handle_bm.from_mesh(basket_geometry.data)
handle_bm.verts.ensure_lookup_table()
unseen = set(handle_bm.verts)
handle_fixed = 0
while unseen:
    seed = unseen.pop()
    component,queue = {seed},[seed]
    while queue:
        vertex = queue.pop()
        for edge in vertex.link_edges:
            neighbor = edge.other_vert(vertex)
            if neighbor not in component:
                component.add(neighbor)
                unseen.discard(neighbor)
                queue.append(neighbor)
    ranges = [max(vertex.co[axis] for vertex in component)-min(vertex.co[axis] for vertex in component) for axis in range(3)]
    if len(component) != 136 or ranges[1] > .22 or ranges[2] < .65 or ranges[0] < .75:
        continue
    ordered = sorted(component,key=lambda vertex:vertex.index)
    rings = [ordered[i:i+8] for i in range(0,len(ordered),8)]
    centers = [sum((vertex.co for vertex in ring),Vector())/8 for ring in rings]
    for i,(center,ring) in enumerate(zip(centers,rings)):
        tangent = (centers[min(i+1,16)]-centers[max(i-1,0)]).normalized()
        across = Vector((0,1,0))
        normal = tangent.cross(across).normalized()
        radius = sum((vertex.co-center).length for vertex in ring)/8
        for j,vertex in enumerate(ring):
            angle = j*math.tau/8
            vertex.co = center+radius*(math.cos(angle)*normal+math.sin(angle)*across)
    handle_fixed += 1
handle_bm.normal_update()
handle_bm.to_mesh(basket_geometry.data)
handle_bm.free()
assert handle_fixed == 2, f'Expected 2 existing handle arcs, got {handle_fixed}'
basket['handle_fix'] = 'Reoriented existing 17x8 ring vertices with a continuous Y frame; no new geometry'
# 篮内装饰果不代表收获数量；沿用现有开口篮网格，删其红果面即可。
bm = bmesh.new()
bm.from_mesh(basket_geometry.data)
bmesh.ops.delete(bm, geom=[face for face in bm.faces
    if basket_geometry.data.materials[face.material_index].name.startswith('Tomato |')], context='FACES')
bm.to_mesh(basket_geometry.data)
bm.free()

ground = bpy.data.objects['Preview only | ground']
set_mat('Preview ground', (.84,.78,.66), .96)
ground.location.z = -.028
world = scene.world.node_tree.nodes['Background']
world.inputs['Color'].default_value = (.84,.82,.74,1)
world.inputs['Strength'].default_value = .45
for light in [ob for ob in scene.objects if ob.type == 'LIGHT']:
    light.data.energy = {'Key':560,'Fill':240,'Rim':180}.get(light.name,180)
    light.data.size = 4.6
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'None'
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.resolution_percentage = 100

# 清理旧网格端点退化面，统一闭合部件方向；薄叶边沿不跨锐角平滑。
# 只改现有几何的拓扑/法线，不改变轮廓、目标节点、材质或状态来源。
topology_cleanup = []
for asset_object in bpy.data.objects['Root'].children_recursive:
    if asset_object.type != 'MESH':
        continue
    mesh = asset_object.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    before_vertices, before_faces = len(bm.verts), len(bm.faces)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    zero_faces = [face for face in bm.faces if face.calc_area() < 1e-12]
    if zero_faces:
        bmesh.ops.delete(bm, geom=zero_faces, context='FACES_ONLY')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    for edge in bm.edges:
        # 原篮编织法线没有异常，保留圆润平滑，不把低边数藤条变成硬折纸。
        edge.smooth = asset_object.name.startswith('Basket') or not edge.is_manifold \
            or edge.calc_face_angle(0.0) < math.radians(55)
    bm.normal_update()
    after_vertices, after_faces = len(bm.verts), len(bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    topology_cleanup.append({'object':asset_object.name,
        'merged_vertices':before_vertices-after_vertices,
        'removed_faces':before_faces-after_faces})

def aim(obj, point):
    obj.rotation_euler = (Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()

camera = scene.camera
camera.location = (6.7,-9.8,6.8)
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 7.5
aim(camera,(.14,-.12,1.03))
shared_rotation = camera.rotation_euler.copy()
scene.render.film_transparent = False
scene.render.resolution_x,scene.render.resolution_y = 1280,720
scene.render.filepath = str(OUT/'whole_plant_scene_16x9.png')
bpy.ops.render.render(write_still=True)
scene.render.resolution_x,scene.render.resolution_y = 960,720
camera.data.ortho_scale = 7.25
scene.render.filepath = str(OUT/'whole_plant_scene_4x3.png')
bpy.ops.render.render(write_still=True)

# 单株透明底大图：保持同一镜头方向，仅改变相机取景和可见集合。
asset_root = bpy.data.objects['Root']
hidden = []
for group in [bpy.data.objects['GardenBed'],basket,plants[1],plants[2]]:
    for ob in [group]+list(group.children_recursive):
        hidden.append((ob,ob.hide_render))
        ob.hide_render = True
hidden.append((ground,ground.hide_render))
ground.hide_render = True
def frame_ground(point, span):
    point = Vector(point)
    camera.rotation_euler = shared_rotation
    camera.location = point+Vector((6.7,-9.8,6.8))
    camera.data.ortho_scale = span
    bpy.context.view_layer.update()
    projected = world_to_camera_view(scene,camera,point)
    right = camera.rotation_euler.to_quaternion() @ Vector((1,0,0))
    up = camera.rotation_euler.to_quaternion() @ Vector((0,1,0))
    camera.location += right*((projected.x-.5)*span)+up*((projected.y-(1-467/512))*span)
    bpy.context.view_layer.update()
    projected = world_to_camera_view(scene,camera,point)
    assert abs(projected.x-.5)<1e-5 and abs(projected.y-(1-467/512))<1e-5, projected

scene.render.film_transparent = True
scene.render.resolution_x,scene.render.resolution_y = 1024,1024
frame_ground(plants[0].location,2.95)
scene.render.filepath = str(OUT/'plant001_transparent.png')
bpy.ops.render.render(write_still=True)
scene.render.resolution_x,scene.render.resolution_y = 512,512
scene.render.filepath = str(OUT/'plant001_512.png')
bpy.ops.render.render(write_still=True)
target_children = [child for child in plants[0].children if child.name.startswith('HarvestTarget')]
fruit_anchors = []
for target in target_children:
    projected = world_to_camera_view(scene,camera,target.matrix_world.translation)
    fruit_anchors.append({'name':target.name,'pixel_center_512':[round(projected.x*512,3),round((1-projected.y)*512,3)],
        'plant_local_center_m':list(target.location),'scale':list(target.scale)})
for target in target_children:
    target.hide_render = True
scene.render.filepath = str(OUT/'plant001_body_512.png')
bpy.ops.render.render(write_still=True)

# 单果为已有目标果独立导出，与株身分开，后续一采只移动果实。
plant_geometry = bpy.data.objects['Plant01 | static geometry']
plant_geometry.hide_render = True
fruit = target_children[0]
old_parent,old_matrix = fruit.parent,fruit.matrix_world.copy()
fruit.parent = None
fruit.location = (0,0,.232)
fruit.rotation_euler = (0,0,0)
fruit.hide_render = False
frame_ground((0,0,0),1.08)
projected_single_fruit = world_to_camera_view(scene,camera,Vector((0,0,.232)))
single_fruit_pixel_center = [round(projected_single_fruit.x*512,3),round((1-projected_single_fruit.y)*512,3)]
scene.render.filepath = str(OUT/'tomato_fruit_512.png')
bpy.ops.render.render(write_still=True)
fruit.parent = old_parent
fruit.matrix_world = old_matrix
fruit.hide_render = True

# 篮子的同镜头透明图，木桩均在 Plant 网格，不随篮导出。
for ob in [basket]+list(basket.children_recursive):
    ob.hide_render = False
frame_ground(basket.location,1.94)
scene.render.filepath = str(OUT/'basket_512.png')
bpy.ops.render.render(write_still=True)
plant_geometry.hide_render = False
for target in target_children:
    target.hide_render = False
for ob,state in hidden:
    ob.hide_render = state
camera.location = (6.7,-9.8,6.8)
aim(camera,(.14,-.12,1.03))
camera.data.ortho_scale = 7.5
scene.render.film_transparent = False
scene.render.resolution_x,scene.render.resolution_y = 1280,720
scene['review_status'] = 'Offline art candidate. No Godot integration or gameplay verification.'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'whole_plant_editable.blend'))

def export_group(group, filename, reset_origin=False, exclude_targets=False, fruit_png_orientation=False):
    bpy.context.view_layer.update()
    old_parent,old_matrix = group.parent,group.matrix_world.copy()
    old_basis,old_inverse = group.matrix_basis.copy(),group.matrix_parent_inverse.copy()
    if reset_origin:
        group.parent = None
        if fruit_png_orientation:
            group.matrix_world = Matrix.Diagonal(Vector((*old_matrix.to_scale(),1)))
        else:
            # 单株 PNG 与 GLB 同 yaw/scale，归零接地平移而保留外观方向。
            group.matrix_world = Matrix.Translation(-old_matrix.to_translation()) @ old_matrix
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    for ob in [group]+list(group.children_recursive):
        if ob.type in {'EMPTY','MESH'} and not (exclude_targets and ob.name.startswith('HarvestTarget')):
            ob.select_set(True)
    bpy.context.view_layer.objects.active = group
    bpy.ops.export_scene.gltf(filepath=str(OUT/filename),export_format='GLB',
        use_selection=True,export_apply=True,export_cameras=False,export_lights=False,
        export_materials='EXPORT',export_yup=True,export_skins=False,export_animations=False)
    group.parent = old_parent
    # 归零单件导出后还原父级下的原 basis，不能用刚切父级时的 world setter。
    # 否则第一颗果实可能在后续整场 GLB 中偏移，PNG 预览却仍看不出问题。
    group.matrix_parent_inverse = old_inverse
    group.matrix_basis = old_basis
    bpy.context.view_layer.update()

export_group(plants[0],'plant001.glb',True)
export_group(plants[0],'plant001_body.glb',True,exclude_targets=True)
export_group(target_children[0],'tomato_fruit.glb',True,fruit_png_orientation=True)
export_group(basket,'basket.glb',True)
export_group(asset_root,'whole_plant_scene.glb')

audit_path = options.validator.resolve()
spec = importlib.util.spec_from_file_location('shared_glb_audit',audit_path)
auditor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auditor)
audits = {}
for name in ('plant001.glb','plant001_body.glb','tomato_fruit.glb','basket.glb','whole_plant_scene.glb'):
    result = auditor.audit(OUT/name)
    result['path'] = name
    audits[name] = result
errors = auditor.check_whole_plant(audits['whole_plant_scene.glb'])
assert not errors, errors
(OUT/'validation/glb_audit.json').parent.mkdir(parents=True,exist_ok=True)
(OUT/'validation/glb_audit.json').write_text(json.dumps(audits,ensure_ascii=False,indent=2)+'\n')

manifest = {'status':'离线美术候选；未接 Godot，不含经济或输入改动',
    'source_generator':{'path':'build_whole_plant.py','sha256':generator_sha256,
        'blender_version':bpy.app.version_string},
    'leaf_surface_preparation':leaf_surface_preparation,
    'topology_cleanup':topology_cleanup,
    'source_dependencies':[{'path':str(path.relative_to(SCRIPT_ROOT)) if path.is_relative_to(SCRIPT_ROOT) else str(path),
                           'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
                           for path in (SOURCE,LEAF_SOURCE,BUILDER_SOURCE)],
    'validation_provider':{'expected_relative_path':'../validation/audit_glb.py','sha256':hashlib.sha256(audit_path.read_bytes()).hexdigest()},
    'reuse':{'plant':'v28 roots, curved stems and independent targets; v33 curved_leaf_mesh',
            'basket':'v28 Basket group; original handle ring vertices repaired and decorative contents removed; no wood supports',
            'bed':'v28 original passive bed, compressed depth/height; no v33 puff perimeter'},
    'files':{name:{'sha256':result['sha256'],'bytes':result['bytes'],'summary':result['summary']}
             for name,result in audits.items()},
    'ground_pivot':'独立 GLB 根节点原点=(0,0,0)，Blender Z-up 导出 glTF Y-up',
    'png_contract':{'size_px':[512,512],'world0_px':[256,467],
        'camera':'全景相同正交 3/4 方向，按物件改变 ortho_scale；1024 审图 pivot=(512,934)',
        'whole_plant':'plant001_512.png','passive_body':'plant001_body_512.png',
        'single_target_fruit':'tomato_fruit_512.png','basket':'basket_512.png',
        'single_target_fruit_pixel_center_512':single_fruit_pixel_center,
        'contact_shadow_baked':False,'runtime_contact_shadow':'复用既有 Shapes.ground_shadow；透明PNG不含接地阴影',
        'ortho_spans_m':{'plant001':2.95,'tomato_fruit':1.08,'basket':1.94},
        'plant001_yaw_radians':-.10,'plant001_scale':[1,1,1],
        'fruit_mesh_center_above_png_ground_m':.232,'fruit_glb_pivot':'果实中心；PNG world0是果底接触线，故显式抬升.232m',
        'projected_fruit_anchors':fruit_anchors,
        'pickup_semantics':'四果整株只作审图；运行候选需分开株身和单果，采摘仅移动单果'},
    'target_ownership':'每株四个独立 HarvestTarget 子网格；枝叶、果梗、木支架归 Plant 静态网格',
    'known_limits':['全部图为离线 Cycles 图','尚未做真实页面 72–96px 目标和触控验收']}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('MANIFEST',json.dumps(manifest,ensure_ascii=False))
