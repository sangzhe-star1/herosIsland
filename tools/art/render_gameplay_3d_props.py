import bpy
import math
import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = PROJECT_ROOT / "assets/props_3d"
os.makedirs(OUT_DIR, exist_ok=True)

def reset_scene(cam_loc=(0.0, -3.2, 2.2), target_loc=(0.0, 0.0, 0.0)):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    world = bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.75, 0.80, 0.85, 1.0)
        bg.inputs["Strength"].default_value = 0.35

    # Key light (warm golden sunlight from top-left)
    key_data = bpy.data.lights.new(name="KeyLight", type='SUN')
    key_data.energy = 2.2
    key_data.color = (1.0, 0.96, 0.88)
    key_obj = bpy.data.objects.new(name="KeyLight", object_data=key_data)
    key_obj.rotation_euler = (math.radians(50), math.radians(25), math.radians(35))
    bpy.context.collection.objects.link(key_obj)

    # Fill light (cool sky ambient from opposite side)
    fill_data = bpy.data.lights.new(name="FillLight", type='SUN')
    fill_data.energy = 0.85
    fill_data.color = (0.72, 0.82, 0.98)
    fill_obj = bpy.data.objects.new(name="FillLight", object_data=fill_data)
    fill_obj.rotation_euler = (math.radians(-30), math.radians(-30), math.radians(-140))
    bpy.context.collection.objects.link(fill_obj)

    # Camera Target
    target = bpy.data.objects.new("CamTarget", None)
    target.location = target_loc
    bpy.context.collection.objects.link(target)

    # Camera
    cam_data = bpy.data.cameras.new(name="Camera")
    cam_data.type = 'PERSP'
    cam_data.lens = 65
    cam_obj = bpy.data.objects.new(name="Camera", object_data=cam_data)
    cam_obj.location = cam_loc
    bpy.context.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

    # Track to constraint ensures object is 100% perfectly centered
    track = cam_obj.constraints.new(type='TRACK_TO')
    track.target = target
    track.track_axis = 'TRACK_NEGATIVE_Z'
    track.up_axis = 'UP_Y'

    # Render settings
    scene = bpy.context.scene
    # In Blender 4/5, engine might be BLENDER_EEVEE or BLENDER_EEVEE_NEXT
    try:
        scene.render.engine = 'BLENDER_EEVEE'
    except:
        pass
    scene.render.resolution_x = 384
    scene.render.resolution_y = 384
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

def srgb_to_lin(c):
    return tuple(x ** 2.2 for x in c)

def make_mat(name, srgb, roughness=0.45, metallic=0.0, emission_srgb=None, emission_strength=1.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        lin = srgb_to_lin(srgb)
        bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if emission_srgb and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*srgb_to_lin(emission_srgb), 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat

def render_out(filename):
    path = os.path.join(OUT_DIR, filename)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Rendered:", path)

# ==============================================================================
# 1. 3D ISOMETRIC TOY CRATES
# ==============================================================================
CRATE_COLORS = {
    "blue": (0.35, 0.55, 0.78),
    "green": (0.32, 0.58, 0.38),
    "orange": (0.82, 0.45, 0.22),
    "purple": (0.58, 0.42, 0.68),
    "yellow": (0.88, 0.72, 0.28),
    "red": (0.78, 0.28, 0.26),
}

def render_toy_crates():
    for c_name, c_srgb in CRATE_COLORS.items():
        reset_scene(cam_loc=(0.0, -3.4, 2.3), target_loc=(0.0, 0.0, -0.05))
        m_slat = make_mat(f"CrateSlat_{c_name}", c_srgb, roughness=0.48)
        m_frame = make_mat("CrateFrame", (0.55, 0.40, 0.26), roughness=0.55) # honey pine frame
        m_metal = make_mat("CrateBracket", (0.28, 0.30, 0.35), roughness=0.35, metallic=0.75)
        m_shadow = make_mat("ContactShadow", (0.02, 0.03, 0.05), roughness=0.9)

        # Ground soft contact shadow
        bpy.ops.mesh.primitive_cylinder_add(radius=1.35, depth=0.01, vertices=32, location=(0, 0, -0.65))
        shadow = bpy.context.active_object
        shadow.scale = (1.2, 0.85, 1.0)
        shadow.data.materials.append(m_shadow)

        # Crate interior floor
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.55))
        floor = bpy.context.active_object
        floor.scale = (1.8, 1.2, 0.1)
        floor.data.materials.append(m_frame)

        # 4 Corner Posts
        for px, py in [(-0.95, -0.65), (0.95, -0.65), (-0.95, 0.65), (0.95, 0.65)]:
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, py, 0.0))
            post = bpy.context.active_object
            post.scale = (0.22, 0.22, 1.15)
            post.data.materials.append(m_frame)

            # Metal corner bracket cap
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, py, 0.52))
            cap = bpy.context.active_object
            cap.scale = (0.24, 0.24, 0.14)
            cap.data.materials.append(m_metal)

            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(px, py, -0.52))
            bot_cap = bpy.context.active_object
            bot_cap.scale = (0.24, 0.24, 0.14)
            bot_cap.data.materials.append(m_metal)

        # Front & Back Slats (3 horizontal slats each)
        for side_y in [-0.65, 0.65]:
            for si, sz in enumerate([-0.35, 0.0, 0.35]):
                bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, side_y, sz))
                slat = bpy.context.active_object
                slat.scale = (1.75, 0.08, 0.24)
                slat.data.materials.append(m_slat)

        # Left & Right Slats
        for side_x in [-0.95, 0.95]:
            for si, sz in enumerate([-0.35, 0.0, 0.35]):
                bpy.ops.mesh.primitive_cube_add(size=1.0, location=(side_x, 0, sz))
                slat = bpy.context.active_object
                slat.scale = (0.08, 1.15, 0.24)
                slat.data.materials.append(m_slat)

        # Central Medallion Plinth on Front Slat for badge icon
        bpy.ops.mesh.primitive_cylinder_add(radius=0.38, depth=0.08, vertices=24, location=(0, -0.70, 0.0))
        med = bpy.context.active_object
        med.rotation_euler = (math.radians(90), 0, 0)
        med.data.materials.append(m_frame)

        bpy.ops.mesh.primitive_cylinder_add(radius=0.32, depth=0.09, vertices=24, location=(0, -0.71, 0.0))
        med_inner = bpy.context.active_object
        med_inner.rotation_euler = (math.radians(90), 0, 0)
        med_inner.data.materials.append(m_metal)

        render_out(f"crate_{c_name}.png")

# ==============================================================================
# 2. 3D BUILD & REPAIR PARTS
# ==============================================================================
def render_repair_parts():
    # 2.1 Oak Plank
    reset_scene(cam_loc=(0.0, -2.8, 2.0), target_loc=(0.0, 0.0, 0.0))
    m_oak = make_mat("PartOak", (0.72, 0.50, 0.30), roughness=0.55)
    m_screw = make_mat("PartScrew", (0.24, 0.22, 0.20), roughness=0.35, metallic=0.8)
    m_shadow = make_mat("PartShadow", (0.02, 0.03, 0.05), roughness=0.9)

    # Shadow
    bpy.ops.mesh.primitive_cylinder_add(radius=1.1, depth=0.01, vertices=24, location=(0, 0, -0.15))
    s = bpy.context.active_object
    s.scale = (1.2, 0.5, 1.0)
    s.data.materials.append(m_shadow)

    # Main Plank
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.0))
    p = bpy.context.active_object
    p.scale = (2.2, 0.72, 0.22)
    p.data.materials.append(m_oak)

    # Chamfer top bevel
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.08))
    pb = bpy.context.active_object
    pb.scale = (2.12, 0.66, 0.12)
    pb.data.materials.append(m_oak)

    # Brass / Steel Screws
    for sx in [-0.85, 0.85]:
        for sy in [-0.22, 0.22]:
            bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=0.25, vertices=12, location=(sx, sy, 0.05))
            sc = bpy.context.active_object
            sc.data.materials.append(m_screw)
    render_out("part_plank_oak.png")

    # 2.2 Gold Plank
    reset_scene(cam_loc=(0.0, -2.8, 2.0), target_loc=(0.0, 0.0, 0.0))
    m_gold = make_mat("PartGold", (0.92, 0.74, 0.22), roughness=0.28, metallic=0.85)
    m_gold_screw = make_mat("GoldScrew", (0.75, 0.55, 0.15), roughness=0.25, metallic=0.9)
    m_shadow = make_mat("PartShadow", (0.02, 0.03, 0.05), roughness=0.9)

    # Shadow
    bpy.ops.mesh.primitive_cylinder_add(radius=1.1, depth=0.01, vertices=24, location=(0, 0, -0.15))
    s = bpy.context.active_object
    s.scale = (1.2, 0.5, 1.0)
    s.data.materials.append(m_shadow)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.0))
    p = bpy.context.active_object
    p.scale = (2.2, 0.72, 0.22)
    p.data.materials.append(m_gold)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.08))
    pb = bpy.context.active_object
    pb.scale = (2.12, 0.66, 0.12)
    pb.data.materials.append(m_gold)

    for sx in [-0.85, 0.85]:
        for sy in [-0.22, 0.22]:
            bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=0.25, vertices=12, location=(sx, sy, 0.05))
            sc = bpy.context.active_object
            sc.data.materials.append(m_gold_screw)
    render_out("part_plank_gold.png")

    # 2.3 Titanium Hull Plate with Cyan Energy Strip
    reset_scene(cam_loc=(0.0, -3.0, 2.2), target_loc=(0.0, 0.0, 0.0))
    m_titanium = make_mat("Titanium", (0.32, 0.36, 0.44), roughness=0.35, metallic=0.75)
    m_cyan = make_mat("CyanStrip", (0.25, 0.85, 1.0), roughness=0.15, emission_srgb=(0.25, 0.85, 1.0), emission_strength=2.5)
    m_shadow = make_mat("PartShadow", (0.02, 0.03, 0.05), roughness=0.9)

    # Shadow
    bpy.ops.mesh.primitive_cylinder_add(radius=1.2, depth=0.01, vertices=24, location=(0, 0, -0.18))
    s = bpy.context.active_object
    s.scale = (1.3, 0.75, 1.0)
    s.data.materials.append(m_shadow)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.0))
    hull = bpy.context.active_object
    hull.scale = (2.2, 1.2, 0.28)
    hull.data.materials.append(m_titanium)

    # Center Energy Conduit
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.12))
    strip = bpy.context.active_object
    strip.scale = (1.8, 0.25, 0.12)
    strip.data.materials.append(m_cyan)
    render_out("part_hull_metal.png")

    # 2.4 Brass Cogwheel
    reset_scene(cam_loc=(0.0, -3.2, 2.4), target_loc=(0.0, 0.0, 0.0))
    m_brass = make_mat("GearBrass", (0.82, 0.65, 0.24), roughness=0.30, metallic=0.8)
    m_axle = make_mat("AxleSteel", (0.22, 0.24, 0.26), roughness=0.45, metallic=0.7)
    m_shadow = make_mat("PartShadow", (0.02, 0.03, 0.05), roughness=0.9)

    # Shadow
    bpy.ops.mesh.primitive_cylinder_add(radius=0.95, depth=0.01, vertices=28, location=(0, 0, -0.15))
    s = bpy.context.active_object
    s.data.materials.append(m_shadow)

    # Center Hub
    bpy.ops.mesh.primitive_cylinder_add(radius=0.75, depth=0.22, vertices=28, location=(0, 0, 0.0))
    gear = bpy.context.active_object
    gear.data.materials.append(m_brass)

    # 8 Teeth
    for i in range(8):
        ang = i * (2.0 * math.pi / 8.0)
        tx = math.cos(ang) * 0.78
        ty = math.sin(ang) * 0.78
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(tx, ty, 0.0), rotation=(0, 0, ang))
        tooth = bpy.context.active_object
        tooth.scale = (0.32, 0.28, 0.22)
        tooth.data.materials.append(m_brass)

    # Axle Hole
    bpy.ops.mesh.primitive_cylinder_add(radius=0.28, depth=0.25, vertices=20, location=(0, 0, 0.0))
    axle = bpy.context.active_object
    axle.data.materials.append(m_axle)
    render_out("part_gear_brass.png")

    # 2.5 Weathered Broken Junk Part
    reset_scene(cam_loc=(0.0, -2.8, 2.0), target_loc=(0.0, 0.0, 0.0))
    m_junk = make_mat("PartJunk", (0.42, 0.40, 0.38), roughness=0.78)
    m_shadow = make_mat("PartShadow", (0.02, 0.03, 0.05), roughness=0.9)

    bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=0.01, vertices=24, location=(0, 0, -0.15))
    s = bpy.context.active_object
    s.scale = (1.1, 0.5, 1.0)
    s.data.materials.append(m_shadow)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.0), rotation=(0, 0, math.radians(6)))
    p = bpy.context.active_object
    p.scale = (2.0, 0.68, 0.22)
    p.data.materials.append(m_junk)
    render_out("part_junk_broken.png")

# ==============================================================================
# 3. 3D TRAFFIC LIGHT POST
# ==============================================================================
def render_traffic_light():
    for state in ["red", "green"]:
        reset_scene(cam_loc=(0.0, -6.0, 1.4), target_loc=(0.0, 0.0, 0.65))
        m_iron = make_mat("TrafficIron", (0.18, 0.20, 0.22), roughness=0.45, metallic=0.75)
        m_box = make_mat("TrafficBox", (0.14, 0.15, 0.16), roughness=0.55)
        m_red = make_mat("LightRed", (0.95, 0.18, 0.18), roughness=0.15,
                         emission_srgb=(1.0, 0.15, 0.15) if state == "red" else (0.25, 0.05, 0.05),
                         emission_strength=3.0 if state == "red" else 0.2)
        m_green = make_mat("LightGreen", (0.20, 0.95, 0.35), roughness=0.15,
                           emission_srgb=(0.20, 1.0, 0.35) if state == "green" else (0.04, 0.25, 0.08),
                           emission_strength=3.0 if state == "green" else 0.2)
        m_shadow = make_mat("TrafficShadow", (0.02, 0.03, 0.05), roughness=0.9)

        # Base Plinth & Shadow
        bpy.ops.mesh.primitive_cylinder_add(radius=0.7, depth=0.01, vertices=24, location=(0, 0, -1.2))
        s = bpy.context.active_object
        s.data.materials.append(m_shadow)

        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -1.05))
        base = bpy.context.active_object
        base.scale = (0.55, 0.55, 0.3)
        base.data.materials.append(m_iron)

        # Pole
        bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=2.4, vertices=16, location=(0, 0, 0.15))
        pole = bpy.context.active_object
        pole.data.materials.append(m_iron)

        # Signal Head Box
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.45))
        box = bpy.context.active_object
        box.scale = (0.75, 0.45, 1.55)
        box.data.materials.append(m_box)

        # Red Lamp & Visor (Top)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.12, vertices=20, location=(0, -0.22, 1.85))
        lamp_r = bpy.context.active_object
        lamp_r.rotation_euler = (math.radians(90), 0, 0)
        lamp_r.data.materials.append(m_red)

        bpy.ops.mesh.primitive_cone_add(radius1=0.32, depth=0.25, vertices=16, location=(0, -0.28, 2.05), rotation=(math.radians(35), 0, 0))
        visor_r = bpy.context.active_object
        visor_r.data.materials.append(m_iron)

        # Green Lamp & Visor (Bottom)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.12, vertices=20, location=(0, -0.22, 1.05))
        lamp_g = bpy.context.active_object
        lamp_g.rotation_euler = (math.radians(90), 0, 0)
        lamp_g.data.materials.append(m_green)

        bpy.ops.mesh.primitive_cone_add(radius1=0.32, depth=0.25, vertices=16, location=(0, -0.28, 1.25), rotation=(math.radians(35), 0, 0))
        visor_g = bpy.context.active_object
        visor_g.data.materials.append(m_iron)

        render_out(f"traffic_light_post_{state}.png")

# ==============================================================================
# 4. 3D PUZZLE RUNE BUTTONS
# ==============================================================================
def render_puzzle_runes():
    RUNE_COLORS = {
        "red": (0.92, 0.28, 0.24),
        "blue": (0.24, 0.58, 0.95),
        "yellow": (0.95, 0.78, 0.20),
        "green": (0.28, 0.85, 0.42),
    }
    for r_name, r_srgb in RUNE_COLORS.items():
        reset_scene(cam_loc=(0.0, -2.4, 1.8), target_loc=(0.0, 0.0, 0.08))
        m_stone = make_mat("PlinthStone", (0.34, 0.36, 0.40), roughness=0.72)
        m_rim = make_mat("PlinthBronze", (0.58, 0.48, 0.28), roughness=0.40, metallic=0.65)
        m_gem = make_mat(f"RuneGem_{r_name}", r_srgb, roughness=0.20, emission_srgb=r_srgb, emission_strength=2.8)
        m_shadow = make_mat("RuneShadow", (0.02, 0.03, 0.05), roughness=0.9)

        # Shadow
        bpy.ops.mesh.primitive_cylinder_add(radius=0.85, depth=0.01, vertices=28, location=(0, 0, -0.15))
        s = bpy.context.active_object
        s.data.materials.append(m_shadow)

        # Hexagonal Stone Base
        bpy.ops.mesh.primitive_cylinder_add(radius=0.75, depth=0.25, vertices=6, location=(0, 0, 0.0))
        base = bpy.context.active_object
        base.data.materials.append(m_stone)

        # Beveled Bronze Rim
        bpy.ops.mesh.primitive_cylinder_add(radius=0.68, depth=0.15, vertices=6, location=(0, 0, 0.15))
        rim = bpy.context.active_object
        rim.data.materials.append(m_rim)

        # Glowing Rune Core Gem
        bpy.ops.mesh.primitive_cylinder_add(radius=0.48, depth=0.18, vertices=6, location=(0, 0, 0.22))
        gem = bpy.context.active_object
        gem.data.materials.append(m_gem)

        render_out(f"rune_button_{r_name}.png")

# ==============================================================================
# 5. 3D ENERGY CRYSTALS / ORBS
# ==============================================================================
def render_crystals():
    # Cyan Crystal Orb
    reset_scene(cam_loc=(0.0, -2.8, 1.6), target_loc=(0.0, 0.0, 0.0))
    m_crystal_cyan = make_mat("CrystalCyan", (0.28, 0.88, 1.0), roughness=0.15, emission_srgb=(0.28, 0.88, 1.0), emission_strength=2.2)
    m_inner_glow = make_mat("CoreGlow", (0.9, 0.98, 1.0), roughness=0.1, emission_srgb=(1.0, 1.0, 1.0), emission_strength=4.0)

    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.75, subdivisions=2, location=(0, 0, 0.0))
    orb = bpy.context.active_object
    orb.data.materials.append(m_crystal_cyan)

    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.35, subdivisions=1, location=(0, 0, 0.0))
    core = bpy.context.active_object
    core.data.materials.append(m_inner_glow)
    render_out("crystal_orb_blue.png")

    # Golden Sun Orb
    reset_scene(cam_loc=(0.0, -2.8, 1.6), target_loc=(0.0, 0.0, 0.0))
    m_crystal_gold = make_mat("CrystalGold", (1.0, 0.82, 0.25), roughness=0.15, emission_srgb=(1.0, 0.82, 0.25), emission_strength=2.2)
    m_gold_glow = make_mat("CoreGoldGlow", (1.0, 0.95, 0.8), roughness=0.1, emission_srgb=(1.0, 1.0, 0.9), emission_strength=4.0)

    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.75, subdivisions=2, location=(0, 0, 0.0))
    orb = bpy.context.active_object
    orb.data.materials.append(m_crystal_gold)

    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.35, subdivisions=1, location=(0, 0, 0.0))
    core = bpy.context.active_object
    core.data.materials.append(m_gold_glow)
    render_out("crystal_orb_gold.png")

if __name__ == "__main__":
    print("=== RENDERING 3D GAMEPLAY PROPS ===")
    render_toy_crates()
    render_repair_parts()
    render_traffic_light()
    render_puzzle_runes()
    render_crystals()
    print("=== FINISHED RENDERING 3D PROPS ===")
