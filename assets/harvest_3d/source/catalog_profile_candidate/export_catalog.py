"""Re-render the existing catalog with a frozen Blender scene's actual rig.

Self-contained Blender Python; it appends existing asset collections, preserves
their meshes/materials/world transforms, and changes only visibility + render
rig. Default is inspection, never rendering. No Godot or repository mutations.
"""
import argparse
from array import array
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector
from bpy_extras.object_utils import world_to_camera_view

CATALOG = (
    'carrot', 'golden_carrot', 'potato', 'tomato', 'strawberry', 'corn',
    'orange', 'apple', 'peas', 'pumpkin', 'watermelon', 'broccoli',
    'lettuce', 'grape', 'wheat', 'stone', 'bug',
)
REPLACEMENTS = {'carrot', 'golden_carrot'}
GEOMETRY_TYPES = {'MESH', 'CURVE', 'SURFACE', 'FONT'}
SIZE = 512
SPAN = 2.60
PIVOT = (256, 467)


def digest_file(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def serial(value):
    if isinstance(value, (bool, int, float, str)) or value is None:
        return value
    try:
        return [serial(x) for x in value]
    except TypeError:
        return getattr(value, 'name', str(value))


def rna_values(subject):
    result = {}
    for prop in subject.bl_rna.properties:
        if prop.identifier == 'rna_type' or prop.type in {'POINTER', 'COLLECTION'}:
            continue
        try:
            result[prop.identifier] = serial(getattr(subject, prop.identifier))
        except (AttributeError, TypeError, ValueError):
            pass
    return result


def node_tree_values(tree):
    if tree is None:
        return None
    return {
        'nodes': [dict(name=n.name, type=n.bl_idname, properties=rna_values(n),
                       inputs={s.identifier: serial(s.default_value) for s in n.inputs
                               if hasattr(s, 'default_value')}) for n in tree.nodes],
        'links': [dict(source_node=l.from_node.name, source_socket=l.from_socket.identifier,
                       target_node=l.to_node.name, target_socket=l.to_socket.identifier)
                  for l in tree.links],
    }


def geometry_digest(obj):
    h = hashlib.sha256()
    data = obj.data
    if obj.type == 'MESH':
        coordinates = array('f', [0]) * (len(data.vertices) * 3)
        indices = array('i', [0]) * len(data.loops)
        material_indices = array('i', [0]) * len(data.polygons)
        data.vertices.foreach_get('co', coordinates)
        data.loops.foreach_get('vertex_index', indices)
        data.polygons.foreach_get('material_index', material_indices)
        for values in (coordinates, indices, material_indices):
            h.update(values.tobytes())
    else:
        # The catalog also keeps curved stems as native Blender Curve objects.
        # Preserve them without converting or replacing their geometry.
        curves = dict(properties=rna_values(data), splines=[])
        for spline in data.splines:
            curves['splines'].append(dict(properties=rna_values(spline),
                points=[rna_values(p) for p in spline.points],
                bezier_points=[rna_values(p) for p in spline.bezier_points]))
        h.update(json.dumps(curves, sort_keys=True).encode())
    h.update(json.dumps([m.name if m else None for m in data.materials]).encode())
    return h.hexdigest()


def is_source_contact_shadow(obj):
    return (obj.name.startswith('Shadow | ') or
            (obj.type == 'MESH' and any(m and m.name.startswith('Studio | soft contact shadow')
                                       for m in obj.data.materials)))


def append_asset_collections(path, asset_ids, scene):
    names = ['ASSET | ' + asset_id for asset_id in asset_ids]
    with bpy.data.libraries.load(str(path), link=False) as (available, loaded):
        missing = set(names) - set(available.collections)
        if missing:
            raise ValueError('Missing exact asset collections: ' + ', '.join(sorted(missing)))
        loaded.collections = names
    result = {}
    for asset_id, collection in zip(asset_ids, loaded.collections):
        scene.collection.children.link(collection)
        collection.hide_render = True
        # Appended source visibility must not decide which asset is rendered.
        for obj in collection.all_objects:
            obj.hide_render = is_source_contact_shadow(obj)
        result[asset_id] = collection
    return result


def capture_profile(scene, camera, lamps, source, sha):
    world = scene.world
    return {
        'source_blend': str(source), 'sha256': sha, 'scene': scene.name,
        'engine': scene.render.engine,
        'world': None if world is None else {
            'name': world.name, 'properties': rna_values(world),
            'node_tree': node_tree_values(world.node_tree if world.use_nodes else None)},
        'lamps': [dict(name=o.name, matrix_world=serial(o.matrix_world),
                       data=rna_values(o.data),
                       node_tree=node_tree_values(o.data.node_tree if o.data.use_nodes else None))
                  for o in lamps],
        'camera': dict(name=camera.name, matrix_world=serial(camera.matrix_world),
                       shared_rotation_quaternion=serial(camera.matrix_world.to_quaternion()),
                       data=rna_values(camera.data)),
        'view_settings': rna_values(scene.view_settings),
        'display_settings': rna_values(scene.display_settings),
        'cycles': rna_values(scene.cycles),
        'compositor_enabled': bool(scene.render.use_compositing and
                                  (getattr(scene, 'compositing_node_group', None) or
                                   getattr(scene, 'node_tree', None))),
    }


def setup_profile(args):
    if not args.profile_blend:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        return bpy.context.scene, None, None
    path = args.profile_blend.resolve()
    sha = digest_file(path)
    if args.expect_profile_sha256 and sha != args.expect_profile_sha256:
        raise ValueError('Profile .blend SHA does not match the frozen profile')
    if args.render and not args.expect_profile_sha256:
        raise ValueError('Rendering requires an explicit --expect-profile-sha256')
    bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False, use_scripts=False)
    if args.profile_scene:
        scene = bpy.data.scenes.get(args.profile_scene)
        if scene is None:
            raise ValueError('Requested profile scene does not exist')
        bpy.context.window.scene = scene
    else:
        scene = bpy.context.scene
    camera = bpy.data.objects.get(args.camera_name) if args.camera_name else scene.camera
    if camera is None or camera.type != 'CAMERA':
        raise ValueError('Profile scene needs an actual active camera')
    if camera.constraints or camera.animation_data:
        raise ValueError('The shared camera must have a frozen static transform')
    lamps = [o for o in scene.objects if o.type == 'LIGHT' and not o.hide_render]
    if not lamps or any(o.data.type not in {'AREA', 'SUN'} for o in lamps):
        raise ValueError('Frozen catalog profile needs its actual Area/Sun lights')
    if args.require_light_types:
        expected = sorted(args.require_light_types.split(','))
        measured = sorted(o.data.type for o in lamps)
        if measured != expected:
            raise ValueError('Frozen light types differ: ' + repr(measured))
    if scene.world is None:
        raise ValueError('Frozen catalog profile must contain its ambient World')
    compositor = (getattr(scene, 'compositing_node_group', None) or
                  getattr(scene, 'node_tree', None))
    if scene.render.use_compositing and compositor is not None:
        raise ValueError('Profile must use direct RGBA export without a compositor graph')
    if args.require_view_transform and scene.view_settings.view_transform != args.require_view_transform:
        raise ValueError('Profile view transform does not match the requested frozen value')
    if args.require_exposure is not None and abs(scene.view_settings.exposure - args.require_exposure) > 1e-6:
        raise ValueError('Profile exposure does not match the requested frozen value')
    profile = capture_profile(scene, camera, lamps, path, sha)
    keep = set(lamps + [camera])
    matrices = {o: o.matrix_world.copy() for o in keep}
    # Neither the landscape geometry nor sample soil marks can reach the PNGs.
    for obj in list(scene.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    rig = bpy.data.collections.new('CATALOG | frozen profile camera and lamps')
    scene.collection.children.link(rig)
    for obj in keep:
        obj.parent = None
        obj.matrix_world = matrices[obj]
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        rig.objects.link(obj)
    scene.camera = camera
    return scene, camera, profile


def configure_png(scene):
    scene.render.resolution_x = scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = scene.render.pixel_aspect_y = 1.0
    scene.render.film_transparent = True
    scene.render.use_border = False
    scene.render.use_crop_to_border = False
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'


def frame_ground(scene, camera):
    # Keep the source camera's effective orientation and starting translation.
    # Translation in its right/up plane establishes the pixel pivot; no mesh,
    # material, scale or per-asset ortho adjustment is made.
    point = Vector((0, 0, 0))
    rotation = camera.matrix_world.to_quaternion()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = SPAN
    bpy.context.view_layer.update()
    projected = world_to_camera_view(scene, camera, point)
    right = rotation @ Vector((1, 0, 0))
    up = rotation @ Vector((0, 1, 0))
    shift = right * ((projected.x - PIVOT[0] / SIZE) * SPAN)
    shift += up * ((projected.y - (1 - PIVOT[1] / SIZE)) * SPAN)
    framed_matrix = camera.matrix_world.copy()
    framed_matrix.translation += shift
    camera.matrix_world = framed_matrix
    bpy.context.view_layer.update()
    actual = world_to_camera_view(scene, camera, point)
    pixel = (actual.x * SIZE, (1 - actual.y) * SIZE)
    if max(abs(pixel[i] - PIVOT[i]) for i in (0, 1)) > 0.001:
        raise ValueError('Ground pivot calibration failed: ' + repr(pixel))
    return pixel


def projected_mesh_bounds(scene, camera, objects):
    extrema = [float('inf'), float('inf'), float('-inf'), float('-inf')]
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        try:
            for vertex in mesh.vertices:
                p = world_to_camera_view(scene, camera, evaluated.matrix_world @ vertex.co)
                x, y = p.x * SIZE, (1 - p.y) * SIZE
                extrema[0], extrema[1] = min(extrema[0], x), min(extrema[1], y)
                extrema[2], extrema[3] = max(extrema[2], x), max(extrema[3], y)
        finally:
            evaluated.to_mesh_clear()
    return {'bounds_px': extrema,
            'within_canvas': extrema[0] >= 0 and extrema[1] >= 0 and extrema[2] < SIZE and extrema[3] < SIZE}


def alpha_audit(path):
    img = bpy.data.images.load(str(path), check_existing=False)
    width, height = img.size
    pixels = array('f', [0]) * (width * height * 4)
    img.pixels.foreach_get(pixels)
    audits = {}
    # bpy's image row zero is the bottom. Report conventional top-left PNG px.
    for label, threshold in [('nonzero', 0.001), ('visible', 0.05), ('solid', 0.95)]:
        bbox = [width, height, -1, -1]
        edges = dict(top=0, bottom=0, left=0, right=0)
        for y in range(height):
            source_y = height - 1 - y
            for x in range(width):
                if pixels[(source_y * width + x) * 4 + 3] < threshold:
                    continue
                bbox[0], bbox[1] = min(bbox[0], x), min(bbox[1], y)
                bbox[2], bbox[3] = max(bbox[2], x), max(bbox[3], y)
                edges['top'] += y == 0
                edges['bottom'] += y == height - 1
                edges['left'] += x == 0
                edges['right'] += x == width - 1
        audits[label] = {'threshold': threshold,
                         'bbox': None if bbox[2] < 0 else [bbox[0], bbox[1], bbox[2] + 1, bbox[3] + 1],
                         'edge_pixels': edges}
    bpy.data.images.remove(img)
    return dict(size=[width, height], sha256=digest_file(path), alpha=audits,
                solid_edge_free=not any(audits['solid']['edge_pixels'].values()),
                visible_edge_free=not any(audits['visible']['edge_pixels'].values()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-blend', type=Path, required=True)
    parser.add_argument('--carrot-blend', type=Path, required=True)
    parser.add_argument('--source-manifest', type=Path)
    parser.add_argument('--profile-blend', type=Path)
    parser.add_argument('--expect-profile-sha256')
    parser.add_argument('--profile-scene')
    parser.add_argument('--camera-name')
    parser.add_argument('--require-view-transform')
    parser.add_argument('--require-exposure', type=float)
    parser.add_argument('--require-light-types',
                        help='Exact comma-separated frozen light types, e.g. SUN,AREA,AREA.')
    parser.add_argument('--asset', action='append', choices=CATALOG)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--save-blend', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    if args.render and not args.profile_blend:
        parser.error('--render requires --profile-blend with its frozen SHA')
    if args.save_blend and not args.profile_blend:
        parser.error('--save-blend requires --profile-blend')
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=True)
    source_manifest = args.source_manifest or args.source_blend.parent / 'manifest.json'
    manifest = json.loads(source_manifest.read_text())
    if not set(CATALOG).issubset(a['id'] for a in manifest['assets']):
        raise ValueError('Source manifest does not contain the 17 catalog IDs')
    scene, camera, profile = setup_profile(args)
    configure_png(scene)
    asset_map = append_asset_collections(args.source_blend.resolve(), [a for a in CATALOG if a not in REPLACEMENTS], scene)
    asset_map.update(append_asset_collections(args.carrot_blend.resolve(), [a for a in CATALOG if a in REPLACEMENTS], scene))
    bpy.context.view_layer.update()
    actual_pivot = frame_ground(scene, camera) if camera else None
    selected = set(args.asset or CATALOG)
    result = {
        'version': 2, 'status': 'rendered_pending_art_acceptance' if args.render else 'inspection_only',
        'blender_version': bpy.app.version_string, 'catalog_ids': list(CATALOG),
        'source_blend': {'path': str(args.source_blend.resolve()), 'sha256': digest_file(args.source_blend)},
        'carrot_candidate_blend': {'path': str(args.carrot_blend.resolve()), 'sha256': digest_file(args.carrot_blend)},
        'source_manifest': {'path': str(source_manifest.resolve()), 'sha256': digest_file(source_manifest)},
        'render_profile': profile,
        'export_camera': None if camera is None else {
            'matrix_world': serial(camera.matrix_world),
            'shared_rotation_quaternion': serial(camera.matrix_world.to_quaternion()),
            'ortho_scale': camera.data.ortho_scale, 'ground_pivot_px': actual_pivot},
        'contract': dict(size_px=[SIZE, SIZE], ortho_span_m=SPAN, world_origin=[0, 0, 0],
                         ground_pivot_px=list(PIVOT), measured_pivot_px=actual_pivot, transparent=True,
                         contact_shadow_baked=False, runtime_contact_shadow_owner='existing Shapes.ground_shadow',
                         geometry_and_materials_unchanged=True, per_asset_auto_fit=False,
                         original_props_included=False, profile_meshes_or_soil_marks_included=False),
        'assets': [],
    }
    for asset_id in CATALOG:
        collection = asset_map[asset_id]
        shadows = [o for o in collection.all_objects if is_source_contact_shadow(o)]
        objects = [o for o in collection.all_objects if o.type in GEOMETRY_TYPES and not is_source_contact_shadow(o)]
        source_snapshots = {o.name: (geometry_digest(o), serial(o.matrix_world)) for o in objects}
        item = dict(id=asset_id, source='carrot_candidate' if asset_id in REPLACEMENTS else 'original_catalog',
                    collection=collection.name, geometry_objects=len(objects),
                    source_shadow_objects_excluded=[o.name for o in shadows], contact_shadow_baked=False,
                    source_objects=[dict(name=o.name, type=o.type,
                                         vertices=len(getattr(o.data, 'vertices', [])),
                                         polygons=len(getattr(o.data, 'polygons', [])),
                                         splines=len(getattr(o.data, 'splines', [])),
                                         materials=[m.name if m else None for m in o.data.materials],
                                         geometry_sha256=source_snapshots[o.name][0], matrix_world=source_snapshots[o.name][1])
                                    for o in objects])
        collection.hide_render = False
        bpy.context.view_layer.update()
        if camera:
            item['projected_geometry'] = projected_mesh_bounds(scene, camera, objects)
        if args.render and asset_id in selected:
            path = output / 'sprites' / (asset_id + '.png')
            path.parent.mkdir(parents=True, exist_ok=True)
            scene.render.filepath = str(path)
            bpy.ops.render.render(write_still=True)
            item['file'] = str(path.relative_to(output))
            item['png_audit'] = alpha_audit(path)
            item['canvas_gate_passed'] = (item['projected_geometry']['within_canvas'] and
                                          item['png_audit']['visible_edge_free'] and item['png_audit']['solid_edge_free'])
        for obj in objects:
            if source_snapshots[obj.name] != (geometry_digest(obj), serial(obj.matrix_world)):
                raise AssertionError('Source geometry/material assignment/transform changed: ' + obj.name)
        collection.hide_render = True
        result['assets'].append(item)
        print('CATALOG', asset_id, 'meshes', len(objects), 'shadow-excluded', len(shadows),
              'rendered', bool(item.get('file')), 'canvas-gate', item.get('canvas_gate_passed'), flush=True)
    # Flag actual clipping without silently changing physical ratio or camera.
    result['canvas_failures'] = [a['id'] for a in result['assets'] if a.get('canvas_gate_passed') is False]
    result['geometry_projection_failures'] = [a['id'] for a in result['assets']
                                             if a.get('projected_geometry', {}).get('within_canvas') is False]
    result['rendered_assets'] = [a['id'] for a in result['assets'] if a.get('file')]
    result['all_catalog_pngs_rendered'] = len(result['rendered_assets']) == len(CATALOG)
    result['overall_canvas_gate'] = ('not_measured' if not result['rendered_assets'] else
                                    'failed' if result['canvas_failures'] else
                                    'all_rendered_passed' if result['all_catalog_pngs_rendered'] else
                                    'partial_render_passed')
    if args.save_blend:
        editable = output / 'catalog_profile_editable.blend'
        bpy.ops.wm.save_as_mainfile(filepath=str(editable))
        result['editable_blend'] = {'file': editable.name, 'sha256': digest_file(editable)}
    filename = 'manifest.json' if args.render else 'inspection_manifest.json'
    (output / filename).write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print('MANIFEST', output / filename, flush=True)


if __name__ == '__main__':
    main()
