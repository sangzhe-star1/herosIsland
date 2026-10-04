#!/usr/bin/env python3
"""Read-only GLB structure/geometry audit; stdlib only, no engine invocation."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import struct
import sys


def read_glb_bytes(raw):
    """Parse a byte buffer, also usable by tests without filesystem fixtures."""
    if len(raw) < 12:
        raise ValueError("Truncated GLB header")
    magic, version, declared_size = struct.unpack_from("<III", raw)
    if magic != 0x46546C67 or version != 2 or declared_size != len(raw):
        raise ValueError("Not a complete glTF 2 GLB")
    document, binary, offset = None, b"", 12
    while offset < len(raw):
        if offset + 8 > len(raw):
            raise ValueError("Truncated GLB chunk header")
        size, kind = struct.unpack_from("<II", raw, offset)
        chunk = raw[offset + 8:offset + 8 + size]
        if len(chunk) != size:
            raise ValueError("Truncated GLB chunk")
        if kind == 0x4E4F534A:
            document = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        offset += size + 8
    if document is None:
        raise ValueError("Missing JSON chunk")
    if not isinstance(document, dict):
        raise ValueError("GLB JSON must be an object")
    return raw, document, binary


def read_glb(path):
    return read_glb_bytes(Path(path).read_bytes())


def index_in(items, index, kind):
    if isinstance(index, bool) or not isinstance(index, int) or not 0 <= index < len(items):
        raise ValueError(f"Invalid {kind} index: {index!r}")
    return items[index]


def color_summary(document, binary, accessor_id):
    accessor = index_in(document["accessors"], accessor_id, "COLOR_0 accessor")
    summary = {key: accessor.get(key) for key in ("type", "componentType", "count", "normalized")}
    if "sparse" in accessor or "bufferView" not in accessor:
        summary["note"] = "Sparse/unbacked color accessor; values not decoded"
        return summary
    view = index_in(document["bufferViews"], accessor["bufferView"], "color bufferView")
    if view.get("buffer", 0) != 0:
        summary["note"] = "External color buffer; values not decoded"
        return summary
    fmt, size, divisor = {5121: ("B", 1, 255), 5123: ("H", 2, 65535), 5126: ("f", 4, 1)}[accessor["componentType"]]
    channels = {"VEC3": 3, "VEC4": 4}[accessor["type"]]
    stride = view.get("byteStride", channels * size)
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    if accessor["count"] <= 0:
        raise ValueError("COLOR_0 accessor must not be empty")
    if stride < channels * size or offset < 0:
        raise ValueError("Invalid COLOR_0 byte offset or stride")
    if offset + (accessor["count"] - 1) * stride + channels * size > len(binary):
        raise ValueError("COLOR_0 accessor exceeds embedded binary buffer")
    rows = [struct.unpack_from("<" + fmt * channels, binary, offset + i * stride) for i in range(accessor["count"])]
    denominator = divisor if accessor.get("normalized", False) else 1
    summary["min"] = [round(min(row[c] for row in rows) / denominator, 6) for c in range(channels)]
    summary["max"] = [round(max(row[c] for row in rows) / denominator, 6) for c in range(channels)]
    summary["mean"] = [round(sum(row[c] for row in rows) / len(rows) / denominator, 6) for c in range(channels)]
    return summary


def extensions_in(value):
    found = set()
    if isinstance(value, dict):
        found.update(value.get("extensions", {}))
        for child in value.values():
            found.update(extensions_in(child))
    elif isinstance(value, list):
        for child in value:
            found.update(extensions_in(child))
    return found


def audit(path):
    return audit_bytes(Path(path).read_bytes(), str(Path(path).resolve()))


def audit_bytes(raw, label="<memory>"):
    raw, document, binary = read_glb_bytes(raw)
    nodes = document.get("nodes", [])
    accessors = document.get("accessors", [])
    materials = document.get("materials", [])
    meshes = []
    for mesh_id, mesh in enumerate(document.get("meshes", [])):
        primitives = []
        for primitive_id, primitive in enumerate(mesh.get("primitives", [])):
            attributes = primitive.get("attributes", {})
            vertices = index_in(accessors, attributes["POSITION"], "POSITION accessor")["count"] if "POSITION" in attributes else 0
            elements = index_in(accessors, primitive["indices"], "index accessor")["count"] if "indices" in primitive else vertices
            mode = primitive.get("mode", 4)
            if mode not in range(7):
                raise ValueError(f"Mesh {mesh_id} primitive {primitive_id}: invalid primitive mode {mode}")
            if mode == 4 and elements % 3:
                raise ValueError(f"Mesh {mesh_id} primitive {primitive_id}: triangle index count not divisible by 3")
            triangles = elements // 3 if mode == 4 else max(0, elements - 2) if mode in (5, 6) else 0
            material_id = primitive.get("material")
            item = {"id": primitive_id, "mode": mode, "vertices": vertices, "triangles": triangles,
                    "material": material_id, "material_name": index_in(materials, material_id, "material").get("name", "") if material_id is not None else None,
                    "attributes": sorted(attributes)}
            if "COLOR_0" in attributes:
                item["color_0"] = color_summary(document, binary, attributes["COLOR_0"])
            primitives.append(item)
        meshes.append({"id": mesh_id, "name": mesh.get("name", ""), "triangles": sum(p["triangles"] for p in primitives),
                       "vertices": sum(p["vertices"] for p in primitives), "primitive_count": len(primitives),
                       "color_0_primitive_count": sum("color_0" in p for p in primitives), "primitives": primitives})

    scene_id = document.get("scene", 0)
    scenes = document.get("scenes", [])
    parents = {}
    for node_id, node in enumerate(nodes):
        for child in node.get("children", []):
            index_in(nodes, child, "child node")
            if child in parents:
                raise ValueError(f"Node {child} referenced by multiple parent/child entries")
            parents[child] = node_id
    # Validate even disconnected nodes, so a hidden cycle cannot evade the audit.
    checked, visiting = set(), set()

    def validate_branch(node_id):
        if node_id in visiting:
            raise ValueError("Node hierarchy has a cycle")
        if node_id in checked:
            return
        visiting.add(node_id)
        for child in nodes[node_id].get("children", []):
            validate_branch(child)
        visiting.remove(node_id)
        checked.add(node_id)

    for node_id in range(len(nodes)):
        validate_branch(node_id)
    roots = index_in(scenes, scene_id, "scene").get("nodes", []) if scenes else [i for i in range(len(nodes)) if i not in parents]
    if len(set(roots)) != len(roots):
        raise ValueError("Default scene has duplicate root node entries")
    for root in roots:
        index_in(nodes, root, "scene root node")
        if root in parents:
            raise ValueError(f"Scene root node {root} is also a child")
    instances, all_paths = [], []

    def walk(node_id, ancestors=(), target_ancestor=False):
        if node_id in ancestors:
            raise ValueError("Node hierarchy has a cycle")
        node = index_in(nodes, node_id, "node")
        path_ids = ancestors + (node_id,)
        path_names = [nodes[i].get("name", f"node_{i}") for i in path_ids]
        is_target = "HarvestTarget" in node.get("name", "")
        all_paths.append({"id": node_id, "name": node.get("name", ""), "path": "/".join(path_names),
                          "parent": nodes[ancestors[-1]].get("name", "") if ancestors else None,
                          "parent_id": ancestors[-1] if ancestors else None, "depth": len(ancestors), "mesh": node.get("mesh")})
        if "mesh" in node:
            mesh = index_in(meshes, node["mesh"], "mesh")
            gpu = node.get("extensions", {}).get("EXT_mesh_gpu_instancing", {}).get("attributes", {})
            multiplier = index_in(accessors, next(iter(gpu.values())), "GPU instance accessor")["count"] if gpu else 1
            instances.append({"node": node_id, "name": node.get("name", ""), "path": "/".join(path_names),
                              "mesh": node["mesh"], "multiplicity": multiplier, "target": is_target or target_ancestor,
                              "triangles": mesh["triangles"] * multiplier, "vertices": mesh["vertices"] * multiplier,
                              "primitive_count": mesh["primitive_count"] * multiplier,
                              "color_0_primitive_count": mesh["color_0_primitive_count"] * multiplier})
        for child in node.get("children", []):
            walk(child, path_ids, target_ancestor or is_target)

    for root in roots:
        walk(root)
    targets = [item for item in all_paths if "HarvestTarget" in item["name"]]
    materials_out = []
    for material_id, material in enumerate(materials):
        pbr = material.get("pbrMetallicRoughness", {})
        materials_out.append({"id": material_id, "name": material.get("name", ""),
                              "baseColorFactor": pbr.get("baseColorFactor", [1, 1, 1, 1]),
                              "baseColorFactor_explicit": "baseColorFactor" in pbr,
                              "baseColorTexture": pbr.get("baseColorTexture"),
                              "roughness": pbr.get("roughnessFactor", 1), "metallic": pbr.get("metallicFactor", 1),
                              "alphaMode": material.get("alphaMode", "OPAQUE"),
                              "extensions": sorted(material.get("extensions", {}))})
    top_lights = document.get("extensions", {}).get("KHR_lights_punctual", {}).get("lights", [])
    count = collections.Counter(item["name"] for item in targets)
    name_count = collections.Counter(node.get("name", "") for node in nodes if node.get("name"))
    return {"path": label, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
            "summary": {"nodes": len(nodes), "meshes": len(meshes), "materials": len(materials),
                        "unique_mesh_triangles": sum(mesh["triangles"] for mesh in meshes),
                        "unique_mesh_vertices": sum(mesh["vertices"] for mesh in meshes),
                        "unique_mesh_primitives": sum(mesh["primitive_count"] for mesh in meshes),
                        "unique_color_0_primitives": sum(mesh["color_0_primitive_count"] for mesh in meshes),
                        "instanced_scene_triangles": sum(item["triangles"] for item in instances),
                        "instanced_scene_vertices": sum(item["vertices"] for item in instances),
                        "instanced_scene_primitives": sum(item["primitive_count"] for item in instances),
                        "instanced_color_0_primitives": sum(item["color_0_primitive_count"] for item in instances),
                        "static_scene_triangles": sum(item["triangles"] for item in instances if not item["target"]),
                        "static_scene_primitives": sum(item["primitive_count"] for item in instances if not item["target"]),
                        "target_scene_triangles": sum(item["triangles"] for item in instances if item["target"]),
                        "targets": len(targets), "unique_target_names": len(count),
                        "textures": len(document.get("textures", [])), "images": len(document.get("images", [])),
                        "cameras": len(document.get("cameras", [])), "lights": len(top_lights),
                        "extensions_used": document.get("extensionsUsed", []),
                        "extensions_required": document.get("extensionsRequired", []), "extensions_present": sorted(extensions_in(document))},
            "hierarchy": all_paths, "targets": targets, "duplicate_target_names": [name for name, amount in count.items() if amount > 1],
            "duplicate_node_names": [name for name, amount in name_count.items() if amount > 1],
            "default_scene": scene_id if scenes else None,
            "scene_roots": [nodes[root].get("name", "") for root in roots],
            "unreachable_node_ids": sorted(set(range(len(nodes))) - {item["id"] for item in all_paths}),
            "materials": materials_out, "meshes": meshes, "instances": instances,
            "images": document.get("images", []), "cameras": document.get("cameras", []), "lights": top_lights,
            "notes": ["Unique mesh counts sum stored glTF mesh definitions once; identical definitions are not deduplicated.",
                      "Scene counts traverse the default scene and multiply node mesh instances; static excludes HarvestTarget nodes and their descendants.",
                      "Primitive counts are potential material surfaces, not measured runtime draw calls.",
                      "Godot vertex color rendering must be checked on imported active materials; GLB presence of COLOR_0 alone is insufficient."]}


def check_whole_plant(result):
    """Optional complete three-plant kit contract; do not apply to modular parts."""
    errors, summary = [], result["summary"]
    if result["default_scene"] is None:
        errors.append("Whole-plant kit requires an explicit glTF scene")
    if result["scene_roots"] != ["Root"]:
        errors.append("Default scene must have exactly one root named Root")
    hierarchy = result["hierarchy"]
    roots = [item for item in hierarchy if item["name"] == "Root" and item["depth"] == 0]
    root_id = roots[0]["id"] if len(roots) == 1 else None
    required = {"GardenBed", "Basket", "Plant01", "Plant02", "Plant03"}
    children = [item for item in hierarchy if item["parent_id"] == root_id and root_id is not None]
    for name in sorted(required):
        if sum(item["name"] == name for item in children) != 1:
            errors.append(f"Root must directly own exactly one {name}")
    plants = [item for item in hierarchy if re.fullmatch(r"Plant\d+", item["name"])]
    if len(plants) != 3 or {item["name"] for item in plants} != {"Plant01", "Plant02", "Plant03"}:
        errors.append("Kit must contain exactly Plant01, Plant02, Plant03")
    if summary["targets"] != 12 or summary["unique_target_names"] != 12:
        errors.append("Kit must contain 12 distinct HarvestTarget nodes")
    combinations = set()
    for target in result["targets"]:
        match = re.fullmatch(r"HarvestTarget .+ P(0[123]) F(0[1234])", target["name"])
        if not match:
            errors.append(f"Invalid target name: {target['name']}")
        else:
            plant_id, fruit_id = match.groups()
            combinations.add((plant_id, fruit_id))
            if target["parent"] != f"Plant{plant_id}":
                errors.append(f"Target {target['name']} must be a direct child of Plant{plant_id}")
        if target["mesh"] is None:
            errors.append(f"Target {target['name']} must own an independent mesh node")
    if combinations != {(f"0{plant}", f"0{fruit}") for plant in range(1, 4) for fruit in range(1, 5)}:
        errors.append("Expected four independently named targets F01–F04 under each plant P01–P03")
    for key, cap in (("instanced_scene_triangles", 60000), ("materials", 12), ("static_scene_primitives", 12)):
        if summary[key] > cap:
            errors.append(f"{key} {summary[key]} exceeds {cap}")
    for key in ("images", "textures", "cameras", "lights"):
        if summary[key] != 0:
            errors.append(f"{key} must be 0; got {summary[key]}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+")
    parser.add_argument("--json", action="store_true", help="Include every mesh primitive and color range")
    parser.add_argument("--check-whole-plant", action="store_true", help="Enforce the full three-plant/12-target kit contract; not for standalone parts")
    args = parser.parse_args()
    try:
        results = [audit(path) for path in args.paths]
    except (OSError, ValueError, KeyError, IndexError, struct.error) as error:
        print(f"GLB audit error: {error}", file=sys.stderr)
        return 2
    for result in results:
        if args.check_whole_plant:
            errors = check_whole_plant(result)
            result["whole_plant_check"] = {"passed": not errors, "errors": errors}
    failed = any(not result["whole_plant_check"]["passed"] for result in results) if args.check_whole_plant else False
    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return 1 if failed else 0
    for result in results:
        print(result["path"])
        print("SHA256", result["sha256"], "bytes", result["bytes"])
        print(json.dumps(result["summary"], ensure_ascii=False, indent=2))
        print("Hierarchy:")
        for item in result["hierarchy"]:
            print(" ", item["path"], "mesh=", item["mesh"])
        print("Mesh instances:")
        for item in result["instances"]:
            print(" ", item["name"], f"{item['triangles']} tris / {item['primitive_count']} primitives", "target" if item["target"] else "static")
        print("Materials:")
        for item in result["materials"]:
            print(" ", json.dumps(item, ensure_ascii=False))
        print("COLOR_0:")
        for mesh in result["meshes"]:
            for primitive in mesh["primitives"]:
                if "color_0" in primitive:
                    print(" ", mesh["name"], primitive["material_name"], json.dumps(primitive["color_0"]))
        if args.check_whole_plant:
            print("Whole-plant check:", "PASS" if result["whole_plant_check"]["passed"] else "FAIL")
            for error in result["whole_plant_check"]["errors"]:
                print(" ", error)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
