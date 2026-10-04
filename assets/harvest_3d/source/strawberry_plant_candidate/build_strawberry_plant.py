"""Re-export the reviewed strawberry body from its editable Blender source."""

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy


HERE = Path(__file__).resolve().parent
SOURCE_BLEND = HERE / "rendered" / "strawberry_plant_review.blend"
PROJECT = HERE.parents[3]
EXISTING_BERRY = PROJECT / "assets/harvest_3d/source/strawberry_readability/rendered/strawberry.glb"


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=HERE / "rendered")
    return parser.parse_args(argv)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    args = parse_args()
    out = args.out.expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)
    if not SOURCE_BLEND.exists():
        raise FileNotFoundError(f"editable source scene is missing: {SOURCE_BLEND}")

    bpy.ops.wm.open_mainfile(filepath=str(SOURCE_BLEND))
    root = bpy.data.objects.get("Strawberry Plant | ground origin")
    if root is None:
        raise RuntimeError("editable scene is missing the strawberry body root")
    slot = bpy.data.objects.get("FruitSlot | strawberry GLB center")
    if slot is None or slot.parent != root:
        raise RuntimeError("editable scene is missing the body child FruitSlot")

    scene = bpy.context.scene
    scene.render.filepath = str(out / "strawberry_plant_preview.png")
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"

    bpy.ops.object.select_all(action="DESELECT")
    export_nodes = [root, *root.children_recursive]
    for obj in export_nodes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    glb_path = out / "strawberry_plant_body.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path), export_format="GLB", use_selection=True,
        export_apply=True, export_animations=False, export_cameras=False,
        export_lights=False)
    bpy.ops.render.render(write_still=True)

    mesh_children = [obj for obj in root.children_recursive if obj.type == "MESH"]
    triangle_count = sum(sum(max(0, len(face.vertices) - 2) for face in obj.data.polygons)
                         for obj in mesh_children)
    manifest = {
        "status": "source-only visual candidate; not adopted by runtime",
        "blender_version": bpy.app.version_string,
        "source_generator": str(Path(__file__).relative_to(PROJECT)),
        "source_sha256": sha256(Path(__file__).resolve()),
        "editable_source": str(SOURCE_BLEND.relative_to(PROJECT)),
        "editable_source_sha256": sha256(SOURCE_BLEND),
        "fruit_source": str(EXISTING_BERRY.relative_to(PROJECT)),
        "ground_origin": [0.0, 0.0, 0.0],
        "fruit_slot_node": slot.name,
        "fruit_slot_center": [round(float(value), 5) for value in slot.location],
        "fruit_is_separate_harvest_target": True,
        "mesh_primitive_estimate": len(mesh_children),
        "triangle_estimate": triangle_count,
        "files": {},
    }
    for path in (glb_path, out / "strawberry_plant_preview.png", SOURCE_BLEND):
        manifest["files"][path.name] = {
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
