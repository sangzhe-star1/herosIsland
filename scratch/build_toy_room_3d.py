import bpy
import math
import os

OUT_GLB = "/opt/heroesIsland/assets/scenes_3d/toy_room_study.glb"
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)

def srgb_to_lin(c):
    return tuple(x ** 2.2 for x in c)

def create_mat(name, srgb_color, roughness=0.55, metallic=0.0, emission_srgb=None, emission_strength=1.0):
    mat = bpy.data.materials.new(name=name)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        lin_color = srgb_to_lin(srgb_color)
        bsdf.inputs["Base Color"].default_value = (*lin_color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if emission_srgb and "Emission Color" in bsdf.inputs:
            lin_em = srgb_to_lin(emission_srgb)
            bsdf.inputs["Emission Color"].default_value = (*lin_em, 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat

# Warm cozy Scandinavian / Montessori nursery toy room palette
mat_table_wood = create_mat("TableWood", (0.72, 0.58, 0.44), roughness=0.45) # light warm birch wood
mat_wall = create_mat("RoomWall", (0.88, 0.86, 0.82), roughness=0.6) # warm off-white cream wall
mat_shelf_wood = create_mat("ShelfWood", (0.62, 0.48, 0.35), roughness=0.5) # honey oak
mat_window_frame = create_mat("WindowFrame", (0.95, 0.95, 0.96), roughness=0.35)
mat_window_sky = create_mat("WindowSky", (0.55, 0.78, 0.95), roughness=0.1, emission_srgb=(0.6, 0.82, 0.98), emission_strength=2.0)
mat_sunbeam = create_mat("Sunbeam", (1.0, 0.95, 0.75), roughness=0.1, emission_srgb=(1.0, 0.95, 0.75), emission_strength=1.5)

# Toy colors (Morandi soft pastel toys on shelves)
mat_toy_blue = create_mat("ToyBlue", (0.35, 0.55, 0.75), roughness=0.4)
mat_toy_red = create_mat("ToyRed", (0.78, 0.38, 0.32), roughness=0.4)
mat_toy_yellow = create_mat("ToyYellow", (0.90, 0.75, 0.32), roughness=0.4)
mat_toy_green = create_mat("ToyGreen", (0.42, 0.65, 0.45), roughness=0.4)
mat_toy_purple = create_mat("ToyPurple", (0.65, 0.50, 0.72), roughness=0.4)
mat_plant_pot = create_mat("PlantPot", (0.76, 0.46, 0.36), roughness=0.6)
mat_plant_leaf = create_mat("PlantLeaf", (0.35, 0.62, 0.38), roughness=0.5)

mat_leather_mat = create_mat("LeatherMat", (0.28, 0.42, 0.35), roughness=0.6) # Morandi sage leather
mat_gold_stitch = create_mat("GoldStitch", (0.85, 0.72, 0.35), roughness=0.35, metallic=0.7)
mat_pencil_cup = create_mat("PencilCup", (0.75, 0.65, 0.55), roughness=0.4)
mat_sketchbook = create_mat("Sketchbook", (0.94, 0.92, 0.88), roughness=0.6)

# 1. Main Playroom Table Surface - Slatted Oak Planks (X from -14 to +14, Y from -5 to +2, Z = 0)
# Base frame
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -1.0, -0.35))
base_frame = bpy.context.active_object
base_frame.scale = (24.0, 8.0, 0.3)
base_frame.data.materials.append(mat_shelf_wood)

# 12 Individual Beveled Oak Timber Planks
for pi in range(12):
    py = -4.8 + pi * 0.62
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, py, -0.05))
    plank = bpy.context.active_object
    plank.name = f"OakPlank_{pi}"
    plank.scale = (24.0, 0.58, 0.18)
    plank.data.materials.append(mat_table_wood)

# Front table apron & beveled bullnose edge
bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=24.0, vertices=16, location=(0, -5.1, -0.05))
edge = bpy.context.active_object
edge.rotation_euler = (0, math.radians(90), 0)
edge.data.materials.append(mat_table_wood)
bpy.ops.object.shade_smooth()

# Central Morandi Sage Leather Desk Mat (where crates and items sit: Y from -4.0 to +1.2)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -1.2, 0.06))
mat_obj = bpy.context.active_object
mat_obj.name = "LeatherDeskMat"
mat_obj.scale = (18.5, 5.8, 0.05)
mat_obj.data.materials.append(mat_leather_mat)

# Stitched golden trim border around desk mat
for sx, sy, sw, sh in [(0, 1.66, 18.2, 0.08), (0, -4.06, 18.2, 0.08), (-9.15, -1.2, 0.08, 5.6), (9.15, -1.2, 0.08, 5.6)]:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, sy, 0.09))
    stitch = bpy.context.active_object
    stitch.scale = (sw, sh, 0.02)
    stitch.data.materials.append(mat_gold_stitch)

# Tabletop Accessories: Ceramic Pencil Cup with Colored Pencils (top right at X=6.8, Y=1.2)
bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=1.0, vertices=16, location=(6.8, 1.2, 0.55))
cup = bpy.context.active_object
cup.data.materials.append(mat_pencil_cup)
bpy.ops.object.shade_smooth()
for pidx, pcol in enumerate([mat_toy_red, mat_toy_blue, mat_toy_yellow, mat_toy_green]):
    pa = pidx * (math.pi * 0.5) + 0.3
    px = 6.8 + math.cos(pa) * 0.18
    py = 1.2 + math.sin(pa) * 0.18
    bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=1.1, vertices=8, location=(px, py, 1.0))
    pencil = bpy.context.active_object
    pencil.rotation_euler = (0.15 * math.sin(pa), 0.15 * math.cos(pa), 0)
    pencil.data.materials.append(pcol)

# Open Sketchbook on Desk (top left at X=-6.5, Y=1.1)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-6.5, 1.1, 0.12))
book = bpy.context.active_object
book.scale = (2.2, 1.6, 0.08)
book.rotation_euler = (0, 0, math.radians(-12))
book.data.materials.append(mat_sketchbook)

# 2. Back Wall (Blender Y = 3.5, Z from 0 to 10)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 3.6, 4.5))
wall = bpy.context.active_object
wall.name = "BackWall"
wall.scale = (24.0, 0.4, 9.0)
wall.data.materials.append(mat_wall)

# Baseboard molding along the wall bottom
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 3.4, 0.25))
baseboard = bpy.context.active_object
baseboard.scale = (24.0, 0.2, 0.5)
baseboard.data.materials.append(mat_window_frame)

# 3. Big Sunny Arched Window in Center of Wall (X = 0, Y = 3.5, Z = 5.2)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 3.52, 5.2))
win_sky = bpy.context.active_object
win_sky.scale = (4.8, 0.1, 4.0)
win_sky.data.materials.append(mat_window_sky)

# Window frame crossbars
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 3.45, 5.2))
v_frame = bpy.context.active_object
v_frame.scale = (0.16, 0.15, 4.2)
v_frame.data.materials.append(mat_window_frame)

bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 3.45, 5.2))
h_frame = bpy.context.active_object
h_frame.scale = (5.0, 0.15, 0.16)
h_frame.data.materials.append(mat_window_frame)

# Window outer casing sill
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 3.35, 3.1))
sill = bpy.context.active_object
sill.scale = (5.4, 0.35, 0.2)
sill.data.materials.append(mat_window_frame)

# Cute potted plant on windowsill
bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.35, vertices=16, location=(-1.6, 3.3, 3.35))
pot = bpy.context.active_object
pot.data.materials.append(mat_plant_pot)
bpy.ops.object.shade_smooth()

for pi in range(5):
    pa = pi * (math.pi * 2 / 5.0)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.2, subdivisions=2, location=(-1.6 + math.cos(pa) * 0.18, 3.3 + math.sin(pa) * 0.12, 3.65))
    leaf = bpy.context.active_object
    leaf.scale = (1.0, 0.8, 0.6)
    leaf.data.materials.append(mat_plant_leaf)
    bpy.ops.object.shade_smooth()

# 4. Wooden Toy Shelves on Left and Right flanks of the wall
for sx in [-7.2, 7.2]:
    # Vertical side panels
    for dx in [-1.5, 1.5]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx + dx, 3.1, 3.6))
        v_panel = bpy.context.active_object
        v_panel.scale = (0.18, 0.8, 6.4)
        v_panel.data.materials.append(mat_shelf_wood)

    # 3 Horizontal shelves
    for sz in [1.2, 3.2, 5.2, 6.8]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, 3.1, sz))
        shelf = bpy.context.active_object
        shelf.scale = (3.1, 0.8, 0.16)
        shelf.data.materials.append(mat_shelf_wood)

# 5. Colorful 3D Wooden Toys on the Shelves
# Left shelf toys
# Building blocks stack on bottom shelf (Z = 1.6)
for i, bx in enumerate([-8.2, -7.6, -7.0, -6.4]):
    bpy.ops.mesh.primitive_cube_add(size=0.45, location=(bx, 3.1, 1.5))
    block = bpy.context.active_object
    mats = [mat_toy_blue, mat_toy_red, mat_toy_yellow, mat_toy_green]
    block.data.materials.append(mats[i % 4])

# Pyramid blocks on middle shelf (Z = 3.6)
bpy.ops.mesh.primitive_cone_add(radius1=0.35, radius2=0.0, depth=0.6, vertices=4, location=(-7.6, 3.1, 3.6))
pyr = bpy.context.active_object
pyr.data.materials.append(mat_toy_purple)

bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=0.55, vertices=16, location=(-6.8, 3.1, 3.6))
cyl = bpy.context.active_object
cyl.data.materials.append(mat_toy_blue)
bpy.ops.object.shade_smooth()

# Wooden toy locomotive on right shelf (Z = 1.6)
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(6.6, 3.1, 1.55))
train_body = bpy.context.active_object
train_body.scale = (1.2, 0.45, 0.5)
train_body.data.materials.append(mat_toy_red)

bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.8, vertices=16, location=(6.4, 3.1, 1.75))
boiler = bpy.context.active_object
boiler.rotation_euler = (0, math.radians(90), 0)
boiler.data.materials.append(mat_toy_yellow)
bpy.ops.object.shade_smooth()

# Toy globe on middle shelf (Z = 3.7)
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.38, segments=20, ring_count=16, location=(7.4, 3.1, 3.7))
globe = bpy.context.active_object
globe.data.materials.append(mat_toy_blue)
bpy.ops.object.shade_smooth()

bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=0.65, vertices=8, location=(7.4, 3.1, 3.4))
stand = bpy.context.active_object
stand.data.materials.append(mat_table_wood)

bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format='GLB',
    use_selection=False,
    export_apply=True
)
print("SUCCESS: Exported 3D nursery playroom study to", OUT_GLB)
