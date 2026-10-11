"""Render the r5 strawberry rosette as a runtime 2.5D plant body.

The fruit stays in the existing HarvestTarget texture and state machine.  The
output uses the same transparent 512px ground-pivot convention as tomato_body.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


HERE = Path(__file__).resolve().parent
DEFAULT_SOURCE = HERE / "rendered_r5" / "strawberry_plant.glb"
DEFAULT_PROFILE = HERE.parent / "catalog_profile_candidate" / "inputs" / "frozen_render_profile.blend"
DEFAULT_FRUIT = HERE.parents[1] / "crops" / "strawberry.png"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
parser.add_argument("--fruit", type=Path, default=DEFAULT_FRUIT)
parser.add_argument("--out-dir", type=Path, default=HERE / "rendered_2d")
parser.add_argument("--ortho", type=float, default=2.95)
parser.add_argument("--tint-r", type=float, default=0.82)
parser.add_argument("--tint-g", type=float, default=0.90)
parser.add_argument("--tint-b", type=float, default=0.78)
parser.add_argument("--body-world-size", type=float, default=150.0)
parser.add_argument("--fruit-ortho", type=float, default=0.864)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
SOURCE = args.source.resolve()
PROFILE = args.profile.resolve()
FRUIT = args.fruit.resolve()
OUT = args.out_dir.resolve()
OUT.mkdir(parents=True, exist_ok=True)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def pixel(point: Vector, camera, scene) -> list[float]:
    projected = world_to_camera_view(scene, camera, point)
    return [round(projected.x * 512.0, 3), round((1.0 - projected.y) * 512.0, 3)]


def strip_volatile_png_text(path: Path) -> None:
    """Drop Blender's date and render-time text chunks for byte-stable output."""
    source = path.read_bytes()
    if not source.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError(f"not a PNG: {path}")
    chunks = [source[:8]]
    offset = 8
    while offset < len(source):
        length = struct.unpack(">I", source[offset:offset + 4])[0]
        chunk_type = source[offset + 4:offset + 8]
        end = offset + 12 + length
        if chunk_type != b"tEXt":
            chunks.append(source[offset:end])
        offset = end
        if chunk_type == b"IEND":
            break
    if offset != len(source):
        raise RuntimeError(f"unexpected trailing PNG data: {path}")
    path.write_bytes(b"".join(chunks))


if not SOURCE.is_file() or not PROFILE.is_file() or not FRUIT.is_file():
    raise FileNotFoundError(f"source/profile/fruit missing: {SOURCE}, {PROFILE}, {FRUIT}")

bpy.ops.wm.open_mainfile(filepath=str(PROFILE))
scene = bpy.context.scene
camera = scene.camera
if camera is None:
    raise RuntimeError("frozen profile has no active camera")
camera_rotation = camera.rotation_euler.copy()

# Keep only the frozen camera and soft studio lights.  This is a render-only
# scene; GLB source objects and material files are never rewritten.
for obj in list(scene.objects):
    if obj.type not in {"CAMERA", "LIGHT"}:
        obj.hide_render = True

bpy.ops.import_scene.gltf(filepath=str(SOURCE))
roots = [obj for obj in bpy.context.scene.objects
         if obj.type == "EMPTY" and obj.parent is None and obj.name.startswith("StrawberryPlant")]
if not roots:
    raise RuntimeError("imported GLB has no StrawberryPlant root")
root = roots[-1]
root.location = (0.0, 0.0, 0.0)
root.rotation_euler = (0.0, 0.0, 0.0)
root.scale = (1.0, 1.0, 1.0)

# Match the reviewed live-field material tuning while keeping every source
# mesh and its geometry intact.
for obj in root.children_recursive:
    if obj.type != "MESH":
        continue
    for material in obj.data.materials:
        if material is None or not material.use_nodes:
            continue
        principled = next((node for node in material.node_tree.nodes
                           if node.type == "BSDF_PRINCIPLED"), None)
        if principled is None:
            continue
        base = principled.inputs["Base Color"].default_value
        base[0] *= args.tint_r
        base[1] *= args.tint_g
        base[2] *= args.tint_b
        principled.inputs["Base Color"].default_value = base
        principled.inputs["Roughness"].default_value = max(0.96, principled.inputs["Roughness"].default_value)

slot = next((obj for obj in root.children_recursive
             if obj.name.split(".")[0] == "FruitSlot | strawberry GLB center"), None)
if slot is None:
    raise RuntimeError("imported plant is missing the HarvestTarget fruit-slot marker")

camera.data.type = "ORTHO"
camera.data.ortho_scale = args.ortho
camera.rotation_euler = camera_rotation
camera.location = Vector((6.7, -9.8, 6.8))
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 48
scene.cycles.seed = 20261011
scene.cycles.use_animated_seed = False
scene.cycles.use_adaptive_sampling = False
scene.cycles.use_denoising = True
scene.render.threads_mode = "FIXED"
scene.render.threads = 1
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.render.filepath = str(OUT / "strawberry_body.png")

# The ground pivot is the common pixel (256, 467) used by the mature tomato
# body renderer.  Translate only the camera so the authored root stays fixed.
ground = Vector((0.0, 0.0, 0.0))
camera.data.ortho_scale = args.ortho
bpy.context.view_layer.update()
projected_ground = world_to_camera_view(scene, camera, ground)
right = camera.rotation_euler.to_quaternion() @ Vector((1.0, 0.0, 0.0))
up = camera.rotation_euler.to_quaternion() @ Vector((0.0, 1.0, 0.0))
camera.location += right * ((projected_ground.x - 0.5) * args.ortho)
camera.location += up * ((projected_ground.y - (1.0 - 467.0 / 512.0)) * args.ortho)
bpy.context.view_layer.update()
projected_ground = world_to_camera_view(scene, camera, ground)
if abs(projected_ground.x - 0.5) > 1e-5 or abs(projected_ground.y - (1.0 - 467.0 / 512.0)) > 1e-5:
    raise RuntimeError(f"ground anchor did not land on 256,467: {projected_ground}")

slot_world = slot.matrix_world.translation.copy()
slot_pixel = pixel(slot_world, camera, scene)
body_path = OUT / "strawberry_body.png"
bpy.ops.render.render(write_still=True)
strip_volatile_png_text(body_path)

# The target fruit is the already-approved crop sprite.  Anchor it by its
# alpha-weighted visual center so the shared fruit slot lands at its center.
fruit_image = bpy.data.images.load(str(FRUIT), check_existing=False)
width, height = map(int, fruit_image.size)
rgba = list(fruit_image.pixels)
weight = sum(rgba[index + 3] for index in range(0, len(rgba), 4))
if weight <= 0.0:
    raise RuntimeError("strawberry fruit image contains no alpha")
sum_x = sum_y = 0.0
for y in range(height):
    for x in range(width):
        alpha = rgba[(y * width + x) * 4 + 3]
        sum_x += x * alpha
        sum_y += y * alpha
fruit_center = [round(sum_x / weight, 3), round(height - 1.0 - sum_y / weight, 3)]

manifest = {
    "source_glb": str(SOURCE.relative_to(HERE.parent.parent.parent.parent)),
    "source_sha256": sha256(SOURCE),
    "profile": str(PROFILE.relative_to(HERE.parent.parent.parent.parent)),
    "profile_sha256": sha256(PROFILE),
    "fruit_image": str(FRUIT.relative_to(HERE.parent.parent.parent.parent)),
    "fruit_sha256": sha256(FRUIT),
    "rendered_body_sha256": sha256(body_path),
    "blender_version": bpy.app.version_string,
    "render": {"engine": scene.render.engine, "resolution": [512, 512],
                "ortho": args.ortho, "color_management": "Standard",
                "film_transparent": True,
                "samples": scene.cycles.samples,
                "seed": scene.cycles.seed,
                "device": scene.cycles.device,
                "threads": scene.render.threads,
                "leaf_tint": [args.tint_r, args.tint_g, args.tint_b],
                "ground_anchor_pixel": [256.0, 467.0],
                "body_world_size": args.body_world_size,
                "fruit_ortho": args.fruit_ortho},
    "fruit_slot_pixel": slot_pixel,
    "fruit_center_pixel": fruit_center,
    "contact_shadow_baked": False,
    "interaction_owner": "HarvestTarget",
}
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("STRAWBERRY_BODY_RENDER", json.dumps(manifest, ensure_ascii=False))
