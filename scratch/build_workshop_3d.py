import bpy
import math
import os

OUT_GLB = "/opt/heroesIsland/assets/scenes_3d/build_workshop.glb"
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

# Morandi workshop palette
mat_ground = create_mat("GrassEarth", (0.32, 0.52, 0.28), roughness=0.7)
mat_rock = create_mat("RockCliff", (0.30, 0.28, 0.26), roughness=0.8)
mat_paving = create_mat("StonePaving", (0.50, 0.48, 0.45), roughness=0.5)
mat_metal_dark = create_mat("MetalDark", (0.22, 0.23, 0.25), roughness=0.35, metallic=0.8)
mat_gold = create_mat("GoldAccent", (0.88, 0.70, 0.22), roughness=0.25, metallic=0.75)
mat_crane_orange = create_mat("CraneOrange", (0.85, 0.45, 0.18), roughness=0.4)
mat_energy_cyan = create_mat("EnergyCyan", (0.2, 0.75, 0.95), roughness=0.2, emission_srgb=(0.2, 0.75, 0.95), emission_strength=2.8)
mat_wood = create_mat("WoodPlank", (0.55, 0.38, 0.24), roughness=0.6)
mat_foliage = create_mat("TreeFoliage", (0.26, 0.46, 0.25), roughness=0.7)
mat_cloud = create_mat("CloudPuff", (0.90, 0.92, 0.96), roughness=0.5)

# 1. Main Floating Workshop Terrace (Width 16m along X, Depth 10m along Y in Blender)
bpy.ops.mesh.primitive_cylinder_add(radius=8.8, depth=1.6, vertices=36, location=(0, 0, -0.8))
island_top = bpy.context.active_object
island_top.name = "IslandTop"
island_top.data.materials.append(mat_ground)
bpy.ops.object.shade_smooth()

bpy.ops.mesh.primitive_cone_add(radius1=8.7, radius2=1.2, depth=6.2, vertices=20, location=(0, 0, -4.6))
island_bottom = bpy.context.active_object
island_bottom.name = "IslandBottom"
island_bottom.data.materials.append(mat_rock)
island_bottom.rotation_euler = (math.radians(180), 0, 0)
bpy.ops.object.shade_smooth()

# 2. Main Stone Construction Terrace Floor
bpy.ops.mesh.primitive_cylinder_add(radius=7.0, depth=0.35, vertices=40, location=(0, 0, 0.18))
terrace = bpy.context.active_object
terrace.name = "TerraceFloor"
terrace.data.materials.append(mat_paving)
bpy.ops.object.shade_smooth()

# Gold border ring
bpy.ops.mesh.primitive_torus_add(major_radius=6.95, minor_radius=0.10, major_segments=40, minor_segments=8, location=(0, 0, 0.36))
gold_ring = bpy.context.active_object
gold_ring.data.materials.append(mat_gold)
bpy.ops.object.shade_smooth()

# 3. Flanking Crane Assemblies (Left at X = -5.8, Right at X = 5.8, Blender Y = 0.5)
for cx in [-5.8, 5.8]:
    # Heavy base
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, 0.5, 0.5))
    base = bpy.context.active_object
    base.scale = (1.4, 1.4, 0.6)
    base.data.materials.append(mat_metal_dark)

    # Vertical mast
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, 0.5, 2.5))
    mast = bpy.context.active_object
    mast.scale = (0.5, 0.5, 3.4)
    mast.data.materials.append(mat_crane_orange)

    # Horizontal boom arm
    arm_dir = 1.0 if cx < 0 else -1.0
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx + arm_dir * 1.5, 0.5, 4.2))
    boom = bpy.context.active_object
    boom.scale = (3.2, 0.4, 0.4)
    boom.data.materials.append(mat_crane_orange)

    # Glowing hoist cable & energy hook
    bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=1.4, vertices=8, location=(cx + arm_dir * 2.5, 0.5, 3.4))
    cable = bpy.context.active_object
    cable.data.materials.append(mat_metal_dark)

    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(cx + arm_dir * 2.5, 0.5, 2.6))
    hook = bpy.context.active_object
    hook.data.materials.append(mat_energy_cyan)

# 4. Energy Generator Pylons in Background (Blender Y = 3.2, which is -Z in Godot)
pylon_coords = [(-3.8, 3.6), (0.0, 4.2), (3.8, 3.6)]
for idx, (px, py) in enumerate(pylon_coords):
    # Pedestal
    bpy.ops.mesh.primitive_cylinder_add(radius=0.55, depth=0.8, vertices=16, location=(px, py, 0.6))
    ped = bpy.context.active_object
    ped.data.materials.append(mat_metal_dark)

    # Glowing crystal core
    bpy.ops.mesh.primitive_cylinder_add(radius=0.32, depth=1.6, vertices=6, location=(px, py, 1.8))
    core = bpy.context.active_object
    core.data.materials.append(mat_energy_cyan)

    # Top emitter cap
    bpy.ops.mesh.primitive_cone_add(radius1=0.6, radius2=0.1, depth=0.5, vertices=16, location=(px, py, 2.8))
    cap = bpy.context.active_object
    cap.data.materials.append(mat_metal_dark)

# 5. Background Voxel Spruce Trees (Blender Y = 4.5 to 5.5)
tree_coords = [(-6.5, 3.8), (-2.0, 5.2), (2.0, 5.2), (6.5, 3.8)]
for tx, ty in tree_coords:
    # Trunk
    bpy.ops.mesh.primitive_cylinder_add(radius=0.16, depth=1.2, vertices=8, location=(tx, ty, 0.8))
    trunk = bpy.context.active_object
    trunk.data.materials.append(mat_wood)

    # Stepped foliage cones (Minecraft/voxel style)
    for tier in range(3):
        trad = 0.9 - tier * 0.22
        tz = 1.4 + tier * 0.6
        bpy.ops.mesh.primitive_cone_add(radius1=trad, radius2=0.1, depth=0.7, vertices=6, location=(tx, ty, tz))
        cone = bpy.context.active_object
        cone.data.materials.append(mat_foliage)

# 6. Fluffy Floating Clouds around the terrace
for cx, cy, cz, cs in [(-8.5, 2.0, 0.0, 1.5), (8.5, 1.8, 0.2, 1.4), (0.0, 7.5, -0.4, 2.2)]:
    for sub in range(3):
        sx = cx + (sub - 1) * 0.7 * cs
        sy = cy + (sub % 2 - 0.5) * 0.5 * cs
        sz = cz
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.75 * cs, segments=16, ring_count=12, location=(sx, sy, sz))
        c_part = bpy.context.active_object
        c_part.scale = (1.2, 1.0, 0.65)
        c_part.data.materials.append(mat_cloud)
        bpy.ops.object.shade_smooth()

bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format='GLB',
    use_selection=False,
    export_apply=True
)
print("SUCCESS: Exported 3D build workshop to", OUT_GLB)
