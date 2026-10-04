"""同源草地空间的离线试片；默认导入冻结 GLB，不修改作物和篮子网格。

只导出被动环境；没有新的点击、订单或收获状态。运行需 Blender。
"""
import argparse
from array import array
import ast
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import random
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input', type=Path, default=ROOT/'rendered/whole_plant_scene.glb')
parser.add_argument('--out', type=Path, default=ROOT/'environment_refined')
parser.add_argument('--expect-sha256', default='123cfab7a4150110e8af29ca208b46dda6a8250d4870e46f3fb791620f64718c')
parser.add_argument('--baseline-manifest',type=Path,default=ROOT/'environment_rendered/manifest.json',
                    help='已交接的4fac rig清单；新环境不能悄悄改摄影或分件锚点')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
baseline_path = args.baseline_manifest.resolve()
baseline = json.loads(baseline_path.read_text())
source = args.input.resolve()
digest = hashlib.sha256(source.read_bytes()).hexdigest()
if digest != args.expect_sha256:
    raise ValueError('输入 GLB 与冻结模型不一致；请明确指定新的 --expect-sha256')
output = args.out.resolve()
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
scene = bpy.context.scene
bpy.context.view_layer.update()
imported = list(scene.objects)
source_meshes = {obj.name: obj.data.as_pointer() for obj in imported if obj.type == 'MESH'}
source_matrices = {obj.name: list(value for row in obj.matrix_world for value in row) for obj in imported}
def mesh_digest(mesh):
    positions = array('f',[0])*(len(mesh.vertices)*3)
    indices = array('i',[0])*len(mesh.loops)
    surfaces = array('i',[0])*len(mesh.polygons)
    normals = array('f',[0])*(len(mesh.corner_normals)*3)
    mesh.vertices.foreach_get('co',positions)
    mesh.loops.foreach_get('vertex_index',indices)
    mesh.polygons.foreach_get('material_index',surfaces)
    mesh.corner_normals.foreach_get('vector',normals)
    fingerprint = hashlib.sha256()
    for values in (positions,indices,surfaces,normals):
        fingerprint.update(values.tobytes())
    fingerprint.update(json.dumps([material.name if material else None for material in mesh.materials]).encode())
    return fingerprint.hexdigest()
source_mesh_digests = {obj.name:mesh_digest(obj.data) for obj in imported if obj.type=='MESH'}

# 已被否决的平棕床只隐藏，不动源网格、目标、缩放或材质。
bed = bpy.data.objects['GardenBed']
for obj in [bed]+list(bed.children_recursive):
    obj.hide_render = True
environment = bpy.data.objects.new('Environment | passive same-source space', None)
scene.collection.objects.link(environment)
environment['passive_visual_only'] = True

def material(name, color, roughness=1):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    result.diffuse_color = (*color, 1)
    node = result.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Roughness'].default_value = roughness
    return result

near_grass_color = Vector((.31,.475,.125))
far_grass_color = Vector((.40,.565,.40))
grass = material('Environment | quiet natural grass', tuple(near_grass_color))
blade = bpy.data.materials['Leaf | garden green']
soil_color = (.29,.145,.067)
right = Vector((.831,.556,0)).normalized()
away = Vector((-.556,.831,0)).normalized()

def world_point(x, y, z):
    return right*x + away*y + Vector((0,0,z))

def terrain_height(x, y):
    # 真实根点与篮区仍是平地。远处连续草地渐起，起伏不是独立球山。
    distance = max(0, min(1, (y-1.6)/5.0))
    distance = distance*distance*(3-2*distance)
    # 侧面中坡之后露出更淡的远坡，中央保持浅缓通视；全部是同一地形网格。
    middle_roll = (1.85*math.exp(-((x+6.3)/3.1)**2-((y-4.8)/1.5)**2)
                   +1.45*math.exp(-((x-6.6)/3.5)**2-((y-5.4)/1.7)**2)
                   +.36*math.exp(-((x-.2)/5.2)**2-((y-5.5)/1.9)**2))
    far_roll = (.83*math.exp(-((x+2.5)/4.2)**2-((y-8.9)/1.8)**2)
                +.61*math.exp(-((x-5.4)/4.9)**2-((y-9.6)/1.9)**2))
    return -.016 + distance*(.22+middle_roll+far_roll)

cols, rows = 112, 64
vertices, faces, colors, clean_colors = [], [], [], []
plant_roots = [bpy.data.objects[f'Plant{i:02d}'].matrix_world.translation.copy() for i in range(1,4)]
for row in range(rows+1):
    y = -18.0 + 27.5*row/rows
    for col in range(cols+1):
        x = -16.0 + 32.0*col/cols
        point = world_point(x,y,terrain_height(x,y))
        vertices.append(tuple(point))
        fade = max(0,min(1,(y-1.3)/6.8))
        fade = fade*fade*(3-2*fade)
        # 草色近处暖、远处偏蓝灰；变换和光照不变，不单件调曝光。
        color = near_grass_color.lerp(far_grass_color,fade)
        clearing = math.exp(-((x+.6)/5.0)**2-((y+.8)/4.5)**2)
        color = color.lerp(Vector((.365,.515,.155)),clearing*.40)
        warmth = 1+.025*math.cos(x*.43+y*.22)
        color *= warmth
        clean_colors.append((*color,1))
        for root in plant_roots:
            radius = ((point.x-root.x)/.57)**2 + ((point.y-root.y)/.47)**2
            soil_mix = .94*math.exp(-radius*2.5)
            color = color.lerp(Vector(soil_color),soil_mix)
        colors.append((*color,1))
for row in range(rows):
    for col in range(cols):
        a = row*(cols+1)+col
        faces.extend([(a,a+1,a+cols+2),(a,a+cols+2,a+cols+1)])
mesh = bpy.data.meshes.new('Environment | continuous gentle field mesh')
mesh.from_pydata(vertices, [], faces)
mesh.materials.append(grass)
for polygon in mesh.polygons:
    polygon.use_smooth = True
attribute = mesh.color_attributes.new(name='FieldColor', type='FLOAT_COLOR', domain='CORNER')
for polygon in mesh.polygons:
    for loop in polygon.loop_indices:
        attribute.data[loop].color = colors[mesh.loops[loop].vertex_index]
def field_colors(values):
    for loop in mesh.loops:
        attribute.data[loop.index].color = values[loop.vertex_index]
    mesh.update()
color_node = grass.node_tree.nodes.new('ShaderNodeVertexColor')
color_node.layer_name = 'FieldColor'
grass.node_tree.links.new(color_node.outputs['Color'],grass.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
field = bpy.data.objects.new('Environment | continuous gentle field',mesh)
scene.collection.objects.link(field)
field.parent = environment

# 复用已经修复的 Builder / prepare_leaf_surface，不再造第二套叶形。
helpers = {'bpy':bpy, 'bmesh':bmesh, 'math':math, 'Vector':Vector,
           'sin':math.sin, 'cos':math.cos, 'pi':math.pi,
           'leaf':blade, 'leaf_surface_preparation':[]}
for path, name in [(ROOT/'inputs/plant_builder_source.py','Builder'),
                   (ROOT/'build_whole_plant.py','prepare_leaf_surface'),
                   (ROOT/'build_whole_plant.py','frame_ground')]:
    tree = ast.parse(path.read_text())
    node = next(item for item in tree.body if getattr(item,'name',None)==name)
    exec(compile(ast.Module(body=[node],type_ignores=[]),str(path),'exec'),helpers)
builder = helpers['Builder']()
rng = random.Random(10602)
grass_origins = []
for side in (-1,1):
    for index in range(6):
        # 中央操作区不撒疑似小苗；右下篮区没有短草遮住反馈。
        x = side*rng.uniform(7.3,8.7)
        y = rng.uniform(-3.6,3.9) if side < 0 else rng.uniform(2.2,5.7)
        origin = world_point(x,y,terrain_height(x,y)+.004)
        grass_origins.append({'screen_right_m':x,'screen_away_m':y,'world':list(origin)})
        for sprig in range(3):
            angle = rng.uniform(0,math.tau)
            direction = Vector((math.cos(angle)*.48,math.sin(angle)*.48,.88)).normalized()
            across = direction.cross(Vector((0,0,1))).normalized()
            builder.leaflet(origin,direction,across,rng.uniform(.13,.24),
                            rng.uniform(.025,.037),blade,segs=4,bend=.022)
sprigs = builder.mesh('Environment | restrained short grass',environment,smooth=True)
helpers['prepare_leaf_surface'](sprigs)
modifier = sprigs.modifiers.new('Soft short grass thickness','SOLIDIFY')
modifier.thickness = .006
modifier.offset = 0
bpy.context.view_layer.objects.active = sprigs
bpy.ops.object.modifier_apply(modifier=modifier.name)
# 草叶的薄侧壁不能跨大锐角和两面共用平均法线；只处理新草簇，
# 不动冻结株身、果实、圆润藤篮或连续地形的平滑法线。
grass_bm = bmesh.new()
grass_bm.from_mesh(sprigs.data)
bmesh.ops.remove_doubles(grass_bm,verts=list(grass_bm.verts),dist=1e-6)
collapsed = [face for face in grass_bm.faces if face.calc_area()<1e-12]
if collapsed:
    bmesh.ops.delete(grass_bm,geom=collapsed,context='FACES_ONLY')
# Solidify 的薄侧壁仍是非共面四边形，导出前也固定三角解释。
bmesh.ops.triangulate(grass_bm,faces=list(grass_bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
bmesh.ops.recalc_face_normals(grass_bm,faces=list(grass_bm.faces))
for edge in grass_bm.edges:
    edge.smooth = not edge.is_manifold or edge.calc_face_angle(0)<math.radians(55)
grass_bm.normal_update()
grass_bm.to_mesh(sprigs.data)
grass_bm.free()
sprigs.data.update()

world = bpy.data.worlds.new('Environment review | soft blue sky')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (.70,.82,.88,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = .45
# 相机可见天空和环境补光分开，避免为了蓝天把整株照成荧光绿。
sky = world.node_tree.nodes.new('ShaderNodeBackground')
sky.inputs['Color'].default_value = (.32,.64,.92,1)
sky.inputs['Strength'].default_value = 1
light_path = world.node_tree.nodes.new('ShaderNodeLightPath')
mix = world.node_tree.nodes.new('ShaderNodeMixShader')
world.node_tree.links.new(light_path.outputs['Is Camera Ray'],mix.inputs[0])
world.node_tree.links.new(world.node_tree.nodes['Background'].outputs['Background'],mix.inputs[1])
world.node_tree.links.new(sky.outputs['Background'],mix.inputs[2])
world.node_tree.links.new(mix.outputs['Shader'],world.node_tree.nodes['World Output'].inputs['Surface'])
scene.world = world
def aim(obj, point):
    obj.rotation_euler = (Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()
light_specs = [('Key','SUN',(-3.7,-4.5,10.5),1.10,.30,(1,.93,.83)),
               ('Fill','AREA',(4.5,-1.0,5.5),240,4.6,(.88,.94,1)),
               ('Rim','AREA',(1.0,4.5,6.0),180,4.6,(1,.97,.86))]
for name, kind, location, energy, size, color in light_specs:
    data = bpy.data.lights.new('Environment review | '+name,kind)
    data.energy = energy
    if kind=='SUN':
        data.angle = size
    else:
        data.size = size
    data.color = color
    lamp = bpy.data.objects.new(data.name,data)
    scene.collection.objects.link(lamp)
    lamp.location = location
    aim(lamp,(0,0,.8))
camera_data = bpy.data.cameras.new('Environment review | shared orthographic')
camera_data.type = 'ORTHO'
camera = bpy.data.objects.new(camera_data.name,camera_data)
scene.collection.objects.link(camera)
camera.location = (6.7,-9.8,6.8)
aim(camera,(.14,-.12,1.03))
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
# 同场所有部件使用同一显示变换；不单独增艳果实或贴另一张天空图。
scene.view_settings.view_transform = 'Standard'
scene.view_settings.exposure = -.20
scene.view_settings.look = 'None'
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.resolution_percentage = 100
renders = []
runtime_background_span = 1280*2.60/180 # 单件作物 art_size90、跨度2.60 的统一米/像素基准。
for aspect, width, height, span in [('16x9',1280,720,9.4),('4x3',960,720,8.8)]:
    scene.render.resolution_x,scene.render.resolution_y = width,height
    camera_data.ortho_scale = span
    scene.render.filepath = str(output/('same_source_space_'+aspect+'.png'))
    bpy.ops.render.render(write_still=True)
    renders.append({'file':Path(scene.render.filepath).name,'size':[width,height],
                    'ortho_scale':span,'camera_direction':'与整株冻结模型一致'})
    flags = {obj.name:obj.hide_render for obj in imported if obj.type=='MESH'}
    for obj in imported:
        if obj.type=='MESH':
            obj.hide_render = True
    # 背景层不能残留示例三株的固定土色印记，真实根点属于现有布局。
    field_colors(clean_colors)
    camera_data.ortho_scale = runtime_background_span
    scene.render.filepath = str(output/('environment_only_'+aspect+'.png'))
    bpy.ops.render.render(write_still=True)
    renders[-1]['environment_only_ortho_scale'] = runtime_background_span
    renders[-1]['environment_only_reference'] = '1280逻辑宽、art_size90/180px画布的同源背景；不是放大展示图'
    camera_data.ortho_scale = span
    field_colors(colors)
    for obj in imported:
        if obj.type=='MESH':
            obj.hide_render = flags[obj.name]

# 同一 rig 的透明分件，避免把旧 AgX PNG 拼在新的 Standard 环境上。
# 只临时改变可见性/单果取景，结束后恢复输入模型的完整变换。
helpers.update({'scene':scene,'camera':camera,'shared_rotation':camera.rotation_euler.copy(),
                'world_to_camera_view':world_to_camera_view})
saved_camera = camera.matrix_world.copy()
saved_span = camera_data.ortho_scale
saved_resolution = (scene.render.resolution_x,scene.render.resolution_y)
mesh_flags = {obj.name:obj.hide_render for obj in scene.objects if obj.type=='MESH'}
for obj in scene.objects:
    if obj.type=='MESH':
        obj.hide_render = True
scene.render.film_transparent = True
scene.render.resolution_x,scene.render.resolution_y = 512,512
plant = bpy.data.objects['Plant01']
plant_body = bpy.data.objects['Plant01 | static geometry']
plant_body.hide_render = False
helpers['frame_ground'](plant.matrix_world.translation,2.95)
projected_anchors = []
for target in sorted((obj for obj in plant.children if obj.name.startswith('HarvestTarget')),key=lambda obj:obj.name):
    projected = world_to_camera_view(scene,camera,target.matrix_world.translation)
    projected_anchors.append({'name':target.name,
        'pixel_center_512':[round(projected.x*512,3),round((1-projected.y)*512,3)],
        'scale':list(target.matrix_world.to_scale())})
scene.render.filepath = str(output/'plant001_body_512.png')
bpy.ops.render.render(write_still=True)
plant_body.hide_render = True
fruit = bpy.data.objects['HarvestTarget Tomato P01 F01']
fruit_parent,fruit_matrix = fruit.parent,fruit.matrix_world.copy()
fruit_basis,fruit_parent_inverse = fruit.matrix_basis.copy(),fruit.matrix_parent_inverse.copy()
fruit.parent = None
fruit.matrix_world = Matrix.Translation(Vector((0,0,.232))) @ Matrix.Diagonal(Vector((*fruit_matrix.to_scale(),1)))
fruit.hide_render = False
helpers['frame_ground']((0,0,0),1.08)
projected = world_to_camera_view(scene,camera,Vector((0,0,.232)))
single_fruit_center = [round(projected.x*512,3),round((1-projected.y)*512,3)]
scene.render.filepath = str(output/'tomato_fruit_512.png')
bpy.ops.render.render(write_still=True)
fruit.hide_render = True
fruit.parent = fruit_parent
fruit.matrix_parent_inverse = fruit_parent_inverse
fruit.matrix_basis = fruit_basis
basket = bpy.data.objects['Basket']
for obj in basket.children_recursive:
    if obj.type=='MESH':
        obj.hide_render = False
helpers['frame_ground'](basket.matrix_world.translation,1.94)
scene.render.filepath = str(output/'basket_512.png')
bpy.ops.render.render(write_still=True)
for obj in scene.objects:
    if obj.type=='MESH':
        obj.hide_render = mesh_flags[obj.name]
camera.matrix_world = saved_camera
camera_data.ortho_scale = saved_span
scene.render.resolution_x,scene.render.resolution_y = saved_resolution
scene.render.film_transparent = False
bpy.context.view_layer.update()

scene['review_status'] = '离线同源空间试片；不是 Godot 页面，未证明 PNG 接入或输入/性能通过'
bpy.ops.wm.save_as_mainfile(filepath=str(output/'same_source_space.blend'))
# 导出的可复用地面和环境-only PNG 都不携带示例根点印记。
field_colors(clean_colors)
bpy.ops.object.select_all(action='DESELECT')
for obj in [environment]+list(environment.children_recursive):
    obj.select_set(True)
bpy.context.view_layer.objects.active = environment
bpy.ops.export_scene.gltf(filepath=str(output/'passive_environment.glb'),export_format='GLB',
                         use_selection=True,export_apply=True,export_cameras=False,export_lights=False,
                         export_skins=False,export_animations=False)
assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
assert all(bpy.data.objects[name].data.as_pointer()==pointer for name,pointer in source_meshes.items())
assert all(mesh_digest(bpy.data.objects[name].data)==fingerprint
           for name,fingerprint in source_mesh_digests.items()), '输入网格的位置/连接/法线或材质槽发生变化'
transform_deltas = {name:max(abs(a-b) for a,b in zip(
    (value for row in bpy.data.objects[name].matrix_world for value in row),matrix))
    for name,matrix in source_matrices.items()}
assert max(transform_deltas.values(),default=0)<1e-6, transform_deltas
spec = importlib.util.spec_from_file_location('shared_audit',ROOT.parent/'validation/audit_glb.py')
auditor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auditor)
audit = auditor.audit(output/'passive_environment.glb')
audit['path'] = 'passive_environment.glb'
manifest = {'status':'离线美术候选；未接正式页面', 'source_sha256':digest,
            'input':str(source),'source_file_unchanged':True,'imported_meshes_unchanged':True,
            'imported_transforms_unchanged':True,'hidden_only':['GardenBed'],
            'max_imported_transform_delta':max(transform_deltas.values(),default=0),
            'environment_revision':'连续远坡、自然绿层次、边缘短草；旧4fac rig不变',
            'environment_palette':{'near':list(near_grass_color),'far':list(far_grass_color)},
            'environment_short_grass_origins':grass_origins,
            'transform_tolerance':1e-6,'environment_export_contains_fixed_soil_marks':False,
            'input_mesh_fingerprints':source_mesh_digests,
            'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'blender_version':bpy.app.version_string,'renders':renders,'environment_audit':audit,
            'render_profile':{'display_transform':'Standard','exposure':-.20,
                              'look':'None','samples':24,'denoise':True,
                              'camera_location':[6.7,-9.8,6.8],'camera_aim':[.14,-.12,1.03],
                              'camera_rotation_euler':list(helpers['shared_rotation']),
                              'ambient_color':[.70,.82,.88],'ambient_strength':.45,
                              'camera_sky_color':[.32,.64,.92],'camera_sky_strength':1,
                              'lights':[dict({'name':name,'type':kind,'location':list(location),
                                              'energy':energy,'color':list(color),'aim':[0,0,.8]},
                                             **({'angle':size} if kind=='SUN' else {'shape':'SQUARE','size':size}))
                                        for name,kind,location,energy,size,color in light_specs],
                              'camera_visible_sky_separate_from_ambient':True},
            'runtime_reference':{'logical_width_px':1280,'crop_art_size':90,'crop_ortho_span_m':2.60,
                                 'pixels_per_metre':180/2.60,'plant_body_art_size':90*2.95/2.60,
                                 'dense_plant_body_art_size':72*2.95/2.60,
                                 'background_ortho_span_m':runtime_background_span},
            'png_contract':{'size_px':[512,512],'world0_px':[256,467],
                            'ortho_spans_m':{'plant001_body':2.95,'tomato_fruit':1.08,'basket':1.94},
                            'projected_fruit_anchors':projected_anchors,
                            'single_target_fruit_pixel_center_512':single_fruit_center,
                            'source_scale_baked_in_fruit_png':[1.13,1.13,1.13],
                            'contact_shadow_baked':False},
            'matching_cutouts':{'plant001_body_512.png':'株身；512画布，原点(256,467)，跨度2.95',
                                'tomato_fruit_512.png':'单果；跨度1.08，图内已含1.13源比例，果心抬高.232m',
                                'basket_512.png':'独立空篮；原点(256,467)，跨度1.94'},
            'transparent_shadow_baked':False,
            'reuse':['默认导入冻结整株/果实/篮GLB','已有Builder.leaflet及叶端修复','原绿叶材质'],
            'limits':['没有 Godot UI 或运行截图，不是可点击农场',
                      '环境顶点色 COLOR_0 需要实际 Godot 导入检查',
                      '地表截图不是完整背景替换；运行侧仍由既有节点坐标驱动',
                      '当前仅检查完整构图，不证明72px可读性或设备性能']}
for key in ('render_profile','runtime_reference','png_contract'):
    assert manifest[key] == baseline[key], '新环境与冻结契约不一致：'+key
manifest['frozen_contract_review'] = {
    'baseline_manifest_sha256':hashlib.sha256(baseline_path.read_bytes()).hexdigest(),
    'baseline_manifest_path':str(baseline_path),
    'render_profile_strictly_equal':True,'runtime_reference_strictly_equal':True,
    'png_contract_strictly_equal':True}
manifest['files'] = {path.name:{'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                              'bytes':path.stat().st_size}
                     for path in sorted(output.iterdir())
                     if path.suffix in ('.blend','.glb','.png')}
(output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('ENVIRONMENT_MANIFEST',output/'manifest.json')
