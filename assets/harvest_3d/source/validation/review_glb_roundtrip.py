"""Blender-only GLB roundtrip review. Imports the supplied GLB without mesh/material edits.

Usage:
  Blender -b --python review_glb_roundtrip.py -- --input frozen.glb --outdir review
    [--expect-sha256 HEX] [--target-name NAME] [--samples 24]
"""
import argparse
import collections
import hashlib
import json
import math
import re
from pathlib import Path
import sys

import bpy
from mathutils import Vector


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--outdir", type=Path, required=True)
    parser.add_argument("--expect-sha256")
    parser.add_argument("--target-name")
    parser.add_argument("--samples", type=int, default=24)
    parser.add_argument("--pose-contract", type=Path, help="整株 manifest；额外核对每个独立果实的局部挂点和源比例")
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return parser.parse_args(argv)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def object_path(obj):
    parts = [obj.name]
    parent = obj.parent
    while parent is not None:
        parts.append(parent.name)
        parent = parent.parent
    return "/".join(reversed(parts))


def bounds(objects):
    points = [obj.matrix_world @ Vector(corner) for obj in objects if obj.type == "MESH" for corner in obj.bound_box]
    if not points:
        raise ValueError("No imported mesh geometry to review")
    low = Vector([min(point[axis] for point in points) for axis in range(3)])
    high = Vector([max(point[axis] for point in points) for axis in range(3)])
    return low, high, points


def normal_review(mesh):
    """Numeric anomalies are evidence for review, not a full topology validator."""
    mesh.calc_loop_triangles()
    nonfinite_positions = sum(not all(math.isfinite(axis) for axis in vertex.co) for vertex in mesh.vertices)
    degenerate, opposed = 0, 0
    for triangle in mesh.loop_triangles:
        a, b, c = (mesh.vertices[index].co for index in triangle.vertices)
        geometric = (b - a).cross(c - a)
        if geometric.length_squared <= 1e-16:
            degenerate += 1
            continue
        corners = [mesh.corner_normals[index].vector for index in triangle.loops]
        average = sum(corners, Vector())
        if average.length_squared > 1e-16 and geometric.normalized().dot(average.normalized()) < -.05:
            opposed += 1
    lengths = []
    nonfinite_normals = 0
    for item in mesh.corner_normals:
        normal = item.vector
        if not all(math.isfinite(axis) for axis in normal):
            nonfinite_normals += 1
        else:
            lengths.append(normal.length)
    edge_use = collections.Counter(edge for polygon in mesh.polygons for edge in polygon.edge_keys)
    colors = []
    for attribute in mesh.color_attributes:
        colors.append({"name": attribute.name, "domain": attribute.domain, "data_type": attribute.data_type,
                       "count": len(attribute.data),
                       "nonfinite_colors": sum(not all(math.isfinite(value) for value in item.color) for item in attribute.data)})
    return {"mesh": mesh.name, "users": mesh.users, "vertices": len(mesh.vertices), "triangles": len(mesh.loop_triangles),
            "nonfinite_positions": nonfinite_positions, "nonfinite_corner_normals": nonfinite_normals,
            "zero_corner_normals": sum(length < 1e-8 for length in lengths),
            "corner_normal_length_range": [min(lengths), max(lengths)] if lengths else [],
            "degenerate_triangles": degenerate, "triangles_opposed_to_corner_normals": opposed,
            "boundary_edges": sum(count == 1 for count in edge_use.values()),
            "edges_with_more_than_two_faces": sum(count > 2 for count in edge_use.values()),
            "color_attributes": colors}


def imported_material_review(material):
    nodes = list(material.node_tree.nodes) if material.use_nodes and material.node_tree else []
    bsdf = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
    base = bsdf.inputs["Base Color"] if bsdf is not None else None
    return {"name": material.name, "use_nodes": material.use_nodes,
            "base_color_default": list(base.default_value) if base is not None else list(material.diffuse_color),
            "base_color_linked": bool(base and base.is_linked),
            "base_color_link_sources": [{"node_type": link.from_node.type, "node_name": link.from_node.name}
                                        for link in base.links] if base is not None else [],
            "image_texture_nodes": [{"name": node.name, "image": node.image.name if node.image else None}
                                    for node in nodes if node.type == "TEX_IMAGE"],
            "vertex_color_nodes": [{"type": node.type, "name": node.name,
                                    "attribute": getattr(node, "layer_name", getattr(node, "attribute_name", None))}
                                    for node in nodes if node.type in {"VERTEX_COLOR", "ATTRIBUTE"}]}

def pose_review(targets, contract_path, digest):
    contract = json.loads(contract_path.read_text())
    if contract['files']['whole_plant_scene.glb']['sha256'] != digest:
        raise ValueError('挂点契约不是当前 GLB 的 manifest')
    anchors = contract['png_contract']['projected_fruit_anchors']
    slots = {re.search(r'F\d+$',item['name']).group():item for item in anchors}
    if len(slots) != 4 or len(targets) != 12:
        raise ValueError('整株挂点检查要求四挂点、十二独立果实')
    reviews = []
    for target in targets:
        match = re.search(r'(P\d+) (F\d+)$',target.name)
        if match is None or match.group(2) not in slots:
            raise ValueError('目标名称无法匹配挂点契约：'+target.name)
        expected = slots[match.group(2)]
        delta = (target.location-Vector(expected['plant_local_center_m'])).length
        scale_delta = (target.matrix_world.to_scale()-Vector(expected['scale'])).length
        parent_matches = target.parent is not None and target.parent.name == 'Plant'+match.group(1)[1:]
        reviews.append({'target':target.name,'local_center_m':list(target.location),
                        'position_error_m':delta,'scale_error':scale_delta,'parent_matches':parent_matches,
                        'passed':parent_matches and delta<1e-5 and scale_delta<1e-5})
    if not all(item['passed'] for item in reviews):
        raise ValueError('GLB 果实挂点/比例发生偏移：'+json.dumps(reviews))
    return {'contract_sha256':sha256(contract_path),'checked_targets':len(reviews),
            'passed':True,'targets':reviews}


def object_snapshot(objects):
    return {obj.name: {"hide_render": obj.hide_render, "hide_viewport": obj.hide_viewport,
                       "mesh_pointer": obj.data.as_pointer() if obj.type == "MESH" else None,
                       "matrix_world": [value for row in obj.matrix_world for value in row]}
            for obj in objects}


def visible_counts(objects):
    meshes = [obj for obj in objects if obj.type == "MESH"]
    return {"mesh_nodes_with_render_enabled": sum(not obj.hide_render for obj in meshes),
            "target_mesh_nodes_with_render_enabled": sum(not obj.hide_render and "HarvestTarget" in obj.name for obj in meshes),
            "target_names_with_render_enabled": sorted(obj.name for obj in meshes if not obj.hide_render and "HarvestTarget" in obj.name)}


def fit_camera(camera, objects, margin=.065):
    low, high, points = bounds(objects)
    center = (low + high) * .5
    direction = Vector((6, -8, 6)).normalized()
    camera.location = center + direction * max(10, (high - low).length * 3)
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    view_points = [camera.matrix_world.inverted() @ point for point in points]
    width = max(point.x for point in view_points) - min(point.x for point in view_points)
    height = max(point.y for point in view_points) - min(point.y for point in view_points)
    aspect = bpy.context.scene.render.resolution_x / bpy.context.scene.render.resolution_y
    camera.data.ortho_scale = max(width, height * aspect) * (1 + 2 * margin)
    camera.data.clip_start = .01
    camera.data.clip_end = 1000


def area_light(name, location, target, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size, data.color = energy, "DISK", size, color
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def main():
    args = arguments()
    source = args.input.resolve()
    if source.suffix.lower() != ".glb":
        raise ValueError("Review requires a GLB input")
    digest = sha256(source)
    if args.expect_sha256 and digest != args.expect_sha256.lower():
        raise ValueError(f"Frozen source hash mismatch: {digest}")
    output = args.outdir.resolve()
    if output == source.parent:
        raise ValueError("Use a separate review output directory")
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    bpy.context.view_layer.update()
    imported = list(bpy.context.scene.objects)
    imported_meshes = [obj for obj in imported if obj.type == "MESH"]
    unique_meshes = list({obj.data.as_pointer(): obj.data for obj in imported_meshes}.values())
    imported_materials = list({material.as_pointer(): material for obj in imported_meshes
                               for material in obj.data.materials if material is not None}.values())
    targets = sorted([obj for obj in imported_meshes if "HarvestTarget" in obj.name], key=lambda obj: obj.name)
    report = {"source": str(source), "source_sha256": digest, "blender_version": bpy.app.version_string,
              "import_method": "bpy.ops.import_scene.gltf, default importer options",
              "imported_images": [image.name for image in bpy.data.images],
              "materials": [imported_material_review(material) for material in imported_materials],
              "mesh_reviews": [normal_review(mesh) for mesh in unique_meshes],
              "hierarchy": [{"name": obj.name, "type": obj.type, "path": object_path(obj),
                             "parent": obj.parent.name if obj.parent else None,
                             "negative_world_determinant": obj.matrix_world.to_3x3().determinant() < 0}
                            for obj in imported],
              "limits": ["Offline Blender import review; not a Godot screenshot or gameplay test.",
                         "Boundary edges may be intentional leaf surfaces; numeric normal findings require visual review.",
                         "Visibility counts record per-object render flags; they do not prove input/hit-test behavior."]}
    report["summary"] = {"imported_mesh_nodes": len(imported_meshes), "unique_imported_meshes": len(unique_meshes),
                         "imported_materials": len(imported_materials), "target_mesh_nodes": len(targets),
                         "image_texture_nodes": sum(len(item["image_texture_nodes"]) for item in report["materials"]),
                         "meshes_with_color_attributes": sum(bool(item["color_attributes"]) for item in report["mesh_reviews"]),
                         "nonfinite_positions": sum(item["nonfinite_positions"] for item in report["mesh_reviews"]),
                         "nonfinite_corner_normals": sum(item["nonfinite_corner_normals"] for item in report["mesh_reviews"]),
                         "zero_corner_normals": sum(item["zero_corner_normals"] for item in report["mesh_reviews"]),
                         "unique_mesh_degenerate_triangles": sum(item["degenerate_triangles"] for item in report["mesh_reviews"]),
                         "unique_mesh_triangles_opposed_to_corner_normals": sum(item["triangles_opposed_to_corner_normals"] for item in report["mesh_reviews"])}
    if args.pose_contract:
        report['pose_contract_review'] = pose_review(targets,args.pose_contract.resolve(),digest)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = max(1, args.samples)
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.world = bpy.data.worlds.new("Review | warm neutral world")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (.74, .70, .64, 1)
    background.inputs["Strength"].default_value = .4
    low, high, _ = bounds(imported_meshes)
    center = (low + high) * .5
    extent = max(1, (high - low).length)
    bpy.ops.mesh.primitive_plane_add(size=extent * 8, location=(center.x, center.y, low.z - .005))
    ground = bpy.context.object
    ground.name = "Review helper | neutral shadow ground"
    ground_material = bpy.data.materials.new("Review helper | matte warm ground")
    ground_material.use_nodes = True
    ground_bsdf = ground_material.node_tree.nodes.get("Principled BSDF")
    ground_bsdf.inputs["Base Color"].default_value = (.70, .64, .55, 1)
    ground_bsdf.inputs["Roughness"].default_value = 1
    ground.data.materials.append(ground_material)
    area_light("Review helper | left warm key", center + Vector((-extent, -extent, extent * 1.5)), center,
               55 * extent * extent, extent, (1, .86, .70))
    area_light("Review helper | soft fill", center + Vector((extent, -.2 * extent, extent)), center,
               10 * extent * extent, extent * 1.4, (.83, .91, 1))
    camera_data = bpy.data.cameras.new("Review helper | 3/4 orthographic")
    camera_data.type = "ORTHO"
    camera = bpy.data.objects.new("Review helper | 3/4 orthographic", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    fit_camera(camera, imported_meshes)
    report["review_camera"] = {"resolution": [1280, 720], "location": list(camera.location),
                               "rotation_euler": list(camera.rotation_euler), "ortho_scale": camera_data.ortho_scale}
    scene.render.filepath = str(output / "roundtrip_full_16x9.png")
    bpy.ops.render.render(write_still=True)
    report["full_render"] = scene.render.filepath
    if args.target_name:
        selected = next((obj for obj in targets if obj.name == args.target_name), None)
        if selected is None:
            raise ValueError(f"Target mesh not found: {args.target_name}")
    else:
        selected = targets[0] if targets else None
    if selected is not None:
        before = object_snapshot(imported)
        before_counts = visible_counts(imported)
        selected.hide_render = True
        after = object_snapshot(imported)
        changed = sorted(name for name in before if before[name] != after[name])
        report["single_target_hide"] = {"target": selected.name, "before": before_counts, "after": visible_counts(imported),
                                        "changed_object_states": changed,
                                        "only_selected_target_changed": changed == [selected.name],
                                        "mesh_data_pointer_unchanged": before[selected.name]["mesh_pointer"] == after[selected.name]["mesh_pointer"]}
        scene.render.filepath = str(output / "roundtrip_one_target_hidden_16x9.png")
        bpy.ops.render.render(write_still=True)
        report["hidden_target_render"] = scene.render.filepath
        selected.hide_render = before[selected.name]["hide_render"]
        if not report["single_target_hide"]["only_selected_target_changed"]:
            raise ValueError("Hiding one target unexpectedly changed another imported object")
    basket = next((obj for obj in imported if obj.name == "Basket"), None)
    if basket is not None:
        basket_objects = [basket] + list(basket.children_recursive)
        basket_meshes = [obj for obj in basket_objects if obj.type == "MESH"]
        if basket_meshes:
            old_flags = {obj.name: obj.hide_render for obj in imported_meshes}
            members = {obj.as_pointer() for obj in basket_meshes}
            for obj in imported_meshes:
                obj.hide_render = obj.as_pointer() not in members
            fit_camera(camera, basket_meshes)
            scene.render.filepath = str(output / "roundtrip_basket_only_16x9.png")
            bpy.ops.render.render(write_still=True)
            report["basket_only_render"] = scene.render.filepath
            report["basket_subtree_meshes"] = [object_path(obj) for obj in basket_meshes]
            report["basket_subtree_suspicious_names"] = [obj.name for obj in basket_objects
                                                        if any(word in obj.name.lower() for word in ("stake", "support", "pole", "木桩"))]
            for obj in imported_meshes:
                obj.hide_render = old_flags[obj.name]
    final_hash = sha256(source)
    report["source_sha256_after_review"] = final_hash
    report["source_unchanged"] = final_hash == digest
    if final_hash != digest:
        raise ValueError("Source GLB changed while review ran; discard this review")
    report_path = output / "roundtrip_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("ROUNDTRIP_REPORT", report_path)
    print("ROUNDTRIP_SOURCE_SHA256", digest)
    print("ROUNDTRIP_IMPORTED", len(imported_meshes), "mesh nodes,", len(imported_materials), "materials,", len(targets), "target meshes")
    print("ROUNDTRIP_IMAGES", len(report["imported_images"]))
    if "single_target_hide" in report:
        print("ROUNDTRIP_SINGLE_TARGET_HIDE", report["single_target_hide"]["only_selected_target_changed"])


if __name__ == "__main__":
    main()
