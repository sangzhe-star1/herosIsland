import bpy
import math
import os

def srgb_to_lin(c):
    return tuple(x ** 2.2 for x in c)

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

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

# =========================================================================
# 1. DUEL ARENA (duel_arena.glb)
# Wide, open, unobstructed circular colosseum with dedicated battle pads
# =========================================================================
def build_duel_arena():
    clear_scene()
    out_path = "/opt/heroesIsland/assets/scenes_3d/duel_arena.glb"
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    # Materials
    mat_stone = create_mat("ArenaStone", (0.42, 0.44, 0.48), roughness=0.7)
    mat_stone_dark = create_mat("ArenaStoneDark", (0.32, 0.34, 0.38), roughness=0.75)
    mat_gold_trim = create_mat("GoldTrim", (0.85, 0.68, 0.30), roughness=0.35, metallic=0.7)
    mat_hero_pad = create_mat("HeroPad", (0.28, 0.58, 0.90), roughness=0.4, emissive=(0.20, 0.55, 0.92), emit_strength=1.5)
    mat_boss_pad = create_mat("BossPad", (0.92, 0.42, 0.28), roughness=0.4, emissive=(0.95, 0.40, 0.25), emit_strength=1.5)
    mat_brass = create_mat("BrazierBrass", (0.65, 0.52, 0.30), roughness=0.4, metallic=0.6)
    mat_flame = create_mat("FlameCrystal", (1.0, 0.75, 0.30), roughness=0.2, emissive=(1.0, 0.80, 0.35), emit_strength=2.2)
    mat_ground = create_mat("GroundRock", (0.28, 0.32, 0.35), roughness=0.85)
    mat_mountains = create_mat("BgMountain", (0.35, 0.38, 0.45), roughness=0.8)

    # Main Base Ground (valley surrounding dais)
    bpy.ops.mesh.primitive_cylinder_add(radius=22.0, depth=1.0, vertices=32, location=(0.0, 2.0, -0.6))
    base = bpy.context.active_object
    base.data.materials.append(mat_ground)

    # Grand Raised Dais (Tier 1)
    bpy.ops.mesh.primitive_cylinder_add(radius=8.8, depth=0.8, vertices=32, location=(0.0, 2.0, 0.0))
    dais1 = bpy.context.active_object
    dais1.data.materials.append(mat_stone_dark)

    # Grand Raised Dais (Tier 2 - main fighting floor)
    bpy.ops.mesh.primitive_cylinder_add(radius=8.2, depth=0.5, vertices=32, location=(0.0, 2.0, 0.4))
    dais2 = bpy.context.active_object
    dais2.data.materials.append(mat_stone)

    # Golden Perimeter Inlay Ring
    bpy.ops.mesh.primitive_torus_add(major_radius=7.8, minor_radius=0.12, location=(0.0, 2.0, 0.66))
    ring = bpy.context.active_object
    ring.data.materials.append(mat_gold_trim)

    # Paver segment grooves across dais
    for a in range(8):
        angle = a * (math.pi / 4.0)
        gx = math.cos(angle) * 3.8
        gy = 2.0 + math.sin(angle) * 3.8
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(gx, gy, 0.65))
        groove = bpy.context.active_object
        groove.scale = (0.1, 7.2, 0.05)
        groove.rotation_euler = (0.0, 0.0, angle)
        groove.data.materials.append(mat_stone_dark)

    # Hero Battle Glyph Pad (aligned to 3D X ≈ -2.2, Y ≈ 0.6, Z ≈ 0.68 -> Screen (270, 520))
    bpy.ops.mesh.primitive_cylinder_add(radius=1.5, depth=0.12, vertices=24, location=(-2.2, 0.6, 0.68))
    h_pad = bpy.context.active_object
    h_pad.data.materials.append(mat_hero_pad)
    # Hero Pad outer bronze rim
    bpy.ops.mesh.primitive_torus_add(major_radius=1.5, minor_radius=0.08, location=(-2.2, 0.6, 0.72))
    h_rim = bpy.context.active_object
    h_rim.data.materials.append(mat_gold_trim)

    # Boss Battle Glyph Pad (aligned to 3D X ≈ +2.0, Y ≈ 0.6, Z ≈ 0.68 -> Screen (976, 520))
    bpy.ops.mesh.primitive_cylinder_add(radius=2.0, depth=0.12, vertices=24, location=(2.0, 0.6, 0.68))
    b_pad = bpy.context.active_object
    b_pad.data.materials.append(mat_boss_pad)
    # Boss Pad outer bronze rim
    bpy.ops.mesh.primitive_torus_add(major_radius=2.0, minor_radius=0.09, location=(2.0, 0.6, 0.72))
    b_rim = bpy.context.active_object
    b_rim.data.materials.append(mat_gold_trim)

    # Flanking Braziers (Left at X=-7.2, Right at X=+7.2, Far back at Y=7.5) - NO CENTER PILLARS!
    brazier_locs = [(-7.2, 2.0), (7.2, 2.0), (-5.5, 6.8), (5.5, 6.8)]
    for bx, by in brazier_locs:
        # Base plinth
        bpy.ops.mesh.primitive_cylinder_add(radius=0.6, depth=1.4, vertices=12, location=(bx, by, 0.7))
        p = bpy.context.active_object
        p.data.materials.append(mat_stone_dark)
        # Brass bowl
        bpy.ops.mesh.primitive_cone_add(radius1=0.75, radius2=0.3, depth=0.6, vertices=12, location=(bx, by, 1.6))
        bowl = bpy.context.active_object
        bowl.data.materials.append(mat_brass)
        # Flame Crystal core
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.35, subdivisions=2, location=(bx, by, 2.1))
        flame = bpy.context.active_object
        flame.data.materials.append(mat_flame)

    # Distant Mountains (Y = 16.0 to 22.0)
    for px, pz, pr in [(-14.0, 18.0, 8.0), (-6.0, 22.0, 10.0), (4.0, 20.0, 9.0), (12.0, 19.0, 7.5)]:
        bpy.ops.mesh.primitive_cone_add(radius1=pr, radius2=0.5, depth=14.0, vertices=6, location=(px, pz, 6.0))
        peak = bpy.context.active_object
        peak.data.materials.append(mat_mountains)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("Exported:", out_path)

# =========================================================================
# 2. PUZZLE CHAMBER (puzzle_chamber.glb)
# High-tech ancient clockwork sanctuary with open workbench and aligned pylons
# =========================================================================
def build_puzzle_chamber():
    clear_scene()
    out_path = "/opt/heroesIsland/assets/scenes_3d/puzzle_chamber.glb"
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    # Materials
    mat_wall = create_mat("ChamberWall", (0.24, 0.27, 0.34), roughness=0.75)
    mat_floor = create_mat("ChamberFloor", (0.20, 0.22, 0.28), roughness=0.65)
    mat_bench = create_mat("AltarBench", (0.38, 0.40, 0.46), roughness=0.55)
    mat_brass = create_mat("ClockworkBrass", (0.78, 0.62, 0.28), roughness=0.35, metallic=0.75)
    mat_copper = create_mat("GearCopper", (0.72, 0.45, 0.30), roughness=0.4, metallic=0.7)
    mat_conduit_cyan = create_mat("ConduitCyan", (0.35, 0.85, 1.0), roughness=0.2, emissive=(0.40, 0.90, 1.0), emit_strength=2.2)
    mat_conduit_gold = create_mat("ConduitGold", (1.0, 0.82, 0.32), roughness=0.2, emissive=(1.0, 0.85, 0.35), emit_strength=2.2)
    mat_crystal = create_mat("PylonCrystal", (0.45, 0.90, 1.0), roughness=0.15, emissive=(0.50, 0.95, 1.0), emit_strength=2.5)

    # Floor
    bpy.ops.mesh.primitive_plane_add(size=30.0, location=(0.0, 4.0, 0.0))
    floor = bpy.context.active_object
    floor.data.materials.append(mat_floor)

    # Back Wall (at Y = 6.8)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 6.8, 5.0))
    wall = bpy.context.active_object
    wall.scale = (28.0, 1.0, 12.0)
    wall.data.materials.append(mat_wall)

    # Back Wall Clockwork Gears (decorative, elevated above row line Z > 3.5)
    for gx, gz, gr, gmat in [(-3.6, 5.2, 2.2, mat_brass), (3.6, 5.5, 2.4, mat_copper), (0.0, 6.2, 1.8, mat_brass)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=gr, depth=0.35, vertices=16, location=(gx, 6.2, gz))
        gear = bpy.context.active_object
        gear.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
        gear.data.materials.append(gmat)
        # Gear teeth
        for t in range(8):
            ta = t * (math.pi / 4.0)
            tx = gx + math.cos(ta) * (gr + 0.25)
            tz = gz + math.sin(ta) * (gr + 0.25)
            bpy.ops.mesh.primitive_cube_add(size=0.5, location=(tx, 6.2, tz))
            tooth = bpy.context.active_object
            tooth.scale = (0.7, 0.7, 0.7)
            tooth.rotation_euler = (math.pi * 0.5, 0.0, ta)
            tooth.data.materials.append(gmat)

    # Energy Wall Conduits (Horizontal & Vertical Glowing Lines)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=22.0, vertices=8, location=(0.0, 6.1, 3.2))
    hc = bpy.context.active_object
    hc.rotation_euler = (0.0, math.pi * 0.5, 0.0)
    hc.data.materials.append(mat_conduit_cyan)

    # Main Stone Altar Workbench (where puzzle pieces sit: Y ≈ 2.2, Z ≈ 0.8, continuous smooth surface)
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

    # Left Energy Source Pylon (aligned with 2D Source at X ≈ -4.8, Y ≈ 2.2)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.75, depth=2.4, vertices=12, location=(-4.8, 2.2, 1.2))
    p1 = bpy.context.active_object
    p1.data.materials.append(mat_bench)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.55, subdivisions=2, location=(-4.8, 2.2, 2.7))
    orb1 = bpy.context.active_object
    orb1.data.materials.append(mat_conduit_cyan)

    # Right Goal Energy Pylon (aligned with 2D Goal at X ≈ +4.8, Y ≈ 2.2)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.75, depth=2.4, vertices=12, location=(4.8, 2.2, 1.2))
    p2 = bpy.context.active_object
    p2.data.materials.append(mat_bench)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.55, subdivisions=2, location=(4.8, 2.2, 2.7))
    orb2 = bpy.context.active_object
    orb2.data.materials.append(mat_conduit_gold)

    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB')
    print("Exported:", out_path)

if __name__ == "__main__":
    build_duel_arena()
    build_puzzle_chamber()
