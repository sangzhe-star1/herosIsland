import bpy
import math
import os

OUT_GLB = "/opt/heroesIsland/assets/scenes_3d/platformer_course.glb"
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)

def srgb_to_lin(c):
    return tuple(x ** 2.2 for x in c)

def create_mat(name, srgb_color, roughness=0.6, metallic=0.0):
    mat = bpy.data.materials.new(name=name)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        lin_color = srgb_to_lin(srgb_color)
        bsdf.inputs["Base Color"].default_value = (*lin_color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
    return mat

# Natural Morandi Minecraft/Voxel Palette
mat_grass_top = create_mat("GrassTop", (0.34, 0.52, 0.28), roughness=0.7) # calm meadow green
mat_dirt_side = create_mat("DirtSide", (0.44, 0.34, 0.24), roughness=0.8) # warm earth
mat_stone_rock = create_mat("StoneRock", (0.42, 0.42, 0.44), roughness=0.75) # stone strata
mat_wood_trunk = create_mat("WoodTrunk", (0.34, 0.24, 0.18), roughness=0.8)
mat_pine_needle = create_mat("PineNeedle", (0.24, 0.42, 0.24), roughness=0.7)
mat_pine_needle2 = create_mat("PineNeedle2", (0.28, 0.48, 0.28), roughness=0.7)
mat_cloud = create_mat("CloudVoxel", (0.92, 0.94, 0.98), roughness=0.45)

# 1. Continuous Foreground Voxel Ground (Blender Y from -3.0 to +3.5, Z around 0)
for fx in range(-24, 52, 4):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(fx, 0.0, -0.6))
    fg = bpy.context.active_object
    fg.name = f"FgGround_{fx}"
    fg.scale = (4.0, 7.0, 1.4)
    fg.data.materials.append(mat_grass_top)

    # Dirt strata below
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(fx, 0.0, -1.8))
    fg_dirt = bpy.context.active_object
    fg_dirt.scale = (4.0, 7.0, 1.2)
    fg_dirt.data.materials.append(mat_dirt_side)

# 2. Rolling Voxel Terraces in Midground (Blender Y = 4.0 to 7.0, Z = 0.5 to 2.5)
for hx in range(-24, 52, 3):
    height = 1.8 + math.sin(hx * 0.18) * 0.9 + math.cos(hx * 0.35) * 0.6
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(hx, 5.0, height * 0.5))
    hill = bpy.context.active_object
    hill.scale = (3.2, 4.0, height)
    hill.data.materials.append(mat_grass_top)

# 3. Distant Voxel Mountain Peaks (Blender Y = 12.0 to 16.0)
for px in range(-24, 54, 6):
    p_height = 6.0 + math.cos(px * 0.2) * 2.5
    bpy.ops.mesh.primitive_cone_add(radius1=4.5, radius2=0.5, depth=p_height, vertices=6, location=(px, 14.0, p_height * 0.5))
    peak = bpy.context.active_object
    peak.data.materials.append(mat_stone_rock)

# 4. Voxel Spruce Trees across the landscape
for tx in range(-20, 48, 4):
    tz_base = 0.2 if tx % 3 == 0 else (1.2 + math.sin(tx * 0.18) * 0.8)
    ty = 1.5 if tx % 3 == 0 else 4.2
    # Trunk
    bpy.ops.mesh.primitive_cylinder_add(radius=0.16, depth=1.4, vertices=8, location=(tx + 0.5, ty, tz_base + 0.7))
    trunk = bpy.context.active_object
    trunk.data.materials.append(mat_wood_trunk)

    # 3 Foliage tiers
    for tier in range(3):
        rad = 0.85 - tier * 0.22
        fol_z = tz_base + 1.4 + tier * 0.6
        bpy.ops.mesh.primitive_cone_add(radius1=rad, radius2=0.1, depth=0.7, vertices=6, location=(tx + 0.5, ty, fol_z))
        cone = bpy.context.active_object
        cone.data.materials.append(mat_pine_needle if tier % 2 == 0 else mat_pine_needle2)

# 5. Floating Voxel Islands with Trees (Blender Y = 2.0 to 3.5, Z = 3.0 to 4.5)
island_locs = [(-12.0, 2.5, 3.4), (-2.0, 2.2, 3.8), (10.0, 2.6, 3.6), (22.0, 2.4, 4.0), (32.0, 2.8, 3.5)]
for ix, iy, iz in island_locs:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(ix, iy, iz))
    isl_top = bpy.context.active_object
    isl_top.scale = (3.2, 2.0, 0.6)
    isl_top.data.materials.append(mat_grass_top)

    bpy.ops.mesh.primitive_cone_add(radius1=1.6, radius2=0.3, depth=1.5, vertices=8, location=(ix, iy, iz - 1.0))
    isl_bot = bpy.context.active_object
    isl_bot.rotation_euler = (math.radians(180), 0, 0)
    isl_bot.data.materials.append(mat_stone_rock)

# 6. Fluffy Voxel Clouds drifting above
cloud_locs = [(-16.0, 5.0, 7.5), (-4.0, 6.5, 8.2), (8.0, 5.5, 7.8), (20.0, 7.0, 8.0), (34.0, 6.0, 7.6)]
for cx, cy, cz in cloud_locs:
    for sub in range(4):
        sx = cx + (sub - 1.5) * 1.4
        sy = cy + (sub % 2) * 0.8
        sz = cz + math.sin(sub) * 0.25
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, sy, sz))
        c_part = bpy.context.active_object
        c_part.scale = (1.8, 1.4, 0.8)
        c_part.data.materials.append(mat_cloud)

bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format='GLB',
    use_selection=False,
    export_apply=True
)
print("SUCCESS: Exported full foreground-to-background 3D platformer course to", OUT_GLB)
