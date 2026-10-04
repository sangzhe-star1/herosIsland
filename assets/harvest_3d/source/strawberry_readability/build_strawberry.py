"""复用已有草莓网格与冻结导出器，仅整理识别轮廓和表面种子。需Blender。"""
import argparse
import ast
import importlib.util
import json
import math
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent
SOURCE_ROOT = ROOT.parent
CATALOG = SOURCE_ROOT/'catalog_profile_candidate'
SOURCE = CATALOG/'catalog_profile_editable.blend'
PROFILE = CATALOG/'inputs/frozen_render_profile.blend'
SOURCE_SHA = 'e28bda1c3520552c8a00fcde7ec7da55ce6f9deb0cda76627c10afdcab363ee9'
PROFILE_SHA = '4facaae15f88401f4f7553f12d4ec1e441e2a9597196b38a0b6a6b6fe2ea5512'

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--out',type=Path,required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
output = args.out.resolve()
output.mkdir(parents=True,exist_ok=True)
spec = importlib.util.spec_from_file_location('shared_catalog_export',CATALOG/'export_catalog.py')
export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(export)
assert export.digest_file(SOURCE)==SOURCE_SHA
assert export.digest_file(PROFILE)==PROFILE_SHA
settings = argparse.Namespace(profile_blend=PROFILE,expect_profile_sha256=PROFILE_SHA,
    render=True,profile_scene=None,camera_name=None,require_light_types='SUN,AREA,AREA',
    require_view_transform='Standard',require_exposure=-.20)
scene,camera,profile = export.setup_profile(settings)
export.configure_png(scene)
collection = export.append_asset_collections(SOURCE,['strawberry'],scene)['strawberry']
collection.hide_render = False
bpy.context.view_layer.update()
excluded_shadows = [obj.name for obj in collection.all_objects if export.is_source_contact_shadow(obj)]
for obj in list(collection.all_objects):
    if export.is_source_contact_shadow(obj):
        # 候选场景彻底移除旧的阴影片，不能只依赖库加载时的hide_render。
        bpy.data.objects.remove(obj,do_unlink=True)
assert len(excluded_shadows)==1
pivot = export.frame_ground(scene,camera)
source_objects = list(collection.all_objects)
body = next(obj for obj in source_objects if obj.name.startswith('Strawberry | heart-shaped berry'))
crown = [obj for obj in source_objects if obj.name.startswith('Strawberry | green crown')]
seeds = sorted([obj for obj in source_objects if obj.name.startswith('Strawberry | seed')],key=lambda obj:obj.name)
assert len(crown)==7 and len(seeds)==21
before = {obj.name:{'geometry_sha256':export.geometry_digest(obj),
                   'matrix_world':export.serial(obj.matrix_world)}
          for obj in source_objects if obj.type in export.GEOMETRY_TYPES}

# 不重造果体：复用八圈lathe网格，扩大上肩、延长柔尖，保留原径向起伏。
old_profile = [(.035,.045),(.11,.15),(.26,.29),(.43,.40),
               (.62,.43),(.78,.36),(.90,.22),(.94,.08)]
new_profile = [(.035,.026),(.17,.095),(.33,.235),(.56,.405),
               (.73,.445),(.85,.400),(.94,.255),(1.02,.075)]
for vertex in body.data.vertices:
    index = min(range(len(old_profile)),key=lambda i:abs(vertex.co.z-old_profile[i][0]))
    assert abs(vertex.co.z-old_profile[index][0])<1e-5
    factor = new_profile[index][1]/old_profile[index][1]
    vertex.co.x *= factor
    vertex.co.y *= factor
    vertex.co.z = new_profile[index][0]
body.data.update()
berry_material = body.data.materials[0]
berry_bsdf = next(node for node in berry_material.node_tree.nodes if node.type=='BSDF_PRINCIPLED')
berry_bsdf.inputs['Roughness'].default_value = .80

leaf_preparation = {'bpy':bpy,'bmesh':bmesh,'leaf_surface_preparation':[]}
path = SOURCE_ROOT/'whole_plant/build_whole_plant.py'
tree = ast.parse(path.read_text())
function = next(node for node in tree.body if getattr(node,'name',None)=='prepare_leaf_surface')
exec(compile(ast.Module(body=[function],type_ignores=[]),str(path),'exec'),leaf_preparation)
for leaf in crown:
    # 同一组莓叶向上肩移动，根部仍连接果体，不添加新图标或树叶资产。
    for vertex in leaf.data.vertices:
        vertex.co.z += .10
    leaf_preparation['prepare_leaf_surface'](leaf)
    modifier = leaf.modifiers.get('Soft leaf thickness')
    assert modifier is not None
    modifier.thickness = .028
    modifier.offset = 0
    bpy.context.view_layer.objects.active = leaf
    bpy.ops.object.modifier_apply(modifier=modifier.name)

def radius_and_slope(z):
    for (za,ra),(zb,rb) in zip(new_profile,new_profile[1:]):
        if za<=z<=zb:
            slope = (rb-ra)/(zb-za)
            return ra+(z-za)*slope,slope
    raise ValueError('种子超出果体曲面')

# 原种子中上排半径比果皮小，绝大多数被埋住。沿冻结镜头前方铺14颗。
view_angle = math.atan2(-9.8,6.7)
seed_rows = [(.26,[-.58,0,.58]),(.44,[-.77,-.24,.29,.79]),
             (.65,[-.70,-.18,.33,.82]),(.82,[-.45,.13,.64])]
seed_specs = []
for z,offsets in seed_rows:
    radius,slope = radius_and_slope(z)
    for offset in offsets:
        angle = view_angle+offset
        outward = Vector((math.cos(angle),math.sin(angle),-slope)).normalized()
        tangent = Vector((math.sin(angle),-math.cos(angle),0))
        upward = tangent.cross(outward).normalized()
        seed_specs.append((Vector((radius*math.cos(angle),radius*math.sin(angle),z))
                           +outward*.009,Matrix((tangent,outward,upward)).transposed()))
for index,seed in enumerate(seeds):
    if index>=len(seed_specs):
        # 多余旧种子仅从候选场景解绑；不写回冻结原.blend。
        collection.objects.unlink(seed)
        continue
    for vertex in seed.data.vertices:
        vertex.co.x *= 1.25
        vertex.co.y *= 1.30
        vertex.co.z *= 1.18
    location,rotation = seed_specs[index]
    seed.location = location
    seed.rotation_euler = rotation.to_euler()
    seed.data.update()

objects = [obj for obj in collection.all_objects
           if obj.type in export.GEOMETRY_TYPES and not export.is_source_contact_shadow(obj)]
for obj in objects:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    collapsed = [face for face in bm.faces if face.calc_area()<1e-12]
    if collapsed:
        bmesh.ops.delete(bm,geom=collapsed,context='FACES_ONLY')
    bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    for edge in bm.edges:
        edge.smooth = not edge.is_manifold or edge.calc_face_angle(0)<math.radians(55)
    bm.normal_update()
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
bpy.context.view_layer.update()
projection = export.projected_mesh_bounds(scene,camera,objects)
assert projection['within_canvas']
scene.render.filepath = str(output/'strawberry.png')
bpy.ops.render.render(write_still=True)
alpha = export.alpha_audit(output/'strawberry.png')
assert alpha['visible_edge_free'] and alpha['solid_edge_free']
bpy.ops.wm.save_as_mainfile(filepath=str(output/'strawberry_readable.blend'))

# GLB只含已有草莓分件的真实几何，不含相机/灯/阴影片/输入对象。
bpy.ops.object.select_all(action='DESELECT')
for obj in objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.export_scene.gltf(filepath=str(output/'strawberry.glb'),export_format='GLB',
    use_selection=True,export_apply=True,export_cameras=False,export_lights=False,
    export_skins=False,export_animations=False)
assert export.digest_file(SOURCE)==SOURCE_SHA and export.digest_file(PROFILE)==PROFILE_SHA
profile_after = export.capture_profile(scene,camera,[obj for obj in scene.objects if obj.type=='LIGHT'],PROFILE,PROFILE_SHA)
for key in ('world','view_settings','display_settings'):
    assert profile[key]==profile_after[key], '冻结显示/环境发生变化：'+key
lamps_before = {lamp['name']:lamp for lamp in profile['lamps']}
lamps_after = {lamp['name']:lamp for lamp in profile_after['lamps']}
assert lamps_before.keys()==lamps_after.keys()
lamp_matrix_errors = {}
for name,old in lamps_before.items():
    new = lamps_after[name]
    # Blender去父级/更新依赖图会重算32位变换，实测约6e-8。
    # 仅矩阵允许1e-6数值误差；灯光RNA及节点树仍逐值严格相等。
    assert old['data']==new['data'] and old['node_tree']==new['node_tree'],name
    error = max(abs(a-b) for ra,rb in zip(old['matrix_world'],new['matrix_world'])
                for a,b in zip(ra,rb))
    lamp_matrix_errors[name] = error
    assert error<1e-6,name
baseline = json.loads((CATALOG/'manifest.json').read_text())
camera_matrix_error = max(abs(a-b) for ra,rb in zip(export.serial(camera.matrix_world),
    baseline['export_camera']['matrix_world']) for a,b in zip(ra,rb))
assert camera_matrix_error<1e-6
audit_spec = importlib.util.spec_from_file_location('shared_glb_audit',SOURCE_ROOT/'validation/audit_glb.py')
audit_module = importlib.util.module_from_spec(audit_spec)
audit_spec.loader.exec_module(audit_module)
glb_audit = audit_module.audit(output/'strawberry.glb')
glb_audit['path'] = 'strawberry.glb'
(output/'glb_audit.json').write_text(json.dumps(glb_audit,ensure_ascii=False,indent=2)+'\n')
manifest = {'status':'同源草莓识别修订候选；尚未替换正式素材',
    'source_blend_sha256':SOURCE_SHA,'frozen_profile_sha256':PROFILE_SHA,
    'generator_sha256':export.digest_file(Path(__file__)),
    'reuse':['既有草莓8圈果体','7片原莓叶','14个原种子网格',
             '唯一catalog导出/投影/alpha辅助函数','整株叶端修复函数','共用GLB审计'],
    'source_files_unchanged':True,'source_objects_before':before,
    'profile_world_display_and_light_data_unchanged':True,
    'lamp_matrix_max_errors':lamp_matrix_errors,'camera_matrix_max_error':camera_matrix_error,
    'transform_tolerance':1e-6,'camera_matrix_matches_catalog':True,
    'source_contact_shadow_excluded':excluded_shadows,'contact_shadow_baked':False,
    'contract':{'size_px':[512,512],'ortho_span_m':2.60,'ground_pivot_px':[256,467],
                'measured_pivot_px':pivot,'per_asset_auto_fit':False},
    'new_profile':new_profile,'seed_rows':seed_rows,'seed_count':len(seed_specs),
    'projected_geometry':projection,'png_audit':alpha,
    'leaf_preparation':leaf_preparation['leaf_surface_preparation'],
    'blender_version':bpy.app.version_string,
    'files':{name:{'sha256':export.digest_file(output/name),'bytes':(output/name).stat().st_size}
             for name in ('strawberry.png','strawberry.glb','strawberry_readable.blend')},
    'limits':['不是Godot游戏截图','未证明24px篮标或儿童识别','不改变vegetable/fruit分类或订单']}
(output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('STRAWBERRY MANIFEST',output/'manifest.json')
