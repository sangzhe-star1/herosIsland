"""Render the frozen passive soil mesh using an exact frozen .blend rig.

This deliberately opens the profile rather than reconstructing World, Sun,
Area lights, color management or Cycles settings from a handwritten JSON.
Neither input file is saved or modified. The output directory must be fresh.
"""
import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
SOIL_SHA = '573f96e7f88fd005b0308a516c07471658a5fb081fd34c7f63ba39095809f8cc'
PROFILE_SHA = '4facaae15f88401f4f7553f12d4ec1e441e2a9597196b38a0b6a6b6fe2ea5512'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def scalar(value):
    if value is None or isinstance(value,(str,int,float,bool)):
        return value
    if isinstance(value,bpy.types.ID):
        return {'id_type':type(value).__name__,'name':value.name_full}
    try:
        return [scalar(item) for item in value]
    except TypeError:
        return str(value)

def rna_settings(data):
    result = {}
    for prop in data.bl_rna.properties:
        if prop.identifier=='rna_type' or prop.type not in ('BOOLEAN','INT','FLOAT','STRING','ENUM'):
            continue
        try:
            result[prop.identifier] = scalar(getattr(data,prop.identifier))
        except (AttributeError,TypeError,RuntimeError):
            continue
    return result

def node_tree_snapshot(tree):
    if tree is None:
        return None
    return {'name':tree.name,'nodes':[
        {'name':node.name,'type':node.bl_idname,'settings':rna_settings(node),
         'inputs':[{'name':socket.name,'identifier':socket.identifier,
                    'default':scalar(socket.default_value) if hasattr(socket,'default_value') else None}
                   for socket in node.inputs]}
        for node in sorted(tree.nodes,key=lambda n:n.name)],
        'links':sorted([[link.from_node.name,link.from_socket.identifier,
                         link.to_node.name,link.to_socket.identifier] for link in tree.links])}

def matrix_values(matrix):
    return [[float(value) for value in row] for row in matrix]

def matrix_delta(left,right):
    return max(abs(left[row][col]-right[row][col]) for row in range(4) for col in range(4))

def mesh_fingerprint(obj):
    data = obj.data
    positions = array('f',[0])*(len(data.vertices)*3)
    indices = array('i',[0])*len(data.loops)
    normals = array('f',[0])*(len(data.corner_normals)*3)
    data.vertices.foreach_get('co',positions)
    data.loops.foreach_get('vertex_index',indices)
    data.corner_normals.foreach_get('vector',normals)
    fingerprint = hashlib.sha256()
    for values in (positions,indices,normals):
        fingerprint.update(values.tobytes())
    fingerprint.update(json.dumps(matrix_values(obj.matrix_world)).encode())
    fingerprint.update(json.dumps([node_tree_snapshot(mat.node_tree) if mat else None
                                   for mat in data.materials],sort_keys=True).encode())
    return fingerprint.hexdigest()

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--profile-blend',type=Path,default=ROOT.parent/'catalog_profile_candidate/inputs/frozen_render_profile.blend')
parser.add_argument('--expect-profile-sha256',default=PROFILE_SHA)
parser.add_argument('--input-glb', type=Path, default=ROOT/'soil_cover.glb')
parser.add_argument('--expect-soil-sha256', default=SOIL_SHA)
parser.add_argument('--expected-mesh-count',type=int,default=1)
parser.add_argument('--expected-node-count',type=int,default=2)
parser.add_argument('--source-spec', type=Path,
                    help='Geometry metadata; defaults to spec.json next to --input-glb.')
parser.add_argument('--require-light-types', nargs='+', default=['SUN','AREA'],
                    help='Fail when any listed type is absent from render-enabled source lamps.')
parser.add_argument('--out',type=Path,default=ROOT/'rendered_profile')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
profile, source, out = args.profile_blend.resolve(), args.input_glb.resolve(), args.out.resolve()
if digest(profile)!=args.expect_profile_sha256:
    raise ValueError('Frozen profile .blend SHA256 does not match')
if digest(source)!=args.expect_soil_sha256:
    raise ValueError('Soil GLB SHA256 does not match the chosen geometry')
if profile==source or out in (profile.parent,source.parent):
    raise ValueError('Use a fresh output directory separate from both inputs')
if out.exists() and any(out.iterdir()):
    raise ValueError('Output directory is not empty; frozen art snapshots are not overwritten')

bpy.ops.wm.open_mainfile(filepath=str(profile))
scene = bpy.context.scene
bpy.context.view_layer.update()
if scene.camera is None or scene.world is None:
    raise ValueError('The frozen profile must provide a scene camera and World')
if scene.render.engine!='CYCLES':
    raise ValueError('Expected an exact Cycles profile; renderer does not substitute engines')
if not scene.world.use_nodes or scene.world.node_tree is None:
    raise ValueError('Expected the frozen profile World complete node tree')
# Blender 5.2 may report scene.use_nodes=True while neither compositor graph
# exists. Only an actual enabled graph can invalidate transparent cutouts.
compositor_graph = (getattr(scene,'compositing_node_group',None)
                    or getattr(scene,'node_tree',None))
compositor_node_count = len(compositor_graph.nodes) if compositor_graph is not None else 0
if scene.render.use_compositing and compositor_node_count:
    raise ValueError('Actual enabled compositor graph requires an explicit transparent-cutout contract')

# Collection visibility is evaluated through the active render view layer.
# An object linked through several collections remains enabled if one path is.
enabled_objects = set()
def enabled_branch(layer,parent_enabled=True):
    enabled = parent_enabled and not layer.exclude and not layer.collection.hide_render
    if enabled:
        enabled_objects.update(layer.collection.objects)
    for child in layer.children:
        enabled_branch(child,enabled)
enabled_branch(bpy.context.view_layer.layer_collection)
lamps = [obj for obj in scene.objects if obj.type=='LIGHT' and not obj.hide_render and obj in enabled_objects]
actual_types = {obj.data.type for obj in lamps}
missing_types = set(args.require_light_types)-actual_types
if missing_types:
    raise ValueError('Missing required render-enabled light types: '+str(sorted(missing_types)))
camera = scene.camera
depsgraph = bpy.context.evaluated_depsgraph_get()
camera_matrix = camera.evaluated_get(depsgraph).matrix_world.copy()
camera_quaternion = camera_matrix.to_quaternion()
lamp_matrices = {obj:obj.evaluated_get(depsgraph).matrix_world.copy() for obj in lamps}
lamp_data_pointers = {obj:obj.data.as_pointer() for obj in lamps}
lamp_rna = {obj:rna_settings(obj.data) for obj in lamps}
lamp_nodes = {obj:node_tree_snapshot(obj.data.node_tree) for obj in lamps}
world = scene.world
world_pointer = world.as_pointer()
world_tree = node_tree_snapshot(world.node_tree)
view_settings = rna_settings(scene.view_settings)
cycles_settings = rna_settings(scene.cycles)
source_camera = {'name':camera.name,'matrix_world':matrix_values(camera_matrix),
                 'quaternion_world':list(camera_quaternion),'data':rna_settings(camera.data)}
lights_manifest = [{'name':obj.name,'type':obj.data.type,'data':lamp_rna[obj],
                    'matrix_world':matrix_values(lamp_matrices[obj]),
                    'node_tree':lamp_nodes[obj]} for obj in lamps]

# Preserve evaluated lamp transforms before removing parent meshes/empties.
# Lamps retain their original data blocks including Sun angle/Area shape and
# any complete light node tree. There is no light-material reconstruction.
for obj,matrix in [(camera,camera_matrix)]+list(lamp_matrices.items()):
    obj.parent = None
    obj.constraints.clear()
    obj.matrix_world = matrix
keepers = {camera,*lamps}
for obj in list(bpy.data.objects):
    if obj not in keepers:
        bpy.data.objects.remove(obj,do_unlink=True)
rig = bpy.data.collections.new('Soil cover | exact frozen profile rig')
scene.collection.children.link(rig)
for obj in keepers:
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    rig.objects.link(obj)
    obj.hide_render = False
    obj.hide_viewport = False
bpy.context.view_layer.update()
for obj in keepers:
    obj.hide_set(False)

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(source))
imported = set(bpy.data.objects)-before
meshes = [obj for obj in imported if obj.type=='MESH']
roots = [obj for obj in imported if obj.parent is None]
assert (len(imported)==args.expected_node_count and len(meshes)==args.expected_mesh_count
        and len(roots)==1), 'Unexpected soil mesh hierarchy'
assert all(obj.type in ('MESH','EMPTY') for obj in imported), 'Soil asset carries a lamp or camera'
assert matrix_delta(roots[0].matrix_world,roots[0].matrix_world.__class__.Identity(4))<1e-6
for obj in meshes:
    for material in obj.data.materials:
        if material and any(node.type=='TEX_IMAGE' for node in material.node_tree.nodes):
            raise ValueError('Unexpected image-textured soil material')
    obj.hide_render = False
    obj.hide_set(False)
bpy.context.view_layer.update()
soil_fingerprints = {obj.name:mesh_fingerprint(obj) for obj in meshes}

scene.camera = camera
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.pixel_aspect_x = 1
scene.render.pixel_aspect_y = 1
scene.render.use_border = False
scene.render.use_crop_to_border = False
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '8'
camera.data = camera.data.copy()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 2.60
camera.data.shift_x = 0
camera.data.shift_y = 0
# Preserve the source effective quaternion. Only right/up translation aligns
# the unchanged world-zero soil pivot on the transparent 512px canvas.
camera.rotation_mode = 'QUATERNION'
camera.rotation_quaternion = camera_quaternion
bpy.context.view_layer.update()
origin = Vector((0,0,0))
projected = world_to_camera_view(scene,camera,origin)
right = camera_quaternion@Vector((1,0,0))
up = camera_quaternion@Vector((0,1,0))
camera.location += right*((projected.x-.5)*2.60)+up*((projected.y-(1-467/512))*2.60)
bpy.context.view_layer.update()
projected = world_to_camera_view(scene,camera,origin)
assert abs(projected.x-.5)<1e-5 and abs(projected.y-(1-467/512))<1e-5, projected
assert abs(camera.matrix_world.to_quaternion().dot(camera_quaternion))>1-1e-6
projected_points = []
for obj in meshes:
    for vertex in obj.data.vertices:
        p = world_to_camera_view(scene,camera,obj.matrix_world@vertex.co)
        projected_points.append((512*p.x,512*(1-p.y)))
bounds = [min(p[0] for p in projected_points),min(p[1] for p in projected_points),
          max(p[0] for p in projected_points),max(p[1] for p in projected_points)]
if not (1<bounds[0]<bounds[2]<511 and 1<bounds[1]<bounds[3]<511):
    raise ValueError('Frozen camera clips soil geometry: '+str(bounds))

def assert_exact_profile():
    assert scene.world.as_pointer()==world_pointer
    assert node_tree_snapshot(scene.world.node_tree)==world_tree
    assert rna_settings(scene.view_settings)==view_settings
    assert rna_settings(scene.cycles)==cycles_settings
    for obj in lamps:
        assert obj.data.as_pointer()==lamp_data_pointers[obj]
        assert rna_settings(obj.data)==lamp_rna[obj]
        assert node_tree_snapshot(obj.data.node_tree)==lamp_nodes[obj]
        assert matrix_delta(obj.matrix_world,lamp_matrices[obj])<1e-6
    assert all(mesh_fingerprint(obj)==soil_fingerprints[obj.name] for obj in meshes)
assert_exact_profile()
out.mkdir(parents=True,exist_ok=True)
scene.render.filepath = str(out/'soil_cover_environment_standard.png')
bpy.ops.render.render(write_still=True)
assert_exact_profile()
assert digest(profile)==args.expect_profile_sha256 and digest(source)==args.expect_soil_sha256
# Exact bytes are copied for the downstream stdlib/Pillow audit; not re-exported.
shutil.copyfile(source,out/'soil_cover.glb')
assert digest(out/'soil_cover.glb')==args.expect_soil_sha256
base_spec = json.loads((args.source_spec or source.parent/'spec.json').read_text())
base_spec.update({'status':'Frozen-profile passive source render; still awaits actual Godot art QA',
                 'renderer_sha256':digest(Path(__file__).resolve()),
                 'profile_blend_sha256':args.expect_profile_sha256,
                 'source_geometry_sha256':args.expect_soil_sha256,
                 'renders':{'environment_standard':{
                     'png':'soil_cover_environment_standard.png',
                     'ground_pivot_pixel':[256,467],
                     'projected_vertex_bounds_px':bounds,
                     'profile_blend':str(profile),
                     'camera_effective_quaternion':list(camera_quaternion)}}})
(out/'spec.json').write_text(json.dumps(base_spec,ensure_ascii=False,indent=2)+'\n')
manifest = {'profile_blend':str(profile),'profile_sha256':args.expect_profile_sha256,
            'source_glb':str(source),'source_sha256':args.expect_soil_sha256,
            'renderer_sha256':digest(Path(__file__).resolve()),'blender_version':bpy.app.version_string,
            'world_name':world.name,'world_node_tree':world_tree,
            'view_settings':view_settings,'cycles_settings':cycles_settings,
            'compositor_render_enabled':scene.render.use_compositing,
            'compositor_actual_node_count':compositor_node_count,
            'source_camera':source_camera,'effective_camera_quaternion':list(camera_quaternion),
            'ground_pivot_pixel':[256,467],'ortho_scale':2.60,
            'framed_camera_matrix_world':matrix_values(camera.matrix_world),
            'lights':lights_manifest,'required_light_types':args.require_light_types,
            'rendered_light_types':sorted(actual_types),'source_rig_exact_after_render':True,
            'profile_file_unchanged':True,'source_glb_unchanged':True,
            'source_scene_meshes_removed':True,'soil_meshes':len(meshes),
            'soil_meshes_materials_transforms_unchanged':True,
            'soil_mesh_fingerprints':soil_fingerprints,
            'projected_vertex_bounds_px':bounds,'contact_shadow_baked':False,
            'png_sha256':digest(out/'soil_cover_environment_standard.png')}
(out/'profile_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('FROZEN_SOIL_PROFILE_MANIFEST',out/'profile_manifest.json',flush=True)
