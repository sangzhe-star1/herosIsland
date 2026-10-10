import bpy
import math
import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]

def srgb_to_lin(c):
    return tuple(max(0.0, min(1.0, float(x))) ** 2.2 for x in c)

def create_mat(name, srgb_color, roughness=0.6, metallic=0.0, emissive=None, emit_strength=1.0):
    mat = bpy.data.materials.new(name=name)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        lin_color = srgb_to_lin(srgb_color)
        bsdf.inputs["Base Color"].default_value = (*lin_color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if emissive and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*srgb_to_lin(emissive), 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emit_strength
    return mat

def smooth_mesh(obj):
    if obj and obj.type == 'MESH':
        obj.data.polygons.foreach_set('use_smooth', [True] * len(obj.data.polygons))

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# =========================================================================
# 1. DUEL ARENA (duel_arena.glb)
# Grand Roman/Grecian colosseum with warm travertine sandstone,
# radial gold runes, and distant alpine mountain peaks.
# =========================================================================
def build_duel_arena():
    clear_scene()
    out_path = str(PROJECT_ROOT / "assets/scenes_3d/duel_arena.glb")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    mat_stone = create_mat("ArenaStone", (0.42, 0.38, 0.32), roughness=0.85)
    mat_stone_dark = create_mat("ArenaStoneDark", (0.38, 0.35, 0.38), roughness=0.75)
    mat_gold_trim = create_mat("GoldTrim", (0.88, 0.72, 0.32), roughness=0.35, metallic=0.75)
    mat_hero_pad = create_mat("HeroPad", (0.28, 0.62, 0.95), roughness=0.35, emissive=(0.25, 0.60, 0.95), emit_strength=2.2)
    mat_boss_pad = create_mat("BossPad", (0.95, 0.45, 0.28), roughness=0.35, emissive=(0.98, 0.42, 0.25), emit_strength=2.2)
    mat_brass = create_mat("BrazierBrass", (0.75, 0.60, 0.32), roughness=0.4, metallic=0.7)
    mat_flame = create_mat("FlameCrystal", (1.0, 0.78, 0.32), roughness=0.2, emissive=(1.0, 0.82, 0.35), emit_strength=2.8)
    mat_ground = create_mat("GroundRock", (0.42, 0.38, 0.35), roughness=0.85)
    mat_mountains = create_mat("BgMountain", (0.35, 0.38, 0.46), roughness=0.8)
    mat_snow = create_mat("MountainSnow", (0.92, 0.94, 0.98), roughness=0.4)

    # Base valley
    bpy.ops.mesh.primitive_cylinder_add(radius=24.0, depth=1.0, vertices=48, location=(0.0, 1.5, -0.6))
    base = bpy.context.active_object
    smooth_mesh(base)
    base.data.materials.append(mat_ground)

    # Grand Raised Dais Tier 1 (dark stone plinth)
    bpy.ops.mesh.primitive_cylinder_add(radius=9.8, depth=0.8, vertices=48, location=(0.0, 1.2, 0.0))
    dais1 = bpy.context.active_object
    smooth_mesh(dais1)
    dais1.data.materials.append(mat_stone_dark)

    # Grand Raised Dais Tier 2 (warm travertine sandstone fighting floor)
    bpy.ops.mesh.primitive_cylinder_add(radius=9.2, depth=0.5, vertices=48, location=(0.0, 1.2, 0.4))
    dais2 = bpy.context.active_object
    smooth_mesh(dais2)
    dais2.data.materials.append(mat_stone)

    # Gold perimeter inlay ring
    bpy.ops.mesh.primitive_torus_add(major_radius=8.8, minor_radius=0.14, location=(0.0, 1.2, 0.66))
    ring = bpy.context.active_object
    smooth_mesh(ring)
    ring.data.materials.append(mat_gold_trim)

    # Radial brass inlay grooves across dais
    for a in range(8):
        angle = a * (math.pi / 4.0)
        gx = math.cos(angle) * 4.2
        gy = 1.2 + math.sin(angle) * 4.2
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(gx, gy, 0.66))
        groove = bpy.context.active_object
        groove.scale = (0.1, 8.2, 0.04)
        groove.rotation_euler = (0.0, 0.0, angle)
        groove.data.materials.append(mat_gold_trim)

    # Hero Battle Glyph Platform -> Screen X=270, Y=520
    bpy.ops.mesh.primitive_cylinder_add(radius=1.85, depth=0.14, vertices=36, location=(-4.55, 0.6, 0.68))
    h_pad = bpy.context.active_object
    smooth_mesh(h_pad)
    h_pad.data.materials.append(mat_hero_pad)
    bpy.ops.mesh.primitive_torus_add(major_radius=1.85, minor_radius=0.10, location=(-4.55, 0.6, 0.73))
    h_rim = bpy.context.active_object
    smooth_mesh(h_rim)
    h_rim.data.materials.append(mat_gold_trim)

    # Boss Battle Glyph Platform -> Screen X=976, Y=520
    bpy.ops.mesh.primitive_cylinder_add(radius=2.35, depth=0.14, vertices=36, location=(4.15, 0.6, 0.68))
    b_pad = bpy.context.active_object
    smooth_mesh(b_pad)
    b_pad.data.materials.append(mat_boss_pad)
    bpy.ops.mesh.primitive_torus_add(major_radius=2.35, minor_radius=0.11, location=(4.15, 0.6, 0.73))
    b_rim = bpy.context.active_object
    smooth_mesh(b_rim)
    b_rim.data.materials.append(mat_gold_trim)

    # Flanking Braziers
    for bx, by in [(-7.6, 1.2), (7.6, 1.2), (-5.6, 6.2), (5.6, 6.2)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.6, depth=1.4, vertices=24, location=(bx, by, 0.7))
        p = bpy.context.active_object
        smooth_mesh(p)
        p.data.materials.append(mat_stone_dark)
        bpy.ops.mesh.primitive_cone_add(radius1=0.8, radius2=0.35, depth=0.6, vertices=24, location=(bx, by, 1.55))
        bowl = bpy.context.active_object
        smooth_mesh(bowl)
        bowl.data.materials.append(mat_brass)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.35, subdivisions=2, location=(bx, by, 2.0))
        flame = bpy.context.active_object
        smooth_mesh(flame)
        flame.data.materials.append(mat_flame)

    # Distant Alpine Mountains with Snowcaps
    for px, pz, pr in [(-15.0, 18.0, 8.5), (-6.0, 22.0, 10.5), (5.0, 21.0, 9.5), (14.0, 19.0, 8.0)]:
        bpy.ops.mesh.primitive_cone_add(radius1=pr, radius2=0.5, depth=15.0, vertices=16, location=(px, pz, 6.5))
        peak = bpy.context.active_object
        smooth_mesh(peak)
        peak.data.materials.append(mat_mountains)
        bpy.ops.mesh.primitive_cone_add(radius1=pr * 0.42, radius2=0.2, depth=5.5, vertices=16, location=(px, pz, 11.2))
        snow = bpy.context.active_object
        smooth_mesh(snow)
        snow.data.materials.append(mat_snow)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("SUCCESS: Exported duel_arena.glb")


# =========================================================================
# 2. HARVEST MEADOW (harvest_meadow.glb)
# Nordic farm diorama with Scandinavian barn, windmill, stone well, and teddy bear.
# Fence at Y=4.8 cleanly behind all crops and planters.
# =========================================================================
def build_harvest_meadow():
    clear_scene()
    out_path = str(PROJECT_ROOT / "assets/scenes_3d/harvest_meadow.glb")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    mat_grass = create_mat("MeadowGrass", (0.28, 0.42, 0.22), roughness=0.85)
    mat_soil_clearing = create_mat("GardenTerraceSoil", (0.36, 0.24, 0.15), roughness=0.88)
    mat_path = create_mat("GravelPath", (0.64, 0.58, 0.48), roughness=0.80)
    mat_wood = create_mat("FarmWood", (0.62, 0.46, 0.32), roughness=0.60)
    mat_wood_dark = create_mat("WoodDark", (0.38, 0.26, 0.16), roughness=0.65)
    mat_cloud = create_mat("FarmCloud", (0.94, 0.96, 0.99), roughness=0.45)
    mat_barn_red = create_mat("BarnRed", (0.66, 0.26, 0.20), roughness=0.55)
    mat_barn_white = create_mat("BarnWhite", (0.92, 0.90, 0.85), roughness=0.50)
    mat_roof = create_mat("SlateRoof", (0.30, 0.34, 0.38), roughness=0.60)
    mat_well = create_mat("WellStone", (0.56, 0.58, 0.60), roughness=0.65)
    mat_water = create_mat("WellWater", (0.28, 0.58, 0.85), roughness=0.15)
    mat_bear = create_mat("TeddyBearFur", (0.78, 0.58, 0.38), roughness=0.80)
    mat_bear_snout = create_mat("TeddyBearSnout", (0.90, 0.82, 0.70), roughness=0.80)
    mat_bear_eye = create_mat("TeddyBearEye", (0.12, 0.08, 0.06), roughness=0.20)
    mat_hay = create_mat("GoldenHay", (0.86, 0.74, 0.38), roughness=0.80)
    mat_window_glow = create_mat("WindowGlow", (1.0, 0.92, 0.60), roughness=0.2, emissive=(1.0, 0.92, 0.60), emit_strength=1.8)
    mat_leaf = create_mat("TreeLeaf", (0.30, 0.54, 0.28), roughness=0.70)
    mat_leaf2 = create_mat("TreeLeaf2", (0.36, 0.60, 0.32), roughness=0.70)
    mat_apple = create_mat("AppleRed", (0.85, 0.20, 0.18), roughness=0.35)

    # 1. Main Rolling Meadow Terrain
    bpy.ops.mesh.primitive_cylinder_add(radius=36.0, depth=1.0, vertices=48, location=(0.0, 3.0, -0.5))
    meadow = bpy.context.active_object
    smooth_mesh(meadow)
    meadow.data.materials.append(mat_grass)

    # 2. Gentle garden plot clearing in the soil bed area
    bpy.ops.mesh.primitive_cylinder_add(radius=7.2, depth=0.08, vertices=48, location=(-1.2, 1.2, 0.04))
    clearing = bpy.context.active_object
    smooth_mesh(clearing)
    clearing.scale = (1.45, 0.78, 1.0)
    clearing.data.materials.append(mat_soil_clearing)

    # 3. Soft garden path curving BEHIND the field towards the well
    path_pts = [(-6.5, 4.4), (-4.2, 4.6), (-1.2, 4.8), (1.8, 4.2), (3.6, 2.8)]
    for pi, (px, py) in enumerate(path_pts):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.75, depth=0.04, vertices=20, location=(px, py, 0.05))
        stone = bpy.context.active_object
        smooth_mesh(stone)
        stone.scale = (1.1, 0.8, 1.0)
        stone.data.materials.append(mat_path)

    # 4. Rustic wooden post-and-rail fences in the background (Y = 4.8, CLEARS CARROTS & BEDS!)
    for fx in range(-5, 4):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=1.1, vertices=12, location=(fx * 1.4, 4.8, 0.55))
        post = bpy.context.active_object
        smooth_mesh(post)
        post.data.materials.append(mat_wood)
        if fx < 3:
            for rz in [0.45, 0.85]:
                bpy.ops.mesh.primitive_cube_add(size=1.0, location=(fx * 1.4 + 0.7, 4.8, rz))
                rail = bpy.context.active_object
                rail.scale = (1.4, 0.06, 0.08)
                rail.data.materials.append(mat_wood)

    # 5. Red Scandinavian Barn in Background Left (X = -8.5, Y = 6.2)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-8.5, 6.2, 2.2))
    barn = bpy.context.active_object
    barn.scale = (4.6, 3.6, 3.2)
    barn.data.materials.append(mat_barn_red)

    # Barn White Trim Corners
    for cx in [-10.7, -6.3]:
        for cy in [4.5, 7.9]:
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, 2.2))
            trim = bpy.context.active_object
            trim.scale = (0.2, 0.2, 3.25)
            trim.data.materials.append(mat_barn_white)

    # Barn Dark Wood Double Doors with X-Brace
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-8.5, 4.38, 1.5))
    door = bpy.context.active_object
    door.scale = (1.6, 0.1, 1.9)
    door.data.materials.append(mat_wood_dark)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-8.5, 4.34, 1.5))
    door_frame = bpy.context.active_object
    door_frame.scale = (1.75, 0.08, 2.05)
    door_frame.data.materials.append(mat_barn_white)

    # Barn Loft Window with warm light
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-8.5, 4.36, 3.0))
    win = bpy.context.active_object
    win.scale = (0.7, 0.08, 0.7)
    win.data.materials.append(mat_window_glow)

    # Barn Pitched Slate Roof
    for side, ang in [(-1, 0.40), (1, -0.40)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-8.5, 6.2 + side * 1.05, 4.05))
        rf = bpy.context.active_object
        rf.scale = (5.0, 2.4, 0.18)
        rf.rotation_euler = (ang, 0.0, 0.0)
        rf.data.materials.append(mat_roof)

    # 6. Distant Dutch Windmill on Horizon (X = 12.0, Y = 8.5)
    bpy.ops.mesh.primitive_cylinder_add(radius=1.1, depth=1.0, vertices=24, location=(12.0, 8.5, 0.5))
    mill_base = bpy.context.active_object
    smooth_mesh(mill_base)
    mill_base.data.materials.append(mat_well)

    bpy.ops.mesh.primitive_cone_add(radius1=1.0, radius2=0.6, depth=2.8, vertices=24, location=(12.0, 8.5, 2.4))
    mill_tower = bpy.context.active_object
    smooth_mesh(mill_tower)
    mill_tower.data.materials.append(mat_wood)

    bpy.ops.mesh.primitive_cone_add(radius1=0.7, radius2=0.05, depth=0.9, vertices=24, location=(12.0, 8.5, 4.2))
    mill_cap = bpy.context.active_object
    smooth_mesh(mill_cap)
    mill_cap.data.materials.append(mat_roof)

    # Windmill hub and 4 slender lattice blades (radius 1.1)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=0.25, vertices=16, location=(12.0, 7.8, 3.8))
    hub = bpy.context.active_object
    smooth_mesh(hub)
    hub.rotation_euler = (math.radians(90), 0, 0)
    hub.data.materials.append(mat_wood_dark)

    for b in range(4):
        ba = math.radians(45) + b * (math.pi * 0.5)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(12.0 + math.cos(ba) * 0.65, 7.7, 3.8 + math.sin(ba) * 0.65))
        blade = bpy.context.active_object
        blade.scale = (0.08, 0.03, 1.1)
        blade.rotation_euler = (0.0, -ba, 0.0)
        blade.data.materials.append(mat_barn_white)

    # 7. Fieldstone Well (X = 4.8, Y = 1.8) -> Screen X ≈ 1080, Y ≈ 320
    bpy.ops.mesh.primitive_cylinder_add(radius=0.85, depth=0.8, vertices=32, location=(4.8, 1.8, 0.4))
    well = bpy.context.active_object
    smooth_mesh(well)
    well.data.materials.append(mat_well)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.72, depth=0.1, vertices=32, location=(4.8, 1.8, 0.65))
    water = bpy.context.active_object
    smooth_mesh(water)
    water.data.materials.append(mat_water)

    for dx in [-0.7, 0.7]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=1.3, vertices=12, location=(4.8 + dx, 1.8, 1.05))
        post = bpy.context.active_object
        smooth_mesh(post)
        post.data.materials.append(mat_wood)

    # Pitched wooden shake roof for well
    for side, ang in [(-1, 0.35), (1, -0.35)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(4.8, 1.8 + side * 0.45, 1.82))
        w_rf = bpy.context.active_object
        w_rf.scale = (1.9, 0.9, 0.10)
        w_rf.rotation_euler = (ang, 0.0, 0.0)
        w_rf.data.materials.append(mat_roof)

    # 8. Golden Hay Bale seat beside the well (X = 3.6, Y = 1.3)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.6, depth=0.6, vertices=24, location=(3.6, 1.3, 0.3))
    hay = bpy.context.active_object
    smooth_mesh(hay)
    hay.data.materials.append(mat_hay)

    # 9. 3D Plush Teddy Bear seated happily on the hay bale
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.45, subdivisions=2, location=(3.6, 1.3, 0.85))
    bear_body = bpy.context.active_object
    smooth_mesh(bear_body)
    bear_body.data.materials.append(mat_bear)

    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.34, subdivisions=2, location=(3.6, 1.25, 1.35))
    bear_head = bpy.context.active_object
    smooth_mesh(bear_head)
    bear_head.data.materials.append(mat_bear)

    # Cute snout
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.14, subdivisions=2, location=(3.6, 1.05, 1.30))
    snout = bpy.context.active_object
    smooth_mesh(snout)
    snout.data.materials.append(mat_bear_snout)

    # Button eyes
    for ex in [-0.11, 0.11]:
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.04, subdivisions=2, location=(3.6 + ex, 1.02, 1.40))
        eye = bpy.context.active_object
        smooth_mesh(eye)
        eye.data.materials.append(mat_bear_eye)

    # Little nose
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.045, subdivisions=2, location=(3.6, 0.94, 1.35))
    nose = bpy.context.active_object
    smooth_mesh(nose)
    nose.data.materials.append(mat_bear_eye)

    # Ears
    for ex in [-0.20, 0.20]:
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.11, subdivisions=2, location=(3.6 + ex, 1.25, 1.62))
        ear = bpy.context.active_object
        smooth_mesh(ear)
        ear.data.materials.append(mat_bear)

    # Paws
    for px in [-0.26, 0.26]:
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.13, subdivisions=2, location=(3.6 + px, 1.10, 0.70))
        paw = bpy.context.active_object
        smooth_mesh(paw)
        paw.data.materials.append(mat_bear)

    # 10. Apple Tree in distance behind well (X = 6.4, Y = 3.8) - 3-lobed puffy canopy
    bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=2.0, vertices=16, location=(6.4, 3.8, 1.0))
    a_trunk = bpy.context.active_object
    smooth_mesh(a_trunk)
    a_trunk.data.materials.append(mat_wood_dark)

    bpy.ops.mesh.primitive_ico_sphere_add(radius=1.1, subdivisions=2, location=(6.4, 3.8, 2.5))
    c_main = bpy.context.active_object
    smooth_mesh(c_main)
    c_main.data.materials.append(mat_leaf)

    for l_dx, l_dy, l_dz, l_rad in [(-0.6, -0.2, -0.2, 0.85), (0.6, -0.1, -0.15, 0.8), (0.0, 0.5, 0.2, 0.75)]:
        bpy.ops.mesh.primitive_ico_sphere_add(radius=l_rad, subdivisions=2, location=(6.4 + l_dx, 3.8 + l_dy, 2.5 + l_dz))
        clobe = bpy.context.active_object
        smooth_mesh(clobe)
        clobe.data.materials.append(mat_leaf2)

    for ax, ay, az in [(-0.5, -0.8, 0.1), (0.4, -0.9, -0.2), (0.0, -1.0, 0.3), (0.7, -0.6, 0.2)]:
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.11, subdivisions=2, location=(6.4 + ax, 3.8 + ay, 2.5 + az))
        app = bpy.context.active_object
        smooth_mesh(app)
        app.data.materials.append(mat_apple)

    # 11. Low-poly clouds floating high above the horizon
    for cx, cy, cz in [(-7.5, 14.0, 11.2), (3.5, 16.0, 12.5), (14.0, 15.0, 11.8)]:
        for sub in range(3):
            sx = cx + (sub - 1.0) * 1.5
            sy = cy + (sub % 2) * 0.8
            sz = cz + math.sin(sub) * 0.3
            bpy.ops.mesh.primitive_ico_sphere_add(radius=1.0, subdivisions=2, location=(sx, sy, sz))
            c_part = bpy.context.active_object
            smooth_mesh(c_part)
            c_part.data.materials.append(mat_cloud)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("SUCCESS: Exported harvest_meadow.glb")


# =========================================================================
# 3. TRAFFIC STREET (traffic_street.glb)
# European diorama street with mansard townhouses, shopfront awnings,
# street trees, cast-iron street lamps, and traffic lights.
# Continuous sidewalk to bottom edge, townhouses fully in frame.
# =========================================================================
def build_traffic_street():
    clear_scene()
    out_path = str(PROJECT_ROOT / "assets/scenes_3d/traffic_street.glb")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    mat_asphalt = create_mat("RoadAsphalt", (0.24, 0.26, 0.30), roughness=0.85)
    mat_curb = create_mat("CurbStone", (0.46, 0.45, 0.44), roughness=0.75)
    mat_sidewalk = create_mat("SidewalkPaver", (0.54, 0.52, 0.48), roughness=0.85)
    mat_sidewalk_near = create_mat("SidewalkNear", (0.50, 0.48, 0.45), roughness=0.85)
    mat_zebra = create_mat("ZebraPaint", (0.94, 0.92, 0.86), roughness=0.7)
    mat_iron = create_mat("CastIron", (0.20, 0.22, 0.24), roughness=0.4, metallic=0.8)
    mat_light_red = create_mat("LightRed", (0.95, 0.25, 0.20), roughness=0.2, emissive=(1.0, 0.20, 0.15), emit_strength=3.2)
    mat_light_amber = create_mat("LightAmber", (0.95, 0.75, 0.20), roughness=0.2, emissive=(1.0, 0.75, 0.20), emit_strength=1.5)
    mat_light_green = create_mat("LightGreen", (0.25, 0.92, 0.45), roughness=0.2, emissive=(0.20, 0.95, 0.40), emit_strength=3.2)
    mat_tree_wood = create_mat("TreeBark", (0.38, 0.28, 0.20), roughness=0.8)
    mat_tree_leaf = create_mat("TreeCanopy", (0.28, 0.48, 0.26), roughness=0.70)
    mat_tree_leaf2 = create_mat("TreeCanopy2", (0.34, 0.54, 0.30), roughness=0.70)
    mat_lamp_glow = create_mat("LampGlow", (1.0, 0.92, 0.70), roughness=0.15, emissive=(1.0, 0.92, 0.65), emit_strength=2.2)
    mat_win_lit = create_mat("WindowLit", (0.98, 0.90, 0.65), roughness=0.2, emissive=(0.98, 0.90, 0.65), emit_strength=1.8)
    mat_win_dark = create_mat("WindowDark", (0.28, 0.34, 0.42), roughness=0.3)
    mat_awning_red = create_mat("AwningRed", (0.78, 0.32, 0.28), roughness=0.6)
    mat_awning_white = create_mat("AwningWhite", (0.92, 0.90, 0.86), roughness=0.6)
    mat_roof_slate = create_mat("SlateRoof", (0.28, 0.30, 0.34), roughness=0.55)

    bldg_mats = [
        create_mat("BldgSage", (0.50, 0.62, 0.54), roughness=0.65),
        create_mat("BldgTerracotta", (0.76, 0.46, 0.38), roughness=0.65),
        create_mat("BldgDenim", (0.42, 0.54, 0.65), roughness=0.65),
        create_mat("BldgCream", (0.88, 0.82, 0.70), roughness=0.65),
        create_mat("BldgRose", (0.78, 0.54, 0.56), roughness=0.65),
    ]

    # Road Surface (Y = -0.5 to 3.5)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 1.2, -0.05))
    road = bpy.context.active_object
    road.name = "RoadSurface"
    road.scale = (28.0, 4.4, 0.1)
    road.data.materials.append(mat_asphalt)

    # 7 3D Zebra Stripes
    for zi in range(7):
        zx = -1.05 + zi * 0.35
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(zx, 1.2, 0.01))
        strip = bpy.context.active_object
        strip.name = f"ZebraStrip_{zi}"
        strip.scale = (0.24, 4.2, 0.02)
        strip.data.materials.append(mat_zebra)

    # Near Sidewalk: EXTENDED DOWNWARD to Y = -6.5 so it completely covers the bottom view!
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -3.5, 0.06))
    near_walk = bpy.context.active_object
    near_walk.name = "NearSidewalk"
    near_walk.scale = (28.0, 5.5, 0.12)
    near_walk.data.materials.append(mat_sidewalk_near)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.95, 0.08))
    near_curb = bpy.context.active_object
    near_curb.name = "NearCurb"
    near_curb.scale = (28.0, 0.15, 0.16)
    near_curb.data.materials.append(mat_curb)

    # Far Sidewalk & Curb (Y = 3.4 to 6.2)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 4.8, 0.06))
    far_walk = bpy.context.active_object
    far_walk.name = "FarSidewalk"
    far_walk.scale = (28.0, 2.8, 0.12)
    far_walk.data.materials.append(mat_sidewalk)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 3.45, 0.08))
    far_curb = bpy.context.active_object
    far_curb.name = "FarCurb"
    far_curb.scale = (28.0, 0.15, 0.16)
    far_curb.data.materials.append(mat_curb)

    # 3D Traffic Light Post on Far Sidewalk (X = 1.6, Y = 3.8, Z = 0.12)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=0.35, vertices=20, location=(1.6, 3.8, 0.30))
    tl_base = bpy.context.active_object
    smooth_mesh(tl_base)
    tl_base.data.materials.append(mat_iron)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=3.2, vertices=16, location=(1.6, 3.8, 1.8))
    tl_pole = bpy.context.active_object
    smooth_mesh(tl_pole)
    tl_pole.data.materials.append(mat_iron)

    bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=0.6, vertices=12, location=(1.35, 3.8, 2.8))
    tl_arm = bpy.context.active_object
    smooth_mesh(tl_arm)
    tl_arm.rotation_euler = (0, math.radians(90), 0)
    tl_arm.data.materials.append(mat_iron)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(1.05, 3.8, 2.8))
    tl_box = bpy.context.active_object
    tl_box.name = "TrafficLightHousing"
    tl_box.scale = (0.35, 0.30, 0.95)
    tl_box.data.materials.append(mat_iron)

    lens_configs = [
        (0.30, mat_light_red, "LensRed"),
        (0.00, mat_light_amber, "LensAmber"),
        (-0.30, mat_light_green, "LensGreen"),
    ]
    for lz_off, l_mat, l_name in lens_configs:
        bpy.ops.mesh.primitive_cone_add(radius1=0.12, radius2=0.08, depth=0.14, vertices=16, location=(1.05, 3.62, 2.8 + lz_off))
        visor = bpy.context.active_object
        smooth_mesh(visor)
        visor.rotation_euler = (math.radians(90), 0, 0)
        visor.data.materials.append(mat_iron)

        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.10, subdivisions=2, location=(1.05, 3.64, 2.8 + lz_off))
        lens = bpy.context.active_object
        lens.name = l_name
        smooth_mesh(lens)
        lens.data.materials.append(l_mat)

    # Streetlamps (Y = 4.0)
    for lx in [-4.5, -1.8, 3.8, 7.5]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=3.0, vertices=12, location=(lx, 4.0, 1.6))
        lamp_pole = bpy.context.active_object
        smooth_mesh(lamp_pole)
        lamp_pole.data.materials.append(mat_iron)

        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.18, subdivisions=2, location=(lx, 4.0, 3.1))
        lamp_bulb = bpy.context.active_object
        smooth_mesh(lamp_bulb)
        lamp_bulb.data.materials.append(mat_lamp_glow)

    # Street Trees (Y = 4.4, fully in frame!)
    for tx in [-6.5, -3.2, 5.2, 9.2]:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.55, minor_radius=0.04, location=(tx, 4.4, 0.13))
        grate = bpy.context.active_object
        smooth_mesh(grate)
        grate.data.materials.append(mat_iron)

        bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=2.4, vertices=16, location=(tx, 4.4, 1.3))
        trunk = bpy.context.active_object
        smooth_mesh(trunk)
        trunk.data.materials.append(mat_tree_wood)

        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.95, subdivisions=2, location=(tx, 4.4, 2.7))
        canopy = bpy.context.active_object
        smooth_mesh(canopy)
        canopy.data.materials.append(mat_tree_leaf)

        for l_dx, l_dy, l_dz, l_rad in [(-0.45, -0.15, -0.1, 0.65), (0.45, -0.1, -0.15, 0.62), (0.0, 0.35, 0.15, 0.60)]:
            bpy.ops.mesh.primitive_ico_sphere_add(radius=l_rad, subdivisions=2, location=(tx + l_dx, 4.4 + l_dy, 2.7 + l_dz))
            clobe = bpy.context.active_object
            smooth_mesh(clobe)
            clobe.data.materials.append(mat_tree_leaf2)

    # European Townhouses: set back to Y = 7.5, b_height = 4.8 to 5.6 so roofs and dormers show!
    bldg_xs = [-10.0, -6.0, -2.0, 2.0, 6.0, 10.0]
    for bi, bx in enumerate(bldg_xs):
        mat_b = bldg_mats[bi % len(bldg_mats)]
        b_height = 4.6 + (bi % 3) * 0.5
        
        # Facade body
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 7.5, b_height * 0.5))
        bldg = bpy.context.active_object
        bldg.name = f"Townhouse_{bi}"
        bldg.scale = (3.8, 2.4, b_height)
        bldg.data.materials.append(mat_b)

        # Mansard slate roof
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 7.5, b_height + 0.55))
        rf = bpy.context.active_object
        rf.scale = (4.0, 2.6, 1.1)
        rf.data.materials.append(mat_roof_slate)

        # Chimney stack
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx + 1.2, 7.5, b_height + 1.4))
        chim = bpy.context.active_object
        chim.scale = (0.45, 0.45, 0.8)
        chim.data.materials.append(mat_b)

        # Ground-floor boutique shopfront awning
        if bi % 2 == 1:
            for ai in range(6):
                a_mat = mat_awning_red if ai % 2 == 0 else mat_awning_white
                bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx - 1.25 + ai * 0.5, 6.2, 1.9))
                awn = bpy.context.active_object
                awn.scale = (0.48, 0.7, 0.08)
                awn.rotation_euler = (math.radians(22), 0, 0)
                awn.data.materials.append(a_mat)

        # Windows with trim
        for floor in range(2):
            for col in [-1.1, 1.1]:
                w_mat = mat_win_lit if (bi + floor) % 2 == 0 else mat_win_dark
                bpy.ops.mesh.primitive_cube_add(size=0.6, location=(bx + col, 6.25, 1.2 + floor * 1.5))
                win = bpy.context.active_object
                win.scale = (0.9, 0.1, 1.1)
                win.data.materials.append(w_mat)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("SUCCESS: Exported traffic_street.glb")


# =========================================================================
# 4. BUILD WORKSHOP (build_workshop.glb)
# Seamless solid honey-oak carpenter workbench with carved tool tray,
# blueprint assembly mat, artisan pegboard with hand tools, and brass lamps.
# =========================================================================
def build_workshop():
    clear_scene()
    out_path = str(PROJECT_ROOT / "assets/scenes_3d/build_workshop.glb")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    mat_table = create_mat("WorkbenchOak", (0.55, 0.40, 0.26), roughness=0.55)
    mat_table_trim = create_mat("TimberTrim", (0.42, 0.30, 0.18), roughness=0.65)
    mat_tray = create_mat("PartsTrayRecess", (0.30, 0.20, 0.14), roughness=0.70)
    mat_pegboard = create_mat("PegboardWall", (0.80, 0.74, 0.66), roughness=0.65)
    mat_iron = create_mat("WorkshopIron", (0.24, 0.26, 0.28), roughness=0.35, metallic=0.85)
    mat_brass = create_mat("WorkshopBrass", (0.84, 0.70, 0.32), roughness=0.30, metallic=0.75)
    mat_lamp = create_mat("LampGlow", (1.0, 0.92, 0.70), roughness=0.2, emissive=(1.0, 0.92, 0.70), emit_strength=2.2)

    # 1. Sturdy Timber Underframe
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -1.0, -0.2))
    table_base = bpy.context.active_object
    table_base.scale = (22.0, 9.6, 0.5)
    table_base.data.materials.append(mat_table_trim)

    # 2. ONE SINGLE SOLID TABLETOP SLAB (warm honey oak, zero striped cracks!)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -1.0, 0.18))
    table_top = bpy.context.active_object
    table_top.name = "WorkbenchTopSlab"
    table_top.scale = (22.0, 9.8, 0.36)
    table_top.data.materials.append(mat_table)

    # 3. Recessed Parts Tray Trough on tabletop surface (aligned with tool picker spots at Y ≈ -1.35)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -1.35, 0.38))
    trough = bpy.context.active_object
    trough.name = "PartsTrayTrough"
    trough.scale = (14.5, 1.6, 0.04)
    trough.data.materials.append(mat_tray)

    # Brass corner bracket accents on tray
    for bx in [-7.2, 7.2]:
        bpy.ops.mesh.primitive_cube_add(size=0.35, location=(bx, -1.35, 0.40))
        b_bracket = bpy.context.active_object
        b_bracket.data.materials.append(mat_brass)

    # 4. Warm Birch Artisan Pegboard Wall (at Y = 4.8)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 4.8, 3.4))
    peg = bpy.context.active_object
    peg.name = "ToolPegboard"
    peg.scale = (20.0, 0.4, 6.2)
    peg.data.materials.append(mat_pegboard)

    # Pegboard Wall Shelf for tools
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.8, 4.5, 2.4))
    ws_shelf = bpy.context.active_object
    ws_shelf.scale = (4.5, 0.6, 0.12)
    ws_shelf.data.materials.append(mat_table_trim)

    # Hand woodworking plane on shelf
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.8, 4.45, 2.6))
    plane = bpy.context.active_object
    plane.scale = (1.2, 0.35, 0.3)
    plane.data.materials.append(mat_table_trim)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=0.2, vertices=12, location=(0.4, 4.45, 2.8))
    knob = bpy.context.active_object
    smooth_mesh(knob)
    knob.data.materials.append(mat_brass)

    # Hanging Claw Hammer
    bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=1.6, vertices=12, location=(-1.2, 4.5, 3.3))
    h_hnd = bpy.context.active_object
    smooth_mesh(h_hnd)
    h_hnd.data.materials.append(mat_table_trim)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-1.2, 4.5, 4.0))
    h_head = bpy.context.active_object
    h_head.scale = (0.7, 0.25, 0.3)
    h_head.data.materials.append(mat_iron)

    # Hanging Brass Angle Framing Square
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(2.6, 4.5, 3.4))
    square_v = bpy.context.active_object
    square_v.scale = (0.2, 0.06, 1.6)
    square_v.data.materials.append(mat_brass)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(3.2, 4.5, 2.7))
    square_h = bpy.context.active_object
    square_h.scale = (1.2, 0.06, 0.2)
    square_h.data.materials.append(mat_brass)

    # Row of 3 Woodworking Chisels
    for ci, cx in enumerate([-3.4, -4.0, -4.6]):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=0.8, vertices=12, location=(cx, 4.5, 3.6))
        c_hnd = bpy.context.active_object
        smooth_mesh(c_hnd)
        c_hnd.data.materials.append(mat_table_trim)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, 4.5, 3.0))
        c_blade = bpy.context.active_object
        c_blade.scale = (0.12, 0.04, 0.6)
        c_blade.data.materials.append(mat_iron)

    # Hanging Copper Wire Spool
    bpy.ops.mesh.primitive_torus_add(major_radius=0.35, minor_radius=0.12, location=(4.6, 4.5, 3.5))
    spool = bpy.context.active_object
    smooth_mesh(spool)
    spool.rotation_euler = (math.radians(90), 0, 0)
    spool.data.materials.append(mat_brass)

    # Industrial Pendant Lamps with warm amber glow
    for lx in [-4.5, 4.5]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=2.4, vertices=8, location=(lx, 2.6, 5.2))
        cord = bpy.context.active_object
        cord.data.materials.append(mat_iron)

        bpy.ops.mesh.primitive_cone_add(radius1=0.75, radius2=0.2, depth=0.55, vertices=24, location=(lx, 2.6, 4.1))
        shade = bpy.context.active_object
        smooth_mesh(shade)
        shade.data.materials.append(mat_brass)

        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.32, subdivisions=2, location=(lx, 2.6, 3.85))
        bulb = bpy.context.active_object
        smooth_mesh(bulb)
        bulb.data.materials.append(mat_lamp)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("SUCCESS: Exported build_workshop.glb")


# =========================================================================
# 5. TOY ROOM STUDY (toy_room_study.glb)
# =========================================================================
def build_toy_room():
    clear_scene()
    out_path = str(PROJECT_ROOT / "assets/scenes_3d/toy_room_study.glb")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    mat_table_wood = create_mat("TableWood", (0.76, 0.62, 0.48), roughness=0.45)
    mat_shelf_wood = create_mat("ShelfWood", (0.66, 0.52, 0.38), roughness=0.5)
    mat_wall = create_mat("RoomWall", (0.92, 0.90, 0.86), roughness=0.6)
    mat_leather_mat = create_mat("LeatherMat", (0.32, 0.46, 0.38), roughness=0.6)
    mat_toy_blue = create_mat("ToyBlue", (0.36, 0.58, 0.78), roughness=0.4)
    mat_toy_red = create_mat("ToyRed", (0.80, 0.40, 0.34), roughness=0.4)
    mat_toy_yellow = create_mat("ToyYellow", (0.92, 0.76, 0.34), roughness=0.4)
    mat_pot = create_mat("PlantPot", (0.80, 0.50, 0.38), roughness=0.6)
    mat_leaf = create_mat("PlantLeaf", (0.38, 0.66, 0.40), roughness=0.5)

    # Solid seamless desk top
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -1.6, -0.1))
    table_top = bpy.context.active_object
    table_top.name = "StudyDeskTop"
    table_top.scale = (24.0, 7.8, 0.45)
    table_top.data.materials.append(mat_table_wood)

    # Sage leather desk mat
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -1.4, 0.15))
    d_mat = bpy.context.active_object
    d_mat.name = "SageDeskMat"
    d_mat.scale = (18.0, 5.0, 0.04)
    d_mat.data.materials.append(mat_leather_mat)

    # Cream plaster wall
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 3.6, 4.0))
    wall = bpy.context.active_object
    wall.name = "PlayroomWall"
    wall.scale = (24.0, 0.4, 8.0)
    wall.data.materials.append(mat_wall)

    # Shelving units
    for sx in [-7.2, 7.2]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, 3.2, 3.2))
        sh = bpy.context.active_object
        sh.scale = (3.2, 0.8, 6.0)
        sh.data.materials.append(mat_shelf_wood)

        for bi, (by_off, b_mat) in enumerate([(-0.8, mat_toy_red), (0.0, mat_toy_yellow), (0.8, mat_toy_blue)]):
            bpy.ops.mesh.primitive_cube_add(size=0.5, location=(sx + by_off, 3.0, 2.2))
            block = bpy.context.active_object
            block.data.materials.append(b_mat)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 3.2, 2.8))
    m_sh = bpy.context.active_object
    m_sh.scale = (5.5, 0.6, 0.12)
    m_sh.data.materials.append(mat_shelf_wood)

    # Ceramic potted succulent
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=0.4, vertices=20, location=(-1.8, 3.2, 3.1))
    pot = bpy.context.active_object
    smooth_mesh(pot)
    pot.data.materials.append(mat_pot)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.25, subdivisions=2, location=(-1.8, 3.2, 3.4))
    leaf = bpy.context.active_object
    smooth_mesh(leaf)
    leaf.data.materials.append(mat_leaf)

    # Row of 4 colorful picture books on shelf
    book_mats = [mat_toy_blue, mat_toy_red, mat_toy_yellow, create_mat("ToyGreen", (0.35, 0.65, 0.40), roughness=0.4)]
    for bi, (bx, b_ang) in enumerate([(-0.8, 0.0), (-0.4, 0.0), (0.0, 0.0), (0.45, -0.15)]):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 3.2, 3.3))
        bk = bpy.context.active_object
        bk.scale = (0.24, 0.55, 0.75)
        bk.rotation_euler = (0.0, b_ang, 0.0)
        bk.data.materials.append(book_mats[bi % len(book_mats)])

    # Stack of two wooden blocks on right side of shelf
    bpy.ops.mesh.primitive_cube_add(size=0.45, location=(1.6, 3.2, 3.1))
    b1 = bpy.context.active_object
    b1.data.materials.append(mat_toy_yellow)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.20, depth=0.40, vertices=16, location=(1.6, 3.2, 3.55))
    b2 = bpy.context.active_object
    smooth_mesh(b2)
    b2.data.materials.append(mat_toy_blue)

    # Warm wood wainscot paneling along base of playroom wall
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 3.5, 0.7))
    wainscot = bpy.context.active_object
    wainscot.scale = (24.0, 0.25, 1.4)
    wainscot.data.materials.append(mat_shelf_wood)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("SUCCESS: Exported toy_room_study.glb")


# =========================================================================
# 6. PLATFORMER COURSE (platformer_course.glb)
# Morandi alpine landscape: lush soothing meadow green, pine tiers,
# rolling hills, snowcapped peaks, and clouds floating high in the sky.
# =========================================================================
def build_platformer_course():
    clear_scene()
    out_path = str(PROJECT_ROOT / "assets/scenes_3d/platformer_course.glb")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    mat_grass = create_mat("GrassTop", (0.26, 0.40, 0.22), roughness=0.88)
    mat_dirt = create_mat("DirtStrata", (0.38, 0.28, 0.18), roughness=0.85)
    mat_rock = create_mat("StoneRock", (0.44, 0.46, 0.50), roughness=0.75)
    mat_wood = create_mat("WoodTrunk", (0.36, 0.26, 0.18), roughness=0.8)
    mat_pine = create_mat("PineNeedle", (0.20, 0.36, 0.22), roughness=0.75)
    mat_pine2 = create_mat("PineNeedle2", (0.24, 0.42, 0.26), roughness=0.75)
    mat_snow = create_mat("PeakSnow", (0.92, 0.94, 0.98), roughness=0.45)
    mat_cloud = create_mat("CloudVoxel", (0.94, 0.96, 0.99), roughness=0.45)

    # 1. Continuous Foreground Running Ground (X = -28 to 56)
    for fx in range(-28, 56, 4):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(fx, 0.0, -0.6))
        fg = bpy.context.active_object
        fg.name = f"FgGround_{fx}"
        fg.scale = (4.0, 7.0, 1.4)
        fg.data.materials.append(mat_grass)

        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(fx, 0.0, -1.8))
        fg_dirt = bpy.context.active_object
        fg_dirt.scale = (4.0, 7.0, 1.2)
        fg_dirt.data.materials.append(mat_dirt)

    # 2. Midground Undulating Rolling Hills (smooth-shaded)
    for hx in range(-28, 56, 4):
        height = 2.2 + math.sin(hx * 0.18) * 0.9 + math.cos(hx * 0.35) * 0.6
        bpy.ops.mesh.primitive_cylinder_add(radius=2.4, depth=height, vertices=24, location=(hx, 5.0, height * 0.5))
        hill = bpy.context.active_object
        smooth_mesh(hill)
        hill.scale = (1.5, 1.0, 1.0)
        hill.data.materials.append(mat_grass)

    # 3. Distant Alpine Mountain Peaks with Snowcaps (smooth-shaded)
    for px in range(-24, 54, 8):
        p_height = 8.0 + math.cos(px * 0.2) * 2.5
        bpy.ops.mesh.primitive_cone_add(radius1=5.5, radius2=0.5, depth=p_height, vertices=24, location=(px, 15.0, p_height * 0.5))
        peak = bpy.context.active_object
        smooth_mesh(peak)
        peak.data.materials.append(mat_rock)

        bpy.ops.mesh.primitive_cone_add(radius1=2.4, radius2=0.2, depth=3.2, vertices=24, location=(px, 15.0, p_height - 1.2))
        snow = bpy.context.active_object
        smooth_mesh(snow)
        snow.data.materials.append(mat_snow)

    # 4. Stylized Alpine Pine Trees (smooth tiers)
    for tx in range(-24, 52, 4):
        tz_base = 0.2 if tx % 3 == 0 else (1.4 + math.sin(tx * 0.18) * 0.8)
        ty = 1.5 if tx % 3 == 0 else 4.2
        bpy.ops.mesh.primitive_cylinder_add(radius=0.16, depth=1.4, vertices=12, location=(tx + 0.5, ty, tz_base + 0.7))
        trunk = bpy.context.active_object
        smooth_mesh(trunk)
        trunk.data.materials.append(mat_wood)

        for tier in range(3):
            rad = 0.90 - tier * 0.22
            fol_z = tz_base + 1.4 + tier * 0.6
            bpy.ops.mesh.primitive_cone_add(radius1=rad, radius2=0.1, depth=0.75, vertices=16, location=(tx + 0.5, ty, fol_z))
            cone = bpy.context.active_object
            smooth_mesh(cone)
            cone.data.materials.append(mat_pine if tier % 2 == 0 else mat_pine2)

    # 5. Elevated Floating Islands (Z = 5.4 to 6.2)
    island_locs = [(-14.0, 3.5, 5.4), (12.0, 3.2, 5.6), (24.0, 3.4, 5.8), (34.0, 3.8, 5.5)]
    for ix, iy, iz in island_locs:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(ix, iy, iz))
        isl_top = bpy.context.active_object
        isl_top.scale = (3.2, 2.0, 0.6)
        isl_top.data.materials.append(mat_grass)

        bpy.ops.mesh.primitive_cone_add(radius1=1.6, radius2=0.3, depth=1.5, vertices=16, location=(ix, iy, iz - 1.0))
        isl_bot = bpy.context.active_object
        smooth_mesh(isl_bot)
        isl_bot.rotation_euler = (math.radians(180), 0, 0)
        isl_bot.data.materials.append(mat_rock)

    # 6. Clouds: floating HIGH IN THE SKY (cz = 12.0 to 14.0, cy = 15.0 to 18.0)
    cloud_locs = [(-16.0, 16.0, 12.5), (-4.0, 17.5, 13.8), (8.0, 16.5, 12.4), (20.0, 18.0, 13.6), (34.0, 17.0, 12.2)]
    for cx, cy, cz in cloud_locs:
        for sub in range(4):
            sx = cx + (sub - 1.5) * 1.8
            sy = cy + (sub % 2) * 1.0
            sz = cz + math.sin(sub) * 0.35
            bpy.ops.mesh.primitive_ico_sphere_add(radius=1.1, subdivisions=2, location=(sx, sy, sz))
            c_part = bpy.context.active_object
            smooth_mesh(c_part)
            c_part.data.materials.append(mat_cloud)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("SUCCESS: Exported platformer_course.glb")


# =========================================================================
# 7. PUZZLE CHAMBER (puzzle_chamber.glb)
# Clockwork sanctuary with elevated gears and smooth ashlar stone altar.
# =========================================================================
def build_puzzle_chamber():
    clear_scene()
    out_path = str(PROJECT_ROOT / "assets/scenes_3d/puzzle_chamber.glb")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    mat_wall = create_mat("ChamberWall", (0.28, 0.32, 0.38), roughness=0.75)
    mat_floor = create_mat("ChamberFloor", (0.22, 0.24, 0.30), roughness=0.65)
    mat_bench = create_mat("AltarBench", (0.30, 0.32, 0.38), roughness=0.70)
    mat_brass = create_mat("ClockworkBrass", (0.82, 0.68, 0.32), roughness=0.35, metallic=0.75)
    mat_copper = create_mat("GearCopper", (0.76, 0.48, 0.32), roughness=0.4, metallic=0.7)
    mat_conduit_cyan = create_mat("ConduitCyan", (0.35, 0.85, 1.0), roughness=0.2, emissive=(0.40, 0.90, 1.0), emit_strength=2.2)
    mat_conduit_gold = create_mat("ConduitGold", (1.0, 0.82, 0.32), roughness=0.2, emissive=(1.0, 0.85, 0.35), emit_strength=2.2)

    # Floor
    bpy.ops.mesh.primitive_plane_add(size=30.0, location=(0.0, 4.0, 0.0))
    floor = bpy.context.active_object
    floor.data.materials.append(mat_floor)

    # Back Wall
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 6.8, 5.0))
    wall = bpy.context.active_object
    wall.scale = (28.0, 1.0, 12.0)
    wall.data.materials.append(mat_wall)

    # Elevated Clockwork Gears (framed cleanly in camera above the altar!)
    for gx, gz, gr, gmat in [(-3.2, 5.0, 1.6, mat_brass), (3.2, 5.3, 1.8, mat_copper), (0.0, 5.7, 1.4, mat_brass)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=gr, depth=0.35, vertices=32, location=(gx, 6.2, gz))
        gear = bpy.context.active_object
        smooth_mesh(gear)
        gear.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
        gear.data.materials.append(gmat)
        for t in range(8):
            ta = t * (math.pi / 4.0)
            tx = gx + math.cos(ta) * (gr + 0.25)
            tz = gz + math.sin(ta) * (gr + 0.25)
            bpy.ops.mesh.primitive_cube_add(size=0.5, location=(tx, 6.2, tz))
            tooth = bpy.context.active_object
            tooth.scale = (0.7, 0.7, 0.7)
            tooth.rotation_euler = (math.pi * 0.5, 0.0, ta)
            tooth.data.materials.append(gmat)

    # Energy Wall Conduit Line
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=22.0, vertices=16, location=(0.0, 6.1, 4.2))
    hc = bpy.context.active_object
    smooth_mesh(hc)
    hc.rotation_euler = (0.0, math.pi * 0.5, 0.0)
    hc.data.materials.append(mat_conduit_cyan)

    # Main Stone Altar Workbench (Y ≈ 2.2, Z ≈ 0.6)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 2.2, 0.6))
    bench = bpy.context.active_object
    bench.scale = (12.5, 2.6, 1.2)
    bench.data.materials.append(mat_bench)

    # Brass Track Rails along the altar surface
    for rz in [1.18, 1.22]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 2.2, rz))
        rail = bpy.context.active_object
        rail.scale = (11.8, 1.8, 0.04)
        rail.data.materials.append(mat_brass)

    # Left Energy Source Pylon (X ≈ -4.8, Y ≈ 2.2)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.75, depth=2.4, vertices=24, location=(-4.8, 2.2, 1.2))
    p1 = bpy.context.active_object
    smooth_mesh(p1)
    p1.data.materials.append(mat_bench)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.55, subdivisions=2, location=(-4.8, 2.2, 2.7))
    orb1 = bpy.context.active_object
    smooth_mesh(orb1)
    orb1.data.materials.append(mat_conduit_cyan)

    # Right Goal Energy Pylon (X ≈ +4.8, Y ≈ 2.2)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.75, depth=2.4, vertices=24, location=(4.8, 2.2, 1.2))
    p2 = bpy.context.active_object
    smooth_mesh(p2)
    p2.data.materials.append(mat_bench)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.55, subdivisions=2, location=(4.8, 2.2, 2.7))
    orb2 = bpy.context.active_object
    smooth_mesh(orb2)
    orb2.data.materials.append(mat_conduit_gold)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("SUCCESS: Exported puzzle_chamber.glb")


# =========================================================================
# 8. PARK OBSERVATORY (park_observatory.glb)
# Botanical park with cedar boardwalk, pond, and Victorian gazebo.
# =========================================================================
def build_park_observatory():
    clear_scene()
    out_path = str(PROJECT_ROOT / "assets/scenes_3d/park_observatory.glb")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    mat_grass = create_mat("ParkGrass", (0.28, 0.44, 0.24), roughness=0.85)
    mat_water = create_mat("PondWater", (0.32, 0.58, 0.82), roughness=0.15)
    mat_boardwalk = create_mat("CedarBoardwalk", (0.58, 0.42, 0.28), roughness=0.65)
    mat_stone = create_mat("LimestonePlinth", (0.68, 0.66, 0.62), roughness=0.65)
    mat_gazebo_dome = create_mat("GazeboDome", (0.42, 0.66, 0.62), roughness=0.45)
    mat_gazebo_white = create_mat("GazeboColumn", (0.92, 0.90, 0.86), roughness=0.45)
    mat_lily = create_mat("LilyPad", (0.30, 0.58, 0.32), roughness=0.6)
    mat_flower_pink = create_mat("FlowerPink", (0.90, 0.48, 0.60), roughness=0.4)
    mat_flower_yellow = create_mat("FlowerYellow", (0.94, 0.78, 0.32), roughness=0.4)

    # 1. Main Park Lawn
    bpy.ops.mesh.primitive_cylinder_add(radius=28.0, depth=1.0, vertices=48, location=(0.0, 5.0, -0.5))
    lawn = bpy.context.active_object
    smooth_mesh(lawn)
    lawn.data.materials.append(mat_grass)

    # 2. Lily Pond
    bpy.ops.mesh.primitive_cylinder_add(radius=6.5, depth=0.1, vertices=36, location=(0.0, 1.2, 0.04))
    pond = bpy.context.active_object
    smooth_mesh(pond)
    pond.scale = (1.6, 0.7, 1.0)
    pond.data.materials.append(mat_water)

    # Lily pads
    for lx, ly in [(-2.2, 1.0), (1.8, 1.4), (-0.8, 1.5), (2.8, 0.9)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=0.02, vertices=16, location=(lx, ly, 0.06))
        pad = bpy.context.active_object
        smooth_mesh(pad)
        pad.data.materials.append(mat_lily)

    # 3. Wooden Boardwalk Planks in Foreground
    for bi in range(12):
        bx = -6.6 + bi * 1.2
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, -0.6, 0.15))
        plank = bpy.context.active_object
        plank.scale = (1.1, 3.4, 0.22)
        plank.data.materials.append(mat_boardwalk)

    # 4. Stepping Stones across the pond edge
    for si, (sx, sy) in enumerate([(-1.4, 0.7), (0.0, 0.9), (1.4, 0.7)]):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.55, depth=0.18, vertices=20, location=(sx, sy, 0.12))
        s_stone = bpy.context.active_object
        smooth_mesh(s_stone)
        s_stone.data.materials.append(mat_stone)

    # 5. Grand Victorian Park Gazebo (X = 0.0, Y = 6.2)
    bpy.ops.mesh.primitive_cylinder_add(radius=3.8, depth=0.7, vertices=36, location=(0.0, 6.2, 0.35))
    g_base = bpy.context.active_object
    smooth_mesh(g_base)
    g_base.data.materials.append(mat_stone)

    # 8 Classical Fluted Columns
    for c in range(8):
        ca = c * (math.pi * 0.25)
        cx = math.cos(ca) * 3.2
        cy = 6.2 + math.sin(ca) * 3.2
        bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=3.2, vertices=16, location=(cx, cy, 2.3))
        col = bpy.context.active_object
        smooth_mesh(col)
        col.data.materials.append(mat_gazebo_white)

    # Entablature Ring
    bpy.ops.mesh.primitive_torus_add(major_radius=3.2, minor_radius=0.22, location=(0.0, 6.2, 3.9))
    ent = bpy.context.active_object
    smooth_mesh(ent)
    ent.data.materials.append(mat_gazebo_white)

    # Sage-Copper Bell Dome Roof
    bpy.ops.mesh.primitive_cone_add(radius1=3.6, radius2=0.4, depth=1.8, vertices=36, location=(0.0, 6.2, 4.8))
    dome = bpy.context.active_object
    smooth_mesh(dome)
    dome.data.materials.append(mat_gazebo_dome)

    # Dome Finial Spire
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.9, vertices=12, location=(0.0, 6.2, 6.0))
    spire = bpy.context.active_object
    smooth_mesh(spire)
    spire.data.materials.append(mat_gazebo_white)

    # Flower pedestals
    for px in [-5.8, 5.8]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, 3.4, 0.4))
        ped = bpy.context.active_object
        ped.scale = (2.4, 1.4, 0.8)
        ped.data.materials.append(mat_stone)

        for fx, f_mat in [(-0.5, mat_flower_pink), (0.5, mat_flower_yellow)]:
            bpy.ops.mesh.primitive_ico_sphere_add(radius=0.45, subdivisions=2, location=(px + fx, 3.4, 1.05))
            f_bush = bpy.context.active_object
            smooth_mesh(f_bush)
            f_bush.data.materials.append(f_mat)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("SUCCESS: Exported park_observatory.glb")


# =========================================================================
# 9. DEFENSE FORTRESS (defense_fortress.glb)
# Medieval fortress wall with battlements, royal banners, and torch sconces.
# =========================================================================
def build_defense_fortress():
    clear_scene()
    out_path = str(PROJECT_ROOT / "assets/scenes_3d/defense_fortress.glb")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    mat_wall = create_mat("FortressWall", (0.44, 0.46, 0.50), roughness=0.70)
    mat_wall_accent = create_mat("WallAccentStone", (0.38, 0.40, 0.44), roughness=0.70)
    mat_wood = create_mat("HeavyTimber", (0.50, 0.35, 0.22), roughness=0.65)
    mat_banner_blue = create_mat("RoyalBannerBlue", (0.30, 0.52, 0.80), roughness=0.55)
    mat_banner_gold = create_mat("BannerGoldEmblem", (0.90, 0.76, 0.30), roughness=0.35, metallic=0.7)
    mat_flame = create_mat("TorchFlame", (1.0, 0.78, 0.32), roughness=0.2, emissive=(1.0, 0.80, 0.35), emit_strength=2.8)
    mat_iron = create_mat("FortressIron", (0.22, 0.24, 0.26), roughness=0.4, metallic=0.8)
    mat_floor = create_mat("CourtyardPaving", (0.36, 0.38, 0.42), roughness=0.80)
    mat_flagstone1 = create_mat("FlagstoneLight", (0.42, 0.44, 0.48), roughness=0.75)
    mat_flagstone2 = create_mat("FlagstoneDark", (0.34, 0.36, 0.40), roughness=0.75)

    # Courtyard ground
    bpy.ops.mesh.primitive_plane_add(size=36.0, location=(0.0, 3.0, 0.0))
    ground = bpy.context.active_object
    ground.data.materials.append(mat_floor)

    # Courtyard Flagstone Pavers grid
    for row in range(5):
        fy = -1.2 + row * 1.05
        for col in range(12):
            fx = -8.25 + col * 1.5 + (0.75 if row % 2 == 1 else 0.0)
            f_mat = mat_flagstone1 if (row + col) % 2 == 0 else mat_flagstone2
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(fx, fy, 0.02))
            paver = bpy.context.active_object
            paver.scale = (1.40, 0.96, 0.04)
            paver.data.materials.append(f_mat)

    # Main Stone Rampart Wall (at Y = 5.2)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 5.2, 2.5))
    wall = bpy.context.active_object
    wall.name = "FortressWallBody"
    wall.scale = (24.0, 1.8, 5.0)
    wall.data.materials.append(mat_wall)

    # Ashlar Stone Course Details
    for row in range(4):
        for bi in range(8):
            bx = -10.5 + bi * 3.0 + (1.5 if row % 2 == 1 else 0.0)
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 4.28, 0.8 + row * 1.1))
            brick = bpy.context.active_object
            brick.scale = (2.4, 0.1, 0.8)
            brick.data.materials.append(mat_wall_accent)

    # Crenellated Battlements
    for ci in range(9):
        cx = -10.0 + ci * 2.5
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, 4.3, 5.4))
        merlon = bpy.context.active_object
        merlon.scale = (1.4, 0.4, 0.9)
        merlon.data.materials.append(mat_wall)

    # Timber Wall-Walk Parapet Corbel Beams
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 4.3, 4.8))
    walk = bpy.context.active_object
    walk.scale = (22.0, 0.8, 0.25)
    walk.data.materials.append(mat_wood)

    for bx in range(-5, 6):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx * 2.2, 4.4, 4.5))
        corbel = bpy.context.active_object
        corbel.scale = (0.28, 0.6, 0.5)
        corbel.data.materials.append(mat_wood)

    # Flanking Bastion Towers
    for tx in [-11.5, 11.5]:
        bpy.ops.mesh.primitive_cylinder_add(radius=1.8, depth=7.5, vertices=24, location=(tx, 4.8, 3.75))
        tower = bpy.context.active_object
        smooth_mesh(tower)
        tower.data.materials.append(mat_wall)

        bpy.ops.mesh.primitive_cone_add(radius1=2.2, radius2=0.1, depth=2.8, vertices=24, location=(tx, 4.8, 8.5))
        t_roof = bpy.context.active_object
        smooth_mesh(t_roof)
        t_roof.data.materials.append(mat_wood)

    # Royal Heraldic Banners hanging from the parapet
    for ban_x in [-4.2, 4.2]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(ban_x, 4.24, 3.4))
        banner = bpy.context.active_object
        banner.scale = (1.6, 0.04, 2.6)
        banner.data.materials.append(mat_banner_blue)

        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(ban_x, 4.22, 3.4))
        emblem = bpy.context.active_object
        emblem.scale = (0.7, 0.05, 0.7)
        emblem.data.materials.append(mat_banner_gold)

    # Cast-Iron Wall Torch Sconces
    for sx in [-7.5, 7.5]:
        bpy.ops.mesh.primitive_cube_add(size=0.4, location=(sx, 4.2, 3.2))
        sconce = bpy.context.active_object
        sconce.data.materials.append(mat_iron)

        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.22, subdivisions=2, location=(sx, 3.9, 3.5))
        flame = bpy.context.active_object
        smooth_mesh(flame)
        flame.data.materials.append(mat_flame)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("SUCCESS: Exported defense_fortress.glb")


if __name__ == "__main__":
    build_duel_arena()
    build_harvest_meadow()
    build_traffic_street()
    build_workshop()
    build_toy_room()
    build_platformer_course()
    build_puzzle_chamber()
    build_park_observatory()
    build_defense_fortress()
