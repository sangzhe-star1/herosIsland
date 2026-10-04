import bpy, bmesh, math, random
from pathlib import Path
from mathutils import Vector

SOURCE = Path('/private/tmp/heroes-island-toy-farm-v30/tomato_harvest_editable.blend')
OUT = Path('/private/tmp/heroes-island-toy-farm-parallel-v33')
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene = bpy.context.scene
rng = random.Random(3101)

def mat(name):
    return bpy.data.materials[name]

leaf_mat = mat('Leaf | garden green')
leaf_mat.diffuse_color = (0.24, 0.48, 0.075, 1.0)
leaf_bsdf = next(n for n in leaf_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
leaf_bsdf.inputs['Base Color'].default_value = (0.24, 0.48, 0.075, 1.0)
leaf_bsdf.inputs['Roughness'].default_value = 0.78
soil_mat = mat('Soil | warm loam')
straw_mat = mat('Basket | honey straw')

# Warm up the subtle, seamless soil albedo while retaining its existing texture
# and rough PBR response.
soil = bpy.data.materials['Soil | warm loam']
image_node = next(n for n in soil.node_tree.nodes if n.type == 'TEX_IMAGE')
soil_image = image_node.image
pixels = list(soil_image.pixels[:])
for i in range(0, len(pixels), 4):
    pixels[i] = min(1.0, pixels[i] * 1.48)
    pixels[i + 1] = min(1.0, pixels[i + 1] * 1.72)
    pixels[i + 2] = min(1.0, pixels[i + 2] * 2.0)
soil_image.pixels.foreach_set(pixels)
soil_image.filepath_raw = str(OUT / 'soil_albedo.png')
soil_image.file_format = 'PNG'
soil_image.save()
soil_image.pack()

# The preview ground uses the same warm cream as the reference instead of the
# gray studio sweep used for geometry checks.
preview_ground = bpy.data.materials['Preview ground']
preview_ground.diffuse_color = (0.98, 0.86, 0.72, 1.0)
preview_bsdf = next(n for n in preview_ground.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
preview_bsdf.inputs['Base Color'].default_value = (0.98, 0.86, 0.72, 1.0)
preview_bsdf.inputs['Roughness'].default_value = 0.96
world_bg = scene.world.node_tree.nodes['Background']
world_bg.inputs['Color'].default_value = (0.82, 0.70, 0.56, 1.0)
world_bg.inputs['Strength'].default_value = 0.55

def ico_cluster_object(name, pieces, material, subdivisions=1):
    """Build many low-poly icospheres into one mesh/material primitive."""
    template = bmesh.new()
    bmesh.ops.create_icosphere(template, subdivisions=subdivisions, radius=1.0)
    template.verts.ensure_lookup_table()
    template.faces.ensure_lookup_table()
    unit_verts = [v.co.copy() for v in template.verts]
    unit_faces = [tuple(v.index for v in f.verts) for f in template.faces]
    template.free()

    verts = []
    faces = []
    for center, scale, angle in pieces:
        ca, sa = math.cos(angle), math.sin(angle)
        base = len(verts)
        sx, sy, sz = scale
        for p in unit_verts:
            x, y = p.x * sx, p.y * sy
            verts.append((center[0] + ca*x - sa*y,
                          center[1] + sa*x + ca*y,
                          center[2] + p.z*sz))
        faces.extend(tuple(base + i for i in f) for f in unit_faces)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj

def join_into(target, source):
    bpy.ops.object.select_all(action='DESELECT')
    target.select_set(True)
    source.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.join()

# Round the previously thin, broken grass lip with a single merged clump mesh.
bed = bpy.data.objects['GardenBed | static geometry']
# Radially remap the ellipse to a superellipse (rounded rectangle) while keeping
# its existing height profile, soil texture and material assignments.
for vertex in bed.data.vertices:
    x, y = vertex.co.x, vertex.co.y
    nx, ny = x / 2.84, y / 1.645
    radius = math.hypot(nx, ny)
    angle = math.atan2(ny, nx)
    c, sn = math.cos(angle), math.sin(angle)
    px = math.copysign(abs(c) ** 0.50, c)
    py = math.copysign(abs(sn) ** 0.50, sn)
    vertex.co.x = radius * 2.84 * px
    vertex.co.y = radius * 1.645 * py
border_puffs = []
for i in range(48):
    a = math.tau * (i + rng.uniform(-0.18, 0.18)) / 48.0
    c, sn = math.cos(a), math.sin(a)
    rx = 2.69 + rng.uniform(-0.09, 0.09)
    ry = 1.48 + rng.uniform(-0.08, 0.08)
    center = (rx * math.copysign(abs(c) ** 0.50, c),
              ry * math.copysign(abs(sn) ** 0.50, sn),
              0.255 + rng.uniform(-0.025, 0.035))
    size = rng.uniform(0.235, 0.315)
    border_puffs.append((center,
                         (size * rng.uniform(0.95, 1.30),
                          size * rng.uniform(0.82, 1.18),
                          size * rng.uniform(0.74, 1.02)),
                         a + rng.uniform(-0.3, 0.3)))
puff_obj = ico_cluster_object('Grass edge | soft rounded clumps', border_puffs, leaf_mat, subdivisions=2)
join_into(bed, puff_obj)

# Scatter a restrained set of hand-sized, rounded loam clods on the exposed bed.
# Each cast follows the real bed surface and rejects the green rim.
clods = []
accepted = []
attempts = 0
while len(clods) < 76 and attempts < 1600:
    attempts += 1
    x = rng.uniform(-2.36, 2.36)
    y = rng.uniform(-1.20, 1.20)
    if (abs(x / 2.42) ** 4 + abs(y / 1.28) ** 4) > 0.84:
        continue
    if any((x-px)**2 + (y-py)**2 < 0.16**2 for px, py in accepted):
        continue
    hit, loc, normal, face_index = bed.ray_cast((x, y, 3.0), (0, 0, -1))
    if not hit or bed.data.polygons[face_index].material_index != 1:
        continue
    # Keep the stem bases clear so the clods remain soil detail, not clutter.
    if any((x-cx)**2 + (y-cy)**2 < 0.30**2
           for cx, cy in [(-1.42, -0.32), (-0.02, -0.43), (1.34, -0.22)]):
        continue
    radius = rng.uniform(0.060, 0.105)
    center = (loc.x, loc.y, loc.z + radius * 0.38)
    clods.append((center,
                  (radius * rng.uniform(0.85, 1.25),
                   radius * rng.uniform(0.65, 1.05),
                   radius * rng.uniform(0.45, 0.82)),
                  rng.uniform(0, math.tau)))
    accepted.append((x, y))
clod_obj = ico_cluster_object('Soil | low contrast rounded clods', clods, soil_mat, subdivisions=1)
join_into(bed, clod_obj)

def curved_leaf_mesh(name, specs, material):
    verts, faces = [], []
    rows, across = 14, 7
    for base, direction, length, width, lift, wave in specs:
        dx, dy = direction
        mag = math.hypot(dx, dy)
        dx, dy = dx/mag, dy/mag
        side_x, side_y = -dy, dx
        first = len(verts)
        for i in range(rows+1):
            t = i / rows
            env = max(0.0, math.sin(math.pi*t)) ** 0.76
            env *= 1.0 + wave*math.sin(8.0*math.pi*t)
            cx = base[0] + dx*length*t
            cy = base[1] + dy*length*t
            cz = base[2] + length*(lift*t + 0.10*math.sin(math.pi*t))
            for j in range(across+1):
                u = j/across*2.0 - 1.0
                x = cx + side_x*(width*env*u)
                y = cy + side_y*(width*env*u)
                z = cz + width*0.22*env*(1.0-u*u)
                verts.append((x,y,z))
        for i in range(rows):
            for j in range(across):
                a = first + i*(across+1) + j
                faces.append((a,a+1,a+across+2,a+across+1))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    obj.modifiers.new('Soft leaf thickness', 'SOLIDIFY').thickness = 0.018
    return obj

# Broad leaves rise and spread behind each tomato row. Fruit anchor locations
# and 48–72px silhouette windows remain unobstructed from the preview camera.
leaf_specs = [
    ((-.12,.10,.36),(-1.0,.25),.78,.30,.34,.05),
    (( .13,.13,.38),( 1.0,.24),.80,.30,.32,.08),
    ((-.25,.26,.55),(-.9,.50),.78,.31,.38,.08),
    (( .24,.29,.59),( .9,.45),.80,.31,.35,.10),
    ((-.12,.42,.73),(-.35,1.0),.72,.30,.36,.08),
    (( .13,.44,.77),( .35,1.0),.72,.30,.38,.06),
    ((-.43,.18,.55),(-1.0,.2),.66,.28,.34,.10),
    (( .44,.20,.63),( 1.0,.2),.68,.29,.32,.08),
    ((-.24,.35,.93),(-.9,.45),.74,.30,.36,.06),
    (( .25,.39,.98),( .9,.45),.74,.30,.36,.08),
    ((-.12,.48,1.18),(-.25,1.0),.72,.29,.36,.07),
    (( .12,.51,1.22),( .25,1.0),.70,.29,.37,.06),
    ((-.40,.32,1.31),(-1.0,.35),.62,.27,.35,.10),
    (( .41,.35,1.36),( 1.0,.32),.62,.27,.34,.09),
]
for plant_name in ('Plant01', 'Plant02', 'Plant03'):
    plant = bpy.data.objects[plant_name]
    foliage = bpy.data.objects[plant_name + ' | static geometry']
    leaves = curved_leaf_mesh(plant_name + ' | curved broad leaf canopy', leaf_specs, leaf_mat)
    bpy.context.scene.collection.objects.link(leaves)
    leaves.parent = plant
    leaves.location = (0, 0, 0)
    join_into(foliage, leaves)

# Enlarge the hand-woven basket slightly while leaving the stakes, which are
# joined below in world space, at their existing crop-relative positions.
basket_mesh = bpy.data.objects['Basket | static geometry']
for vertex in basket_mesh.data.vertices:
    vertex.co.x *= 1.12
    vertex.co.y *= 1.12
    vertex.co.z *= 1.05

# Warm wooden support stakes behind each vine. Reuse the basket's straw material
# and merge them into the existing basket mesh/material primitive.
stake_parts = []
for name in ('Plant01', 'Plant02', 'Plant03'):
    plant = bpy.data.objects[name]
    world = plant.matrix_world.translation
    x, y = world.x, world.y + 0.43
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.047, depth=2.10,
        end_fill_type='NGON', location=(x, y, 1.05))
    stake = bpy.context.object
    stake.name = name + ' | simple garden stake'
    stake.data.materials.append(straw_mat)
    for poly in stake.data.polygons:
        poly.use_smooth = True
    stake_parts.append(stake)
basket_mesh = bpy.data.objects['Basket | static geometry']
bpy.ops.object.select_all(action='DESELECT')
basket_mesh.select_set(True)
for stake in stake_parts:
    stake.select_set(True)
bpy.context.view_layer.objects.active = basket_mesh
bpy.ops.object.join()

# Save two review compositions at native target sizes.
camera = scene.camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '8'
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
for width, height, scale, filename in (
    (1280, 720, 8.0, 'tomato_harvest_16x9.png'),
    (960, 720, 7.2, 'tomato_harvest_4x3.png'),
):
    camera.data.ortho_scale = scale
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.filepath = str(OUT / filename)
    bpy.ops.render.render(write_still=True)

scene['review_note'] = (
    'Parallel v33 exploration: warm cream studio background, rounded-rectangle bed, curved leaf canopy, '
    'low contrast loam clods, broader leaf canopy with independent target windows. '
    'Static Blender candidate only; not integrated into gameplay.'
)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'tomato_harvest_editable.blend'))
bpy.ops.object.select_all(action='DESELECT')
root = bpy.data.objects['Root']
asset_objects = [root] + list(root.children_recursive)
for obj in asset_objects:
    if obj.type in {'EMPTY', 'MESH'}:
        obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=str(OUT / 'tomato_harvest_editable.glb'),
    export_format='GLB', use_selection=True, export_cameras=False,
    export_lights=False, export_materials='EXPORT', export_yup=True,
    export_skins=False, export_animations=False,
)
print('ASSET_OUTPUT', OUT)
print('MESH_OBJECTS', sum(1 for o in asset_objects if o.type == 'MESH'))
print('TRIANGLES', sum(len(p.vertices)-2 for o in asset_objects if o.type == 'MESH' for p in o.data.polygons))
print('TARGET_MESHES', sum(1 for o in asset_objects if o.type == 'MESH' and o.name.startswith('HarvestTarget Tomato')))
