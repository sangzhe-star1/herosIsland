"""Build the editable r1 passive half-buried-potato soil cover.

Geometry only. Exact lighting is supplied separately by render_frozen_profile.py.
The source never reads temporary artifacts or creates game input/state.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--out',type=Path,default=ROOT/'rendered_geometry')
parser.add_argument('--mound-height',type=float,default=.240)
parser.add_argument('--rear-bias',type=float,default=.100)
parser.add_argument('--front-notch',type=float,default=.150)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
out = args.out.resolve()
if out.exists() and any(out.iterdir()):
    raise ValueError('Use an empty output directory; existing source artifacts are preserved')
out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
asset = bpy.data.objects.new('SoilCover | passive visual only',None)
scene.collection.objects.link(asset)
asset['passive_visual_only'] = True
asset['contact_shadow_baked'] = False
asset['ground_pivot'] = [0.0,0.0,0.0]
soil = bpy.data.materials.new('SoilCover | warm loose earth')
soil.diffuse_color = (.23,.108,.048,1)
soil.use_nodes = True
node = soil.node_tree.nodes['Principled BSDF']
node.inputs['Base Color'].default_value = (.23,.108,.048,1)
node.inputs['Roughness'].default_value = 1.0
node.inputs['Metallic'].default_value = 0.0
right = Vector((7.2,4.3,0)).normalized()
away = Vector((-4.3,7.2,0)).normalized()
def point(x,y,z):
    return right*x+away*y+Vector((0,0,z))

segments,rings = 64,8
vertices = [tuple(point(-.10,args.rear_bias+.04,args.mound_height))]
faces = []
for row in range(1,rings+1):
    t = row/rings
    for column in range(segments):
        angle = math.tau*column/segments
        radius = 1+.135*math.cos(3*angle+.5)+.085*math.sin(5*angle-1.1)
        notch_distance = math.atan2(math.sin(angle+.6),math.cos(angle+.6))
        radius -= args.front_notch*math.exp(-(notch_distance/.58)**2)
        x = -.04-.06*(1-t)+.78*t*radius*math.cos(angle)
        y = args.rear_bias+.04*(1-t)+.425*t*radius*math.sin(angle)
        height = .009+(args.mound_height-.009)*(1-t**1.45)**1.16
        height += .018*math.sin(2*angle+.4)*math.sin(math.pi*t)**1.5
        height += .032*max(0,-math.cos(angle))*math.sin(math.pi*t)
        height += .018*math.cos(5*angle-.7)*math.sin(math.pi*t)
        vertices.append(tuple(point(x,y,height)))
for column in range(segments):
    faces.append((0,1+column,1+(column+1)%segments))
for row in range(rings-1):
    inner = 1+row*segments
    outer = inner+segments
    for column in range(segments):
        following = (column+1)%segments
        faces.append((inner+column,outer+column,outer+following,inner+following))
bottom = len(vertices)
vertices.append(tuple(point(-.04,args.rear_bias,0)))
last = 1+(rings-1)*segments
for column in range(segments):
    faces.append((bottom,last+(column+1)%segments,last+column))
data = bpy.data.meshes.new('SoilCover | shallow irregular mound Mesh')
data.from_pydata(vertices,[],faces)
data.update()
data.materials.append(soil)
for polygon in data.polygons:
    polygon.use_smooth = True
for polygon in list(data.polygons)[-segments:]:
    polygon.use_smooth = False
for edge in data.edges:
    if all(last<=index<last+segments for index in edge.vertices):
        edge.use_edge_sharp = True
mound = bpy.data.objects.new('SoilCover | shallow irregular mound',data)
scene.collection.objects.link(mound)
mound.parent = asset
data.calc_loop_triangles()
assert len(data.loop_triangles)==1024
assert all(triangle.area>=1e-12 for triangle in data.loop_triangles)
assert all(all(math.isfinite(value) for value in vertex.co) for vertex in data.vertices)
bpy.ops.object.select_all(action='DESELECT')
asset.select_set(True)
mound.select_set(True)
bpy.context.view_layer.objects.active = asset
bpy.ops.export_scene.gltf(filepath=str(out/'soil_cover.glb'),export_format='GLB',
    use_selection=True,export_apply=True,export_cameras=False,export_lights=False,
    export_skins=False,export_animations=False)
scene['candidate_status'] = 'Source r1 only; actual harvest art QA pending confirmation'
scene['contact_shadow_baked'] = False
bpy.ops.wm.save_as_mainfile(filepath=str(out/'soil_cover.blend'))
spec = {'status':'Source r1 candidate; actual harvest art QA pending confirmation',
    'asset':'soil_cover','revision':'semantic_r1','blender_version':bpy.app.version_string,
    'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'ground_pivot_world':[0,0,0],'ground_pivot_pixel':[256,467],
    'contact_shadow_baked':False,'shadow_owner':'existing runtime ground mound',
    'geometry':{mound.name:{'vertices':len(data.vertices),'triangles':len(data.loop_triangles),
                           'degenerate_triangles':0,'nonfinite_vertices':0}},
    'geometry_parameters':{'mound_height':args.mound_height,'rear_bias':args.rear_bias,
                           'front_right_notch':args.front_notch,'clod_count':0},
    'integration_suggestion':{'node':'existing HarvestTargetVisual/_cover',
        'ground_anchor_relative_to_target':[0,42],'apparent_width':'crop_size*1.30',
        'normal_width':117.0,'dense_width':93.6,
        'preserve':['Target input/radius','sweep recognizer','uncover alpha/scale','order owner']},
    'render_profile':'../catalog_profile_candidate/inputs/frozen_render_profile.blend',
    'render_profile_sha256':'4facaae15f88401f4f7553f12d4ec1e441e2a9597196b38a0b6a6b6fe2ea5512',
    'renders':{}}
(out/'spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n')
print('SOIL_COVER_R1_GEOMETRY',out,flush=True)
