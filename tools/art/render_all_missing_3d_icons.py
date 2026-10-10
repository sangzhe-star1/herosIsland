import bpy
import math
import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = PROJECT_ROOT / "assets/icons/3d"
os.makedirs(OUT_DIR, exist_ok=True)

def srgb_to_lin(c):
    return tuple(max(0.0, min(1.0, float(x))) ** 2.2 for x in c)

def reset_scene(cam_loc=(0.0, -3.2, 2.2), target_loc=(0.0, 0.0, 0.0), lens=65):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    world = bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.85, 0.90, 0.95, 1.0)
        bg.inputs["Strength"].default_value = 0.45

    # Key light: warm golden top-left
    key = bpy.data.lights.new(name="Key", type='SUN')
    key.energy = 2.8
    key.color = (1.0, 0.96, 0.88)
    ko = bpy.data.objects.new(name="Key", object_data=key)
    ko.rotation_euler = (math.radians(52), math.radians(22), math.radians(38))
    bpy.context.collection.objects.link(ko)

    # Fill light: cool ambient
    fill = bpy.data.lights.new(name="Fill", type='SUN')
    fill.energy = 1.1
    fill.color = (0.75, 0.88, 1.0)
    fo = bpy.data.objects.new(name="Fill", object_data=fill)
    fo.rotation_euler = (math.radians(-32), math.radians(-28), math.radians(-142))
    bpy.context.collection.objects.link(fo)

    # Rim light: crisp specular edge
    rim = bpy.data.lights.new(name="Rim", type='SUN')
    rim.energy = 1.5
    rim.color = (1.0, 1.0, 1.0)
    ro = bpy.data.objects.new(name="Rim", object_data=rim)
    ro.rotation_euler = (math.radians(-65), math.radians(0), math.radians(180))
    bpy.context.collection.objects.link(ro)

    target = bpy.data.objects.new("CamTarget", None)
    target.location = target_loc
    bpy.context.collection.objects.link(target)

    cam_data = bpy.data.cameras.new(name="Camera")
    cam_data.type = 'PERSP'
    cam_data.lens = lens
    cam = bpy.data.objects.new(name="Camera", object_data=cam_data)
    cam.location = cam_loc
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    track = cam.constraints.new(type='TRACK_TO')
    track.target = target
    track.track_axis = 'TRACK_NEGATIVE_Z'
    track.up_axis = 'UP_Y'

    scene = bpy.context.scene
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

def make_mat(name, srgb, roughness=0.32, metallic=0.0, emit_srgb=None, emit_strength=1.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*srgb_to_lin(srgb), 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if emit_srgb and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*srgb_to_lin(emit_srgb), 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emit_strength
    return mat

def smooth_active():
    obj = bpy.context.active_object
    if obj and obj.type == 'MESH':
        obj.data.polygons.foreach_set('use_smooth', [True] * len(obj.data.polygons))

def add_capsule(radius=0.3, depth=0.8, location=(0,0,0), rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=max(0.1, depth - radius), location=location, rotation=rotation)
    smooth_active()
    return bpy.context.active_object

def add_octahedron(radius=1.0, location=(0,0,0), rotation=(0,0,0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=location, rotation=rotation)
    smooth_active()
    return bpy.context.active_object

def render_icon(name):
    path = os.path.join(OUT_DIR, f"{name}.png")
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Rendered 3D Icon:", name)

# ------------------------------------------------------------------------------
# 1. ball
def render_ball():
    reset_scene(cam_loc=(0, -3.2, 1.8), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.1, location=(0, 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("BallRed", (0.92, 0.25, 0.22), roughness=0.25))
    # Colorful bands
    bpy.ops.mesh.primitive_torus_add(major_radius=1.12, minor_radius=0.12, location=(0, 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("BallYellow", (0.98, 0.85, 0.25), roughness=0.25))
    bpy.ops.mesh.primitive_torus_add(major_radius=1.12, minor_radius=0.12, location=(0, 0, 0), rotation=(math.radians(90), 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("BallBlue", (0.22, 0.55, 0.95), roughness=0.25))
    render_icon("ball")

# 2. picture_book
def render_picture_book():
    reset_scene(cam_loc=(0, -3.0, 2.4), target_loc=(0, 0, 0))
    # Cover
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0), rotation=(math.radians(12), math.radians(15), math.radians(-10)))
    cov = bpy.context.active_object
    cov.scale = (1.5, 1.9, 0.32)
    smooth_active()
    cov.data.materials.append(make_mat("BookBlue", (0.22, 0.48, 0.85), roughness=0.35))
    # Pages
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.06, 0.05, 0), rotation=(math.radians(12), math.radians(15), math.radians(-10)))
    pages = bpy.context.active_object
    pages.scale = (1.38, 1.82, 0.24)
    pages.data.materials.append(make_mat("Pages", (0.95, 0.94, 0.90), roughness=0.5))
    # Star emblem on cover
    bpy.ops.mesh.primitive_cylinder_add(radius=0.32, depth=0.06, location=(-0.1, -0.15, 0.18), rotation=(math.radians(12), math.radians(15), math.radians(-10)))
    emblem = bpy.context.active_object
    emblem.data.materials.append(make_mat("GoldEmblem", (1.0, 0.85, 0.32), roughness=0.25, metallic=0.85))
    render_icon("picture_book")

# 3. comic
def render_comic():
    reset_scene(cam_loc=(0, -3.0, 2.2), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0), rotation=(math.radians(10), math.radians(-12), math.radians(5)))
    com = bpy.context.active_object
    com.scale = (1.4, 1.85, 0.18)
    smooth_active()
    com.data.materials.append(make_mat("ComicYellow", (0.98, 0.82, 0.18), roughness=0.3))
    # Lightning flash on cover
    bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.06, location=(0, 0, 0.11), rotation=(math.radians(10), math.radians(-12), math.radians(5)))
    flash = bpy.context.active_object
    flash.data.materials.append(make_mat("FlashRed", (0.92, 0.24, 0.22), roughness=0.3, emit_srgb=(0.95, 0.25, 0.2), emit_strength=1.5))
    render_icon("comic")

# 4. socks
def render_socks():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    for sx, col in [(-0.45, (0.92, 0.32, 0.35)), (0.45, (0.35, 0.65, 0.95))]:
        # Ankle
        bpy.ops.mesh.primitive_cylinder_add(radius=0.38, depth=0.9, location=(sx, 0.2, 0.3), rotation=(math.radians(-15), 0, 0))
        smooth_active()
        bpy.context.active_object.data.materials.append(make_mat(f"Sock_{sx}", col, roughness=0.6))
        # Foot
        add_capsule(radius=0.35, depth=0.8, location=(sx, -0.15, -0.2), rotation=(math.radians(70), 0, 0))
        bpy.context.active_object.data.materials.append(make_mat(f"SockFoot_{sx}", col, roughness=0.6))
        # White cuff
        bpy.ops.mesh.primitive_torus_add(major_radius=0.42, minor_radius=0.12, location=(sx, 0.32, 0.75), rotation=(math.radians(-15), 0, 0))
        smooth_active()
        bpy.context.active_object.data.materials.append(make_mat(f"Cuff_{sx}", (0.95, 0.95, 0.98), roughness=0.65))
    render_icon("socks")

# 5. hat
def render_hat():
    reset_scene(cam_loc=(0, -3.2, 2.1), target_loc=(0, 0, 0))
    # Brim
    bpy.ops.mesh.primitive_cylinder_add(radius=1.35, depth=0.08, location=(0, 0, -0.3))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("HatTan", (0.88, 0.75, 0.52), roughness=0.55))
    # Crown
    bpy.ops.mesh.primitive_cylinder_add(radius=0.72, depth=0.75, location=(0, 0, 0.12))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("HatCrown", (0.88, 0.75, 0.52), roughness=0.55))
    # Red ribbon
    bpy.ops.mesh.primitive_torus_add(major_radius=0.74, minor_radius=0.08, location=(0, 0, -0.18))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("HatRibbon", (0.88, 0.25, 0.22), roughness=0.4))
    render_icon("hat")

# 6. knife
def render_knife():
    reset_scene(cam_loc=(0, -3.0, 2.0), target_loc=(0, 0, 0))
    # Handle
    add_capsule(radius=0.22, depth=1.1, location=(-0.5, 0, -0.4), rotation=(0, math.radians(45), 0))
    bpy.context.active_object.data.materials.append(make_mat("KnifeHandle", (0.98, 0.78, 0.22), roughness=0.35))
    # Blunt blade
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.4, 0, 0.4), rotation=(0, math.radians(45), 0))
    blade = bpy.context.active_object
    blade.scale = (0.35, 0.08, 1.4)
    smooth_active()
    blade.data.materials.append(make_mat("KnifeBlade", (0.85, 0.88, 0.92), roughness=0.25, metallic=0.9))
    render_icon("knife")

# 7. matches
def render_matches():
    reset_scene(cam_loc=(0, -3.0, 2.2), target_loc=(0, 0, 0))
    # Box
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.2, 0, 0))
    b = bpy.context.active_object
    b.scale = (1.1, 1.6, 0.5)
    smooth_active()
    b.data.materials.append(make_mat("MatchBox", (0.25, 0.55, 0.85), roughness=0.45))
    # Strike strip
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.38, 0, 0))
    st = bpy.context.active_object
    st.scale = (0.05, 1.55, 0.45)
    st.data.materials.append(make_mat("Strike", (0.45, 0.28, 0.22), roughness=0.85))
    # One match stick sticking out
    bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=1.2, location=(0.55, 0.2, 0.25), rotation=(math.radians(20), math.radians(15), 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("MatchWood", (0.92, 0.82, 0.65), roughness=0.6))
    # Match head
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(0.7, 0.4, 0.75))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("MatchHead", (0.92, 0.22, 0.18), roughness=0.35))
    render_icon("matches")

# 8. scissors
def render_scissors():
    reset_scene(cam_loc=(0, -3.1, 2.1), target_loc=(0, 0, 0))
    # Dual rings
    for rx, rz in [(-0.45, -0.65), (0.45, -0.65)]:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.12, location=(rx, 0, rz))
        smooth_active()
        bpy.context.active_object.data.materials.append(make_mat("ScissorsGrip", (0.32, 0.75, 0.95), roughness=0.35))
    # Blades crossing
    for ang, sx in [(-18.0, -0.15), (18.0, 0.15)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, 0, 0.45), rotation=(0, math.radians(ang), 0))
        bl = bpy.context.active_object
        bl.scale = (0.16, 0.05, 1.3)
        smooth_active()
        bl.data.materials.append(make_mat("ScissorsBlade", (0.88, 0.90, 0.94), roughness=0.22, metallic=0.9))
    render_icon("scissors")

# 9. medicine
def render_medicine():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    # Bottle
    bpy.ops.mesh.primitive_cylinder_add(radius=0.72, depth=1.3, location=(0, 0, -0.15))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("MedBottle", (0.96, 0.96, 0.98), roughness=0.3))
    # Cap
    bpy.ops.mesh.primitive_cylinder_add(radius=0.55, depth=0.45, location=(0, 0, 0.72))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("MedCap", (0.25, 0.58, 0.92), roughness=0.35))
    # Red cross
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.74, -0.15))
    c1 = bpy.context.active_object
    c1.scale = (0.55, 0.04, 0.18)
    c1.data.materials.append(make_mat("RedCross", (0.92, 0.22, 0.22), roughness=0.3))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.74, -0.15))
    c2 = bpy.context.active_object
    c2.scale = (0.18, 0.04, 0.55)
    c2.data.materials.append(make_mat("RedCross2", (0.92, 0.22, 0.22), roughness=0.3))
    render_icon("medicine")

# 10. socket
def render_socket():
    reset_scene(cam_loc=(0, -3.0, 2.2), target_loc=(0, 0, 0))
    # Faceplate
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    pl = bpy.context.active_object
    pl.scale = (1.6, 1.6, 0.25)
    smooth_active()
    pl.data.materials.append(make_mat("SocketPlate", (0.95, 0.95, 0.96), roughness=0.35))
    # Two eye slits
    for ex in [-0.35, 0.35]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(ex, 0, 0.14))
        sl = bpy.context.active_object
        sl.scale = (0.10, 0.32, 0.06)
        sl.data.materials.append(make_mat("SocketSlot", (0.15, 0.16, 0.20), roughness=0.8))
    # Yellow hazard triangle
    bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=0.08, vertices=3, location=(0, 0, 0.16))
    tri = bpy.context.active_object
    tri.data.materials.append(make_mat("SocketWarn", (0.98, 0.82, 0.18), roughness=0.3, emit_srgb=(0.98, 0.82, 0.18), emit_strength=1.2))
    render_icon("socket")

# 11. pillow
def render_pillow():
    reset_scene(cam_loc=(0, -3.2, 2.2), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=(0, 0, 0))
    pil = bpy.context.active_object
    pil.scale = (1.45, 1.25, 0.55)
    smooth_active()
    pil.data.materials.append(make_mat("PillowTeal", (0.42, 0.82, 0.88), roughness=0.6))
    # Center tuft button
    bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=0.6, location=(0, 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("PillowBtn", (0.98, 0.90, 0.55), roughness=0.4))
    render_icon("pillow")

# 12. plaster
def render_plaster():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    # Crossed plaster band-aids
    for ang in [-25.0, 25.0]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0), rotation=(0, 0, math.radians(ang)))
        pl = bpy.context.active_object
        pl.scale = (1.9, 0.55, 0.12)
        smooth_active()
        pl.data.materials.append(make_mat(f"PlasterTan_{ang}", (0.92, 0.78, 0.62), roughness=0.65))
    # Red heart in center
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.25, location=(-0.1, 0, 0.1))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("HeartRed", (0.95, 0.25, 0.28), roughness=0.35))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.25, location=(0.1, 0, 0.1))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("HeartRed2", (0.95, 0.25, 0.28), roughness=0.35))
    render_icon("plaster")

# 13. berries
def render_berries():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    b_mat = make_mat("BerryBlue", (0.32, 0.45, 0.88), roughness=0.25)
    for bx, by, bz in [(-0.4, -0.2, 0), (0.4, -0.2, 0), (0, 0.35, 0.3)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.48, location=(bx, by, bz))
        smooth_active()
        bpy.context.active_object.data.materials.append(b_mat)
    # Green leaf
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.45, 0.8), rotation=(math.radians(25), 0, 0))
    leaf = bpy.context.active_object
    leaf.scale = (0.55, 0.35, 0.08)
    smooth_active()
    leaf.data.materials.append(make_mat("BerryLeaf", (0.35, 0.75, 0.35), roughness=0.4))
    render_icon("berries")

# 14. fish
def render_fish():
    reset_scene(cam_loc=(0, -3.2, 1.9), target_loc=(0, 0, 0))
    # Body
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=(0, 0, 0))
    body = bpy.context.active_object
    body.scale = (1.3, 0.75, 0.85)
    smooth_active()
    body.data.materials.append(make_mat("FishOrange", (0.98, 0.55, 0.20), roughness=0.3))
    # Tail fin
    bpy.ops.mesh.primitive_cylinder_add(radius=0.55, depth=0.1, location=(-1.3, 0, 0), rotation=(0, math.radians(90), 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("FishTail", (0.98, 0.75, 0.25), roughness=0.35))
    # White stripe
    bpy.ops.mesh.primitive_torus_add(major_radius=0.76, minor_radius=0.1, location=(0.1, 0, 0), rotation=(0, math.radians(90), 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("FishStripe", (0.96, 0.96, 0.98), roughness=0.35))
    # Eye
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=(0.75, -0.65, 0.2))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("FishEye", (0.12, 0.12, 0.15), roughness=0.2))
    render_icon("fish")

# 15. blanket
def render_blanket():
    reset_scene(cam_loc=(0, -3.2, 2.3), target_loc=(0, 0, 0))
    for lz, col in [(0.0, (0.98, 0.82, 0.85)), (0.35, (0.95, 0.90, 0.72)), (0.7, (0.75, 0.88, 0.95))]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, lz))
        b = bpy.context.active_object
        b.scale = (1.6, 1.3, 0.28)
        smooth_active()
        b.data.materials.append(make_mat(f"Blanket_{lz}", col, roughness=0.6))
    render_icon("blanket")

# 16. scarf
def render_scarf():
    reset_scene(cam_loc=(0, -3.2, 2.2), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.95, minor_radius=0.28, location=(0, 0, 0.2))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("ScarfRed", (0.88, 0.28, 0.32), roughness=0.65))
    # Tail
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.55, -0.65, -0.4), rotation=(math.radians(20), math.radians(15), 0))
    t = bpy.context.active_object
    t.scale = (0.45, 0.18, 0.95)
    smooth_active()
    t.data.materials.append(make_mat("ScarfTail", (0.88, 0.28, 0.32), roughness=0.65))
    render_icon("scarf")

# 17. party_hat
def render_party_hat():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cone_add(radius1=0.85, depth=1.6, location=(0, 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("PartyCone", (0.95, 0.35, 0.75), roughness=0.35))
    # Pom-pom top
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.24, location=(0, 0, 0.88))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("PomPom", (0.98, 0.88, 0.25), roughness=0.55, emit_srgb=(1.0, 0.88, 0.25), emit_strength=1.5))
    render_icon("party_hat")

# 18. sunglasses
def render_sunglasses():
    reset_scene(cam_loc=(0, -3.0, 1.8), target_loc=(0, 0, 0))
    # Frame
    m_frame = make_mat("GlassesFrame", (0.98, 0.82, 0.20), roughness=0.3)
    m_lens = make_mat("GlassesLens", (0.12, 0.14, 0.18), roughness=0.15, metallic=0.6)
    for lx in [-0.62, 0.62]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(lx, 0, 0))
        fr = bpy.context.active_object
        fr.scale = (0.95, 0.12, 0.65)
        smooth_active()
        fr.data.materials.append(m_frame)

        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(lx, -0.04, 0))
        ln = bpy.context.active_object
        ln.scale = (0.82, 0.08, 0.52)
        smooth_active()
        ln.data.materials.append(m_lens)
    # Bridge
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.15))
    br = bpy.context.active_object
    br.scale = (0.35, 0.10, 0.12)
    br.data.materials.append(m_frame)
    render_icon("sunglasses")

# 19. cape_red
def render_cape_red():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.9, depth=1.5, vertices=16, location=(0, 0, -0.1), rotation=(math.radians(15), 0, 0))
    cp = bpy.context.active_object
    cp.scale = (1.1, 0.45, 1.0)
    smooth_active()
    cp.data.materials.append(make_mat("CapeCrimson", (0.90, 0.18, 0.22), roughness=0.4))
    # Golden brooch
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.22, location=(0, -0.32, 0.65))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("BroochGold", (1.0, 0.85, 0.32), roughness=0.25, metallic=0.85))
    render_icon("cape_red")

# 20. wings
def render_wings():
    reset_scene(cam_loc=(0, -3.2, 1.8), target_loc=(0, 0, 0))
    w_mat = make_mat("WingsMat", (0.92, 0.96, 1.0), roughness=0.3, emit_srgb=(0.8, 0.92, 1.0), emit_strength=1.8)
    for wx, ang in [(-0.65, -24.0), (0.65, 24.0)]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(wx, 0, 0), rotation=(0, 0, math.radians(ang)))
        w = bpy.context.active_object
        w.scale = (0.9, 0.12, 1.4)
        smooth_active()
        w.data.materials.append(w_mat)
    render_icon("wings")

# 21. cowboy_hat
def render_cowboy_hat():
    reset_scene(cam_loc=(0, -3.2, 2.2), target_loc=(0, 0, 0))
    # Rolled brim
    bpy.ops.mesh.primitive_cylinder_add(radius=1.45, depth=0.08, location=(0, 0, -0.2))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("CowboyBrim", (0.58, 0.38, 0.22), roughness=0.6))
    # Crown
    bpy.ops.mesh.primitive_cylinder_add(radius=0.75, depth=0.8, location=(0, 0, 0.25))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("CowboyCrown", (0.58, 0.38, 0.22), roughness=0.6))
    render_icon("cowboy_hat")

# 22. bandana
def render_bandana():
    reset_scene(cam_loc=(0, -3.0, 2.0), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cone_add(radius1=1.1, depth=0.8, location=(0, 0, 0), rotation=(math.radians(180), 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("BandanaRed", (0.92, 0.25, 0.25), roughness=0.5))
    render_icon("bandana")

# 23. vest
def render_vest():
    reset_scene(cam_loc=(0, -3.2, 2.2), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    v = bpy.context.active_object
    v.scale = (1.4, 0.8, 1.5)
    smooth_active()
    v.data.materials.append(make_mat("VestOrange", (0.98, 0.52, 0.18), roughness=0.45))
    # Reflective silver stripe
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.42, 0))
    st = bpy.context.active_object
    st.scale = (1.35, 0.05, 0.25)
    st.data.materials.append(make_mat("Reflector", (0.95, 0.96, 0.98), roughness=0.2, metallic=0.7))
    render_icon("vest")

# 24. dress
def render_dress():
    reset_scene(cam_loc=(0, -3.2, 2.1), target_loc=(0, 0, 0))
    # Bodice
    bpy.ops.mesh.primitive_cylinder_add(radius=0.48, depth=0.6, location=(0, 0, 0.5))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("DressPink", (0.95, 0.45, 0.72), roughness=0.35))
    # Skirt
    bpy.ops.mesh.primitive_cone_add(radius1=1.15, depth=1.1, location=(0, 0, -0.3))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("SkirtPink", (0.95, 0.55, 0.82), roughness=0.4))
    render_icon("dress")

# 25. star_robe
def render_star_robe():
    reset_scene(cam_loc=(0, -3.2, 2.1), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cone_add(radius1=1.05, depth=1.6, location=(0, 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("RobeBlue", (0.24, 0.32, 0.75), roughness=0.4))
    # Golden star on chest
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.08, location=(0, -0.55, 0.35), rotation=(math.radians(15), 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("RobeStar", (1.0, 0.88, 0.32), roughness=0.25, metallic=0.85))
    render_icon("star_robe")

# 26. cap_cloud
def render_cap_cloud():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    m_cloud = make_mat("CloudCap", (0.95, 0.96, 1.0), roughness=0.5)
    for cx, cy, cz in [(-0.4, 0, 0), (0.4, 0, 0), (0, 0, 0.28), (0, -0.35, 0)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.52, location=(cx, cy, cz))
        smooth_active()
        bpy.context.active_object.data.materials.append(m_cloud)
    # Blue visor brim
    bpy.ops.mesh.primitive_cylinder_add(radius=0.85, depth=0.08, location=(0, -0.55, -0.2), rotation=(math.radians(15), 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("VisorBlue", (0.32, 0.65, 0.95), roughness=0.35))
    render_icon("cap_cloud")

# 27. board
def render_board():
    reset_scene(cam_loc=(0, -3.2, 2.3), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0), rotation=(math.radians(15), math.radians(20), math.radians(-10)))
    b = bpy.context.active_object
    b.scale = (0.75, 2.1, 0.14)
    smooth_active()
    b.data.materials.append(make_mat("BoardTeal", (0.22, 0.82, 0.78), roughness=0.25))
    # Glowing hover pads
    for pz in [-0.55, 0.55]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.22, depth=0.08, location=(0, pz, -0.12), rotation=(math.radians(15), math.radians(20), math.radians(-10)))
        smooth_active()
        bpy.context.active_object.data.materials.append(make_mat("HoverPad", (0.95, 0.25, 0.85), roughness=0.2, emit_srgb=(0.95, 0.25, 0.85), emit_strength=2.5))
    render_icon("board")

# 28. cloud
def render_cloud():
    reset_scene(cam_loc=(0, -3.2, 1.8), target_loc=(0, 0, 0))
    m_cl = make_mat("CloudWhite", (0.96, 0.97, 1.0), roughness=0.5)
    for cx, cz, r in [(-0.6, 0, 0.55), (0.6, 0, 0.55), (0, 0, 0.75), (-0.25, 0, 0.65), (0.25, 0, 0.65)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(cx, 0, cz))
        smooth_active()
        bpy.context.active_object.data.materials.append(m_cl)
    render_icon("cloud")

# 29. trail
def render_trail():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.9, minor_radius=0.15, location=(0, 0, 0), rotation=(math.radians(45), 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("TrailRainbow", (0.45, 0.85, 1.0), roughness=0.2, emit_srgb=(0.45, 0.85, 1.0), emit_strength=2.2))
    render_icon("trail")

# 30. halo
def render_halo():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.95, minor_radius=0.18, location=(0, 0, 0), rotation=(math.radians(35), 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("HaloGold", (1.0, 0.88, 0.35), roughness=0.18, emit_srgb=(1.0, 0.88, 0.35), emit_strength=2.8))
    render_icon("halo")

# 31. sticker_book
def render_sticker_book():
    reset_scene(cam_loc=(0, -3.0, 2.3), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0), rotation=(math.radians(15), math.radians(12), 0))
    sb = bpy.context.active_object
    sb.scale = (1.45, 1.85, 0.3)
    smooth_active()
    sb.data.materials.append(make_mat("StickerPurple", (0.65, 0.35, 0.85), roughness=0.35))
    render_icon("sticker_book")

# 32. tower
def render_tower():
    reset_scene(cam_loc=(0, -3.4, 2.2), target_loc=(0, 0, 0.2))
    # Base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.95, depth=0.45, location=(0, 0, -0.6))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("TowerBase", (0.45, 0.48, 0.55), roughness=0.7))
    # Spire
    bpy.ops.mesh.primitive_cylinder_add(radius=0.6, depth=1.2, location=(0, 0, 0.1))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("TowerSpire", (0.55, 0.58, 0.65), roughness=0.55))
    # Glowing crystal top
    add_octahedron(radius=0.65, location=(0, 0, 1.05))
    bpy.context.active_object.data.materials.append(make_mat("TowerCrystal", (0.35, 0.85, 1.0), roughness=0.15, emit_srgb=(0.35, 0.85, 1.0), emit_strength=3.5))
    render_icon("tower")

# 33. goo
def render_goo():
    reset_scene(cam_loc=(0, -3.2, 1.8), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.9, location=(0, 0, 0))
    g = bpy.context.active_object
    g.scale = (1.1, 0.95, 0.85)
    smooth_active()
    g.data.materials.append(make_mat("GooPurple", (0.75, 0.35, 0.90), roughness=0.15, emit_srgb=(0.65, 0.25, 0.80), emit_strength=1.5))
    render_icon("goo")

# 34. spread
def render_spread():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    m_sp = make_mat("SpreadCyan", (0.28, 0.88, 1.0), roughness=0.2, emit_srgb=(0.28, 0.88, 1.0), emit_strength=2.8)
    for ang, sx in [(-25.0, -0.45), (0.0, 0.0), (25.0, 0.45)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.16, depth=1.3, location=(sx, 0, 0), rotation=(0, math.radians(ang), 0))
        smooth_active()
        bpy.context.active_object.data.materials.append(m_sp)
    render_icon("spread")

# 35. power
def render_power():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    add_octahedron(radius=1.1, location=(0, 0, 0))
    bpy.context.active_object.data.materials.append(make_mat("PowerOrange", (1.0, 0.52, 0.18), roughness=0.2, emit_srgb=(1.0, 0.52, 0.18), emit_strength=3.2))
    render_icon("power")

# 36. slow
def render_slow():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    # Hourglass / ice crystal
    bpy.ops.mesh.primitive_cone_add(radius1=0.75, depth=0.85, location=(0, 0, 0.42), rotation=(math.radians(180), 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("SlowIce1", (0.55, 0.90, 1.0), roughness=0.2, emit_srgb=(0.55, 0.90, 1.0), emit_strength=2.0))
    bpy.ops.mesh.primitive_cone_add(radius1=0.75, depth=0.85, location=(0, 0, -0.42))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("SlowIce2", (0.55, 0.90, 1.0), roughness=0.2, emit_srgb=(0.55, 0.90, 1.0), emit_strength=2.0))
    render_icon("slow")

# 37. split
def render_split():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.9, depth=1.1, vertices=3, location=(0, 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("PrismSplit", (0.85, 0.92, 1.0), roughness=0.15, metallic=0.2, emit_srgb=(0.7, 0.85, 1.0), emit_strength=1.8))
    render_icon("split")

# 38. blast
def render_blast():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    add_octahedron(radius=1.15, location=(0, 0, 0))
    bpy.context.active_object.data.materials.append(make_mat("BlastGold", (1.0, 0.78, 0.22), roughness=0.2, emit_srgb=(1.0, 0.78, 0.22), emit_strength=3.5))
    render_icon("blast")

# 39. wave
def render_wave():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.2))
    palm = bpy.context.active_object
    palm.scale = (0.9, 0.25, 0.9)
    smooth_active()
    palm.data.materials.append(make_mat("WaveGold", (1.0, 0.85, 0.35), roughness=0.35))
    # Fingers
    for fx, fz in [(-0.35, 0.55), (-0.12, 0.65), (0.12, 0.65), (0.35, 0.55)]:
        add_capsule(radius=0.11, depth=0.45, location=(fx, 0, fz))
        bpy.context.active_object.data.materials.append(make_mat(f"Fin_{fx}", (1.0, 0.85, 0.35), roughness=0.35))
    render_icon("wave")

# 40. spin
def render_spin():
    reset_scene(cam_loc=(0, -3.2, 2.2), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.95, minor_radius=0.22, location=(0, 0, 0), rotation=(math.radians(50), math.radians(20), 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("SpinCyan", (0.32, 0.85, 0.98), roughness=0.22, emit_srgb=(0.32, 0.85, 0.98), emit_strength=2.6))
    render_icon("spin")

# 41. pose
def render_pose():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.95, depth=0.18, location=(0, 0, 0), rotation=(math.radians(90), 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("PoseMedal", (1.0, 0.85, 0.32), roughness=0.25, metallic=0.85))
    render_icon("pose")

# 42. lamp
def render_lamp():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    # Base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.65, depth=0.2, location=(0, 0, -0.6))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("LampWood", (0.55, 0.38, 0.22), roughness=0.55))
    # Stem
    bpy.ops.mesh.primitive_cylinder_add(radius=0.15, depth=0.8, location=(0, 0, -0.15))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("LampStem", (0.55, 0.38, 0.22), roughness=0.55))
    # Glowing shade
    bpy.ops.mesh.primitive_cone_add(radius1=0.85, depth=0.75, location=(0, 0, 0.45))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("LampShade", (1.0, 0.88, 0.45), roughness=0.25, emit_srgb=(1.0, 0.88, 0.45), emit_strength=2.8))
    render_icon("lamp")

# 43. sofa
def render_sofa():
    reset_scene(cam_loc=(0, -3.2, 2.2), target_loc=(0, 0, 0))
    m_sofa = make_mat("SofaCoral", (0.92, 0.48, 0.45), roughness=0.6)
    # Seat
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.2))
    s = bpy.context.active_object
    s.scale = (1.6, 1.2, 0.45)
    smooth_active()
    s.data.materials.append(m_sofa)
    # Backrest
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.52, 0.35))
    bk = bpy.context.active_object
    bk.scale = (1.6, 0.35, 0.85)
    smooth_active()
    bk.data.materials.append(m_sofa)
    render_icon("sofa")

# 44. shelf
def render_shelf():
    reset_scene(cam_loc=(0, -3.2, 2.2), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    sh = bpy.context.active_object
    sh.scale = (1.85, 0.75, 0.16)
    smooth_active()
    sh.data.materials.append(make_mat("ShelfWood", (0.58, 0.42, 0.26), roughness=0.5))
    render_icon("shelf")

# 45. soil
def render_soil():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cylinder_add(radius=1.15, depth=0.45, location=(0, 0, -0.2))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("SoilEarth", (0.38, 0.25, 0.18), roughness=0.85))
    # Little green sprout
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.25), rotation=(0, math.radians(25), 0))
    sp = bpy.context.active_object
    sp.scale = (0.15, 0.08, 0.45)
    smooth_active()
    sp.data.materials.append(make_mat("SproutLeaf", (0.35, 0.85, 0.35), roughness=0.35))
    render_icon("soil")

# 46. plank
def render_plank():
    reset_scene(cam_loc=(0, -3.2, 2.2), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0), rotation=(math.radians(12), math.radians(18), math.radians(-10)))
    pl = bpy.context.active_object
    pl.scale = (0.75, 2.1, 0.22)
    smooth_active()
    pl.data.materials.append(make_mat("PlankOak", (0.75, 0.58, 0.35), roughness=0.55))
    render_icon("plank")

# 47. dish
def render_dish():
    reset_scene(cam_loc=(0, -3.2, 2.2), target_loc=(0, 0, 0))
    # Bowl
    bpy.ops.mesh.primitive_cylinder_add(radius=1.05, depth=0.55, location=(0, 0, -0.15))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("DishBowl", (0.95, 0.94, 0.92), roughness=0.25))
    # Golden stew
    bpy.ops.mesh.primitive_cylinder_add(radius=0.92, depth=0.1, location=(0, 0, 0.05))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("DishSoup", (0.95, 0.72, 0.25), roughness=0.2))
    render_icon("dish")

# 48. ear
def render_ear():
    reset_scene(cam_loc=(0, -3.2, 2.0), target_loc=(0, 0, 0))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.75, minor_radius=0.35, location=(0, 0, 0), rotation=(math.radians(20), 0, 0))
    smooth_active()
    bpy.context.active_object.data.materials.append(make_mat("EarSkin", (0.95, 0.78, 0.65), roughness=0.5))
    render_icon("ear")

def main():
    renders = [
        render_ball, render_picture_book, render_comic, render_socks, render_hat,
        render_knife, render_matches, render_scissors, render_medicine, render_socket,
        render_pillow, render_plaster, render_berries, render_fish, render_blanket,
        render_scarf, render_party_hat, render_sunglasses, render_cape_red, render_wings,
        render_cowboy_hat, render_bandana, render_vest, render_dress, render_star_robe,
        render_cap_cloud, render_board, render_cloud, render_trail, render_halo,
        render_sticker_book, render_tower, render_goo, render_spread, render_power,
        render_slow, render_split, render_blast, render_wave, render_spin,
        render_pose, render_lamp, render_sofa, render_shelf, render_soil,
        render_plank, render_dish, render_ear
    ]
    for r in renders:
        r()
    print("ALL 48 MISSING 3D ICONS RENDERED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
