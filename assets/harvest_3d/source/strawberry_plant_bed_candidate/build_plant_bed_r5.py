"""Build a passive toy-farm strawberry rosette and one continuous planting bed.

The fruit stays a separate HarvestTarget.  This script writes only into its
own candidate directory; it never edits runtime art or gameplay files.
"""
import argparse
import hashlib
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--out', type=Path, default=ROOT / 'rendered')
parser.add_argument('--bed-width', type=float, default=8.8)
parser.add_argument('--bed-depth', type=float, default=4.4)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
OUT = args.out.resolve()
OUT.mkdir(parents=True, exist_ok=True)
BED_WIDTH = max(6.0, args.bed_width)
BED_DEPTH = max(3.0, args.bed_depth)
random.seed(73)
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, roughness=.86):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = 0
    return mat


leaf_dark = material('Leaf | garden green', (.115, .325, .055), .88)
leaf_light = material('Leaf | sunlit green', (.19, .415, .095), .88)
vein_mat = material('Leaf | gentle vein', (.235, .46, .12), .9)
stem_mat = material('Crown | deep green', (.075, .205, .035), .9)
grass_dark = material('Bed edge | garden green', (.21, .385, .085), .9)
grass_light = material('Bed edge | young green', (.31, .48, .13), .9)


def _smoothstep(value):
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def _linear_to_srgb(value):
    return (12.92 * value if value <= .0031308
            else 1.055 * (value ** (1.0 / 2.4)) - .055)


def _periodic_noise(grids, u, v):
    total = 0.0
    weights = (.34, .27, .19, .13, .07)
    for grid, weight in zip(grids, weights):
        grid_h = len(grid)
        grid_w = len(grid[0])
        x = (u % 1.0) * grid_w
        y = (v % 1.0) * grid_h
        x0 = int(math.floor(x)) % grid_w
        y0 = int(math.floor(y)) % grid_h
        x1 = (x0 + 1) % grid_w
        y1 = (y0 + 1) % grid_h
        tx = _smoothstep(x - math.floor(x))
        ty = _smoothstep(y - math.floor(y))
        top = grid[y0][x0] * (1 - tx) + grid[y0][x1] * tx
        bottom = grid[y1][x0] * (1 - tx) + grid[y1][x1] * tx
        total += (top * (1 - ty) + bottom * ty) * weight
    return total


def make_soil_texture_material():
    """Create a subtle, repeat-free loam map that exports inside the GLB."""
    texture_rng = random.Random(20261003)
    grids = []
    for grid_w, grid_h in ((4, 2), (8, 4), (16, 8), (32, 16), (64, 32)):
        grids.append([[texture_rng.uniform(-1.0, 1.0) for _ in range(grid_w)]
                      for _ in range(grid_h)])
    image_width, image_height = 512, 256
    base_color = (.185, .155, .130)
    pixels = []
    for y in range(image_height):
        v = (y + .5) / image_height
        for x in range(image_width):
            u = (x + .5) / image_width
            mottling = _periodic_noise(grids, u, v)
            grain = texture_rng.uniform(-1.0, 1.0)
            shade = 1.0 + .15 * mottling + .025 * grain
            soil_sample = [base_color[0] * shade,
                           base_color[1] * (shade + .006),
                           base_color[2] * (shade + .012)]
            radius = math.sqrt((2.0 * u - 1.0) ** 2 + (2.0 * v - 1.0) ** 2)
            meadow_mix = _smoothstep((radius - .72) / .34)
            meadow_color = (.31, .42, .24)
            final_color = [soil_sample[channel] * (1.0 - meadow_mix)
                           + meadow_color[channel] * meadow_mix
                           for channel in range(3)]
            pixels.extend((
                _linear_to_srgb(max(.0, min(1.0, final_color[0]))),
                _linear_to_srgb(max(.0, min(1.0, final_color[1]))),
                _linear_to_srgb(max(.0, min(1.0, final_color[2]))),
                1.0,
            ))
    image = bpy.data.images.new(
        'StrawberryBed | muted loam color texture',
        width=image_width, height=image_height, alpha=False, float_buffer=False)
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(OUT / 'strawberry_loam_texture.png')
    image.file_format = 'PNG'
    image.save()
    image_path = str(image.filepath_raw)
    bpy.data.images.remove(image)
    # Reopen the saved sRGB image so the Blender review and exported GLTF use
    # the same color-managed pixels.
    image = bpy.data.images.load(image_path, check_existing=False)
    image.pack()

    mat = material('Soil | GLTF muted mottled loam', (1.0, 1.0, 1.0), .96)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    uv_node = nodes.new('ShaderNodeTexCoord')
    texture_node = nodes.new('ShaderNodeTexImage')
    texture_node.image = image
    texture_node.interpolation = 'Linear'
    texture_node.extension = 'EXTEND'
    links.new(uv_node.outputs['UV'], texture_node.inputs['Vector'])
    links.new(texture_node.outputs['Color'], bsdf.inputs['Base Color'])
    return mat


soil_texture = make_soil_texture_material()


class MeshBuilder:
    def __init__(self):
        self.vertices = []
        self.faces = []
        self.materials = []
        self.face_materials = []

    def add_material(self, mat):
        if mat not in self.materials:
            self.materials.append(mat)
        return self.materials.index(mat)

    def face(self, indices, mat):
        self.faces.append(tuple(indices))
        self.face_materials.append(self.add_material(mat))

    def tube(self, points, radii, mat, sides=8):
        points = [Vector(p) for p in points]
        if len(points) < 2:
            return
        base = len(self.vertices)
        for i, p in enumerate(points):
            tangent = (points[min(i + 1, len(points) - 1)]
                       - points[max(i - 1, 0)]).normalized()
            ref = Vector((0, 1, 0)) if abs(tangent.y) < .91 else Vector((1, 0, 0))
            across = tangent.cross(ref).normalized()
            other = tangent.cross(across).normalized()
            radius = radii[i] if hasattr(radii, '__len__') else radii
            for j in range(sides):
                angle = 2 * math.pi * j / sides
                q = p + radius * (math.cos(angle) * across + math.sin(angle) * other)
                self.vertices.append(tuple(q))
        for i in range(len(points) - 1):
            for j in range(sides):
                self.face((base + i * sides + j,
                           base + i * sides + (j + 1) % sides,
                           base + (i + 1) * sides + (j + 1) % sides,
                           base + (i + 1) * sides + j), mat)
        self.face(tuple(base + j for j in reversed(range(sides))), mat)
        self.face(tuple(base + (len(points) - 1) * sides + j
                        for j in range(sides)), mat)

    def create(self, name, parent=None):
        mesh = bpy.data.meshes.new(name + ' Mesh')
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.validate(clean_customdata=True)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        for mat in self.materials:
            mesh.materials.append(mat)
        for face, index in zip(mesh.polygons, self.face_materials):
            face.material_index = index
            face.use_smooth = True
        if parent:
            obj.parent = parent
        return obj


def make_leaflet(builder, base, direction, length, width, mat,
                 lift=.095, droop=.045, phase=0.0,
                 sections=22, include_vein=True, compact=False):
    """Create a plump, rounded, gently scalloped strawberry leaflet."""
    base = Vector(base)
    direction = Vector((direction[0], direction[1], 0)).normalized()
    side = Vector((-direction.y, direction.x, 0))
    first = len(builder.vertices)
    sections = 22
    # Four columns make a cupped blade; edge tufts use a cheaper three-column mesh.
    across_fractions = (-1.0, 0.0, 1.0) if compact else (-1.0, -.34, .34, 1.0)
    for i in range(sections + 1):
        t = .02 + .96 * i / sections
        envelope = (max(0.0, math.sin(math.pi * t)) ** .62)
        envelope *= .91 + .09 * math.sin(math.pi * t * 2 + phase)
        scallop = .022 * math.cos(12 * math.pi * t + phase) * math.sin(math.pi * t) ** .35
        center = base + direction * (length * t)
        center.z += lift * math.sin(math.pi * t) - droop * t * t
        for col, fraction in enumerate(across_fractions):
            f = abs(fraction)
            w = width * envelope * (1 + scallop if f > .9 else 1)
            z_cup = .018 * f * f * envelope
            p = center + side * (fraction * w)
            p.z -= z_cup
            if col in (1, 2):
                p.z += .012 * envelope
            builder.vertices.append(tuple(p))
    for i in range(sections):
        for col in range(len(across_fractions) - 1):
            a = first + i * len(across_fractions) + col
            b = a + len(across_fractions)
            builder.face((a, b, b + 1, a + 1), mat)
    # A single low raised vein ends before the tip, so it reads as a leaf rather
    # than a wire.  Its ends sit inside the blade to avoid floating highlights.
    if include_vein:
        vein = []
        for i in range(7):
            t = .10 + .73 * i / 6
            p = base + direction * (length * t)
            p.z += lift * math.sin(math.pi * t) - droop * t * t + .026 * math.sin(math.pi * t)
            vein.append(tuple(p))
        builder.tube(vein, [.0065 - .0035 * i / 6 for i in range(7)], vein_mat, 5)


def make_strawberry_plant(name='StrawberryPlant'):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    root.empty_display_type = 'CIRCLE'
    root.empty_display_size = .12
    builder = MeshBuilder()
    # A compact, softly domed crown rests just above the ground pivot.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=1,
                                         location=(0, 0, .105))
    crown = bpy.context.object
    crown.name = name + ' | crown'
    crown.scale = (.115, .105, .085)
    crown.data.materials.append(stem_mat)
    for polygon in crown.data.polygons:
        polygon.use_smooth = True
    crown.parent = root

    # Five compound fans frame one clear forward fruit slot.  Each fan has three
    # rounded leaflets and a curved petiole, keeping the plant low and readable.
    fan_specs = [
        (-2.72, .48, .145, .115),
        (-1.54, .43, .135, .115),
        (-.25, .50, .155, .125),
        (.98, .43, .135, .105),
        (2.23, .47, .145, .115),
    ]
    for fan_index, (angle, length, width, z_lift) in enumerate(fan_specs):
        direction = Vector((math.cos(angle), math.sin(angle), 0))
        start = Vector((0, 0, .115))
        fan_base = start + direction * .105
        fan_base.z += .025
        petiole_end = fan_base + direction * .095
        petiole_end.z += .035
        points = [start,
                  start.lerp(fan_base, .45) + Vector((0, 0, .035)),
                  petiole_end]
        builder.tube(points, [.015, .012, .009], stem_mat, 7)

        # Main leaflet points outward; side leaflets open in a friendly shallow V.
        leaflet_specs = [
            (direction, length * .78, width),
            (Vector((math.cos(angle + .82), math.sin(angle + .82), 0)),
             length * .56, width * .78),
            (Vector((math.cos(angle - .82), math.sin(angle - .82), 0)),
             length * .56, width * .78),
        ]
        for leaf_index, (leaf_dir, leaf_length, leaf_width) in enumerate(leaflet_specs):
            origin = fan_base + direction * (.035 if leaf_index == 0 else .01)
            origin.z += .018
            make_leaflet(builder, origin, leaf_dir, leaf_length, leaf_width,
                         leaf_light if (fan_index + leaf_index) % 4 == 0 else leaf_dark,
                         lift=z_lift + random.uniform(-.012, .012),
                         droop=.040 + .008 * (leaf_index == 0),
                         phase=fan_index * .73 + leaf_index * 1.4)

    # A restrained runner trails on the soil edge; it ends in two small leaves,
    # avoiding the flower-pot or decorative-prop look.
    runner = [(-.03, -.02, .10), (-.13, -.13, .055), (-.29, -.20, .045),
              (-.43, -.19, .043)]
    builder.tube(runner, [.010, .009, .007, .004], stem_mat, 6)
    for side_sign in (-1, 1):
        d = Vector((.78, side_sign * .63, 0)).normalized()
        make_leaflet(builder, (-.43, -.19 + side_sign * .018, .048), d,
                     .115, .040, leaf_light, lift=.028, droop=.018,
                     phase=side_sign * .9)

    # A short raised peduncle reaches the front edge, where the ripe berry can
    # remain readable above the low rosette leaves.
    fruit_slot_local = (.05, -.365, .235)
    builder.tube([(0.0, -.025, .145), (.012, -.12, .205),
                  (.030, -.225, .275), (.047, -.325, .355),
                  (fruit_slot_local[0], fruit_slot_local[1], .375)],
                 [.015, .012, .010, .008, .006], stem_mat, 7)

    body = builder.create(name + ' | foliage and petioles', root)
    body.location = (0, 0, 0)
    # This locator is intentionally empty. Runtime HarvestTarget supplies the
    # actual fruit and owns its touch bounds, maturity, removal and delivery.
    slot = bpy.data.objects.new('FruitSlot | strawberry GLB center', None)
    bpy.context.collection.objects.link(slot)
    slot.parent = root
    slot.location = fruit_slot_local
    slot.empty_display_type = 'SPHERE'
    slot.empty_display_size = .045
    root['ground_pivot_m'] = [0, 0, 0]
    root['fruit_slot_local_m'] = list(slot.location)
    root['interaction_owner'] = 'HarvestTarget'
    return root


def make_bed(width=BED_WIDTH, depth=BED_DEPTH):
    """Create a thin, open loam surface with a very shallow broad rise."""
    obj_root = bpy.data.objects.new('StrawberryBed', None)
    bpy.context.collection.objects.link(obj_root)
    obj_root.empty_display_type = 'CIRCLE'
    obj_root.empty_display_size = .2
    builder = MeshBuilder()
    ring_count = 96
    rings = []
    # The open soil surface starts at meadow height and rises only 9cm across
    # almost the full bed. No closed bottom, skirt, hard color ring, pads, or strips.
    half_width, half_depth = width * .5, depth * .5
    profiles = [
        (1.000, 1.000, .001), (.985, .990, .002),
        (.960, .970, .005), (.925, .940, .011),
        (.880, .900, .020), (.820, .840, .031),
        (.740, .760, .044), (.640, .670, .057),
        (.520, .560, .069), (.390, .430, .079),
        (.250, .290, .086), (.120, .150, .090),
    ]
    for ring_index, (rx, ry, z) in enumerate(profiles):
        row = []
        for i in range(ring_count):
            a = 2 * math.pi * i / ring_count
            irregular = (1 + .018 * math.sin(5 * a + .4)
                         + .010 * math.sin(9 * a - .7)
                         + .006 * math.cos(13 * a + .8))
            x = half_width * rx * irregular * math.copysign(abs(math.cos(a)) ** .78, math.cos(a))
            y = half_depth * ry * irregular * math.copysign(abs(math.sin(a)) ** .78, math.sin(a))
            progress = ring_index / (len(profiles) - 1)
            zwave = .002 * math.sin(7 * a + .3) * progress
            soil_wave = (.004 * math.sin(1.2 * x + .8)
                         * math.cos(1.55 * y - .5)
                         * math.sin(math.pi * progress))
            row.append(len(builder.vertices))
            builder.vertices.append((x, y, z + zwave + soil_wave))
        rings.append(row)

    # One continuous surface rolls from field level to a low crown.
    for k in range(len(rings) - 1):
        outer, inner = rings[k], rings[k + 1]
        for j in range(ring_count):
            builder.face((outer[j], outer[(j + 1) % ring_count],
                          inner[(j + 1) % ring_count], inner[j]), soil_texture)
    center = len(builder.vertices)
    builder.vertices.append((0, 0, .090))
    for j in range(ring_count):
        builder.face((rings[-1][j], rings[-1][(j + 1) % ring_count], center), soil_texture)
    bed_mesh = builder.create('StrawberryBed | continuous loam', obj_root)
    bed_mesh.location = (0, 0, 0)
    uv_layer = bed_mesh.data.uv_layers.new(name='UVMap')
    for loop in bed_mesh.data.loops:
        point = bed_mesh.data.vertices[loop.vertex_index].co
        uv_layer.data[loop.index].uv = (point.x / width + .5, point.y / depth + .5)
    obj_root['bed_dimensions_m'] = [width, depth, .090]
    obj_root['surface'] = 'single-sided loam surface, ground-level edge, shallow broad crown'

    # Sparse, nearly horizontal leaf pairs tuck into the open soil perimeter.
    edge = MeshBuilder()
    grass_clusters = 8
    for i in range(grass_clusters):
        a = 2 * math.pi * i / grass_clusters + random.uniform(-.035, .035)
        edge_scale = .992 + random.uniform(-.004, .004)
        origin_x = half_width * edge_scale * math.copysign(abs(math.cos(a)) ** .78, math.cos(a))
        origin_y = half_depth * edge_scale * math.copysign(abs(math.sin(a)) ** .78, math.sin(a))
        origin = Vector((origin_x, origin_y,
                         bed_surface_height(bed_mesh, origin_x, origin_y) + .001))
        radial = Vector((math.cos(a), math.sin(a), 0))
        tangent = Vector((-math.sin(a), math.cos(a), 0))
        for j in range(2):
            d = (radial * random.uniform(.12, .24)
                 + tangent * random.uniform(-.85, .85)
                 + Vector((0, 0, random.uniform(.08, .14)))).normalized()
            edge_leaf = leaf_light if (i + j) % 4 == 0 else grass_dark
            make_leaflet(edge, origin + Vector((0, 0, j * .012)), d,
                         random.uniform(.075, .105), random.uniform(.026, .035),
                         edge_leaf, lift=.010, droop=.008,
                         phase=i * .37 + j, sections=6,
                         include_vein=False, compact=True)
    fringe = edge.create('StrawberryBed | sparse edge fringe', obj_root)
    fringe.location = (0, 0, 0)
    return obj_root, bed_mesh


def set_render(scene, camera_target=(0, 0, .7), width=1280, height=720, scale=1.0):
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = 'RGBA'
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'Medium High Contrast'
    scene.view_settings.exposure = -.15
    scene.view_settings.gamma = 1.0

    cam_data = bpy.data.cameras.new('Review camera')
    camera = bpy.data.objects.new('Review camera', cam_data)
    scene.collection.objects.link(camera)
    camera.location = (6.7, -9.8, 7.8)
    target = Vector(camera_target)
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 10.0 * scale
    scene.camera = camera

    world = bpy.data.worlds.new('Soft toy-farm world')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (.55, .68, .79, 1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = .42
    scene.world = world

    light_data = bpy.data.lights.new('Large soft sun', 'AREA')
    light = bpy.data.objects.new('Large soft sun', light_data)
    scene.collection.objects.link(light)
    light.location = (-3.5, -4.0, 7.5)
    light_data.energy = 520
    light_data.shape = 'DISK'
    light_data.size = 5.0
    light.rotation_euler = (Vector((0, 0, .4)) - light.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.resolution_percentage = 100


def export_selection(path, objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
        for child in obj.children_recursive:
            child.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB',
        use_selection=True, export_apply=True, export_cameras=False,
        export_lights=False, export_animations=False,
        export_skins=False, export_materials='EXPORT')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def bed_surface_height(bed_mesh, x, y):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = bed_mesh.evaluated_get(depsgraph)
    hit, location, _normal, _face = evaluated.ray_cast(
        Vector((x, y, 2.0)), Vector((0.0, 0.0, -1.0)))
    return location.z if hit else 0.0


def add_preview_ground():
    ground_mat = material('Review only | meadow', (.31, .42, .24), 1.0)
    bpy.ops.mesh.primitive_plane_add(size=100.0, location=(0.0, 0.0, -0.012))
    ground = bpy.context.object
    ground.name = 'Review only | meadow floor'
    ground.data.materials.append(ground_mat)


plant = make_strawberry_plant()
bed, bed_mesh = make_bed()
plant_glb = OUT / 'strawberry_plant.glb'
bed_glb = OUT / 'strawberry_bed.glb'
export_selection(plant_glb, [plant])
export_selection(bed_glb, [bed])

# Preview a three-row harvest area. Each body root is placed on the actual bed
# mesh at its grid point; these extra plants and fruit markers are review-only.
preview_roots = []
column_positions = [BED_WIDTH * fraction for fraction in (-.36, -.18, 0, .18, .36)]
row_positions = [BED_DEPTH * fraction for fraction in (-.25, 0, .25)]
for row_index, y in enumerate(row_positions):
    for column_index, x in enumerate(column_positions):
        if abs(x) < 0.001 and abs(y) < 0.001:
            preview_plant = plant
        else:
            preview_plant = make_strawberry_plant(
                f'Review plant r{row_index + 1} c{column_index + 1}')
        preview_plant.location = (x, y, bed_surface_height(bed_mesh, x, y) + .002)
        preview_roots.append(preview_plant)

scene = bpy.context.scene
add_preview_ground()
set_render(scene, camera_target=(0, 0, .72), scale=1.08)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'strawberry_plant_bed.blend'))
scene.render.filepath = str(OUT / 'strawberry_plant_bed_review.png')
bpy.ops.render.render(write_still=True)

# These berries visualize the named slots only. The plant GLB has no fruit mesh.
marker_mat = material('Review only | strawberry slot marker', (.78, .045, .035), .82)
markers = []
for preview_plant in preview_roots:
    slot = next((obj for obj in preview_plant.children_recursive
                 if obj.name.split('.')[0] == 'FruitSlot | strawberry GLB center'), None)
    if slot is None:
        continue
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16, ring_count=10, radius=.145,
        location=slot.matrix_world.translation)
    marker = bpy.context.object
    marker.name = 'Review only | berry slot marker'
    marker.scale = (.86, .86, 1.12)
    marker.data.materials.append(marker_mat)
    for polygon in marker.data.polygons:
        polygon.use_smooth = True
    markers.append(marker)
scene.render.filepath = str(OUT / 'strawberry_plant_bed_with_slot_review.png')
bpy.ops.render.render(write_still=True)
for marker in markers:
    bpy.data.objects.remove(marker, do_unlink=True)

plant_meshes = [obj for obj in plant.children_recursive if obj.type == 'MESH']
bed_meshes = [obj for obj in bed.children_recursive if obj.type == 'MESH']
body_slot = next(obj for obj in plant.children_recursive
                 if obj.name.split('.')[0] == 'FruitSlot | strawberry GLB center')
plant_triangles = sum(sum(max(0, len(face.vertices) - 2) for face in obj.data.polygons)
                      for obj in plant_meshes)
bed_triangles = sum(sum(max(0, len(face.vertices) - 2) for face in obj.data.polygons)
                    for obj in bed_meshes)

manifest = {
    'status': 'isolated source candidate; not adopted by runtime or formal page',
    'generator': Path(__file__).name,
    'blender_version': bpy.app.version_string,
    'plant': {
        'file': 'strawberry_plant.glb',
        'ground_pivot_m': [0, 0, 0],
        'fruit_slot_node': 'FruitSlot | strawberry GLB center',
        'fruit_slot_local_m': [round(float(v), 5) for v in body_slot.location],
        'interaction_owner': 'HarvestTarget',
        'fruit_geometry_exported': False,
        'mesh_primitive_count': len(plant_meshes),
        'triangle_estimate': plant_triangles,
        'sha256': sha(OUT / 'strawberry_plant.glb'),
    },
    'bed': {
        'file': 'strawberry_bed.glb',
        'texture_file': 'strawberry_loam_texture.png',
        'texture_sha256': sha(OUT / 'strawberry_loam_texture.png'),
        'dimensions_m': [BED_WIDTH, BED_DEPTH, .090],
        'max_surface_height_m': .090,
        'closed_bottom_or_skirt': False,
        'edge_transition': 'open ground-level edge with eight short two-leaf overlaps',
        'texture_edge_blend': 'low-contrast soil mottling fades to meadow green near the perimeter',
        'continuous_single_mound': True,
        'mesh_primitive_count': len(bed_meshes),
        'triangle_estimate': bed_triangles,
        'per_target_pads_or_overlay_strips': False,
        'sha256': sha(OUT / 'strawberry_bed.glb'),
    },
    'preview': {
        'plant_count': len(preview_roots),
        'layout': 'five columns by three rows; plants are positioned by bed-mesh ray hits',
        'fruit_slot_markers': len(markers),
        'markers_exported': False,
    },
    'review': 'r5 Blender-only candidate; actual Godot page screenshot is still required',
}
(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('STRAWBERRY_PLANT_CANDIDATE', OUT / 'manifest.json')
