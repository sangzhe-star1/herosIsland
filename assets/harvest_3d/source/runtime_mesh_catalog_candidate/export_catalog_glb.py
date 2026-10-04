"""Export one shadow-free GLB per crop from the frozen sprite-pack scene."""

import bpy
import hashlib
import json
from pathlib import Path


HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parents[3]
SOURCE_BLEND = PROJECT_ROOT / "assets/harvest_3d/source/harvest_sprite_pack.blend"
CROP_MANIFEST = PROJECT_ROOT / "data/harvest_crops.json"
OUTPUT_DIR = HERE / "glb"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def sha256(path: Path) -> str:
	value = hashlib.sha256()
	with path.open("rb") as source:
		for block in iter(lambda: source.read(1024 * 1024), b""):
			value.update(block)
	return value.hexdigest()


def remove_temporary_collection(collection: bpy.types.Collection) -> None:
	for obj in list(collection.objects):
		data = obj.data
		bpy.data.objects.remove(obj, do_unlink=True)
		if data is not None and data.users == 0:
			if isinstance(data, bpy.types.Mesh):
				bpy.data.meshes.remove(data)
			elif isinstance(data, bpy.types.Curve):
				bpy.data.curves.remove(data)
	bpy.data.collections.remove(collection)


def export_collection(asset_id: str) -> dict:
	source = bpy.data.collections.get(f"ASSET | {asset_id}")
	if source is None:
		raise RuntimeError(f"Missing Blender collection for {asset_id}")

	temporary = bpy.data.collections.new(f"__GLTF_EXPORT_TEMP__ | {asset_id}")
	bpy.context.scene.collection.children.link(temporary)
	duplicates = []
	for original in source.objects:
		if original.type not in {"MESH", "CURVE"}:
			continue
		if original.name.startswith("Shadow | "):
			continue
		duplicate = original.copy()
		duplicate.data = original.data.copy()
		duplicate.matrix_world = original.matrix_world.copy()
		temporary.objects.link(duplicate)
		duplicates.append(duplicate)
	if not duplicates:
		remove_temporary_collection(temporary)
		raise RuntimeError(f"No exportable geometry for {asset_id}")

	if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
		bpy.ops.object.mode_set(mode="OBJECT")
	bpy.ops.object.select_all(action="DESELECT")
	for duplicate in duplicates:
		duplicate.select_set(True)
	bpy.context.view_layer.objects.active = duplicates[0]
	bpy.ops.object.convert(target="MESH", keep_original=False)

	mesh_objects = [obj for obj in temporary.objects if obj.type == "MESH"]
	if not mesh_objects:
		remove_temporary_collection(temporary)
		raise RuntimeError(f"Curve conversion left no meshes for {asset_id}")
	for obj in mesh_objects:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = mesh_objects[0]

	output_path = OUTPUT_DIR / f"{asset_id}.glb"
	result = bpy.ops.export_scene.gltf(
		filepath=str(output_path),
		export_format="GLB",
		export_materials="EXPORT",
		export_cameras=False,
		export_lights=False,
		export_animations=False,
		export_yup=True,
		export_apply=True,
		use_selection=True,
	)
	if "FINISHED" not in result or not output_path.is_file():
		remove_temporary_collection(temporary)
		raise RuntimeError(f"glTF export failed for {asset_id}: {result}")

	mesh_count = len(mesh_objects)
	vertex_count = sum(len(obj.data.vertices) for obj in mesh_objects)
	triangle_count = sum(
		len(poly.vertices) - 2
		for obj in mesh_objects
		for poly in obj.data.polygons
	)
	entry = {
		"id": asset_id,
		"file": output_path.name,
		"sha256": sha256(output_path),
		"bytes": output_path.stat().st_size,
		"meshes": mesh_count,
		"vertices": vertex_count,
		"triangles": triangle_count,
		"source_collection": source.name,
		"excluded_shadow_planes": True,
	}
	remove_temporary_collection(temporary)
	return entry


with CROP_MANIFEST.open("r", encoding="utf-8") as source:
	crop_ids = [entry["id"] for entry in json.load(source)]
if len(crop_ids) != 17 or len(set(crop_ids)) != len(crop_ids):
	raise RuntimeError(f"Expected 17 unique crop IDs, got {len(crop_ids)}")

entries = [export_collection(asset_id) for asset_id in crop_ids]
manifest = {
	"source_blend": str(SOURCE_BLEND.relative_to(PROJECT_ROOT)),
	"source_blend_sha256": sha256(SOURCE_BLEND),
	"crop_manifest": str(CROP_MANIFEST.relative_to(PROJECT_ROOT)),
	"catalog": entries,
}
manifest_path = HERE / "catalog_manifest.json"
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print("RUNTIME_CROP_GLB_CATALOG EXPORTED ids=%d bytes=%d manifest=%s" % (
	len(entries), sum(entry["bytes"] for entry in entries), manifest_path))
