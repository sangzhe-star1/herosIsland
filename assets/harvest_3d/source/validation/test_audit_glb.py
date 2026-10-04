"""Memory-only GLB fixtures for the existing harvest GLB auditor."""
import copy
import contextlib
import io
import json
from pathlib import Path
import struct
import unittest
from unittest import mock

import audit_glb


def glb_bytes(document, binary=b""):
    encoded = json.dumps(document, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    chunks = struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
    if binary:
        padded = binary + b"\0" * (-len(binary) % 4)
        chunks += struct.pack("<II", len(padded), 0x004E4942) + padded
    return struct.pack("<III", 0x46546C67, 2, 12 + len(chunks)) + chunks


def primitive(position=0, material=0):
    return {"attributes": {"POSITION": position}, "material": material}


def basic_document():
    return {"asset": {"version": "2.0"}, "scene": 0,
            "scenes": [{"nodes": [0]}],
            "nodes": [{"name": "Root", "children": [1, 2]},
                      {"name": "piece", "mesh": 0},
                      {"name": "HarvestTarget Tomato P01 F01", "mesh": 0}],
            "meshes": [{"name": "shared", "primitives": [primitive()]}],
            "accessors": [{"componentType": 5126, "count": 6, "type": "VEC3"}],
            "materials": [{"name": "Loam", "pbrMetallicRoughness": {"baseColorFactor": [.2, .3, .4, 1]}}]}


def whole_plant_document():
    document = basic_document()
    document["accessors"].append({"componentType": 5126, "count": 3, "type": "VEC3"})
    document["meshes"].append({"name": "shared fruit", "primitives": [primitive(1)]})
    document["nodes"] = [{"name": "Root", "children": [1, 2, 3, 4, 5]},
                         {"name": "GardenBed", "mesh": 0}, {"name": "Basket", "mesh": 0}]
    for plant in range(1, 4):
        children = list(range(6 + (plant - 1) * 4, 10 + (plant - 1) * 4))
        document["nodes"].append({"name": f"Plant{plant:02d}", "mesh": 0, "children": children})
    for plant in range(1, 4):
        for fruit in range(1, 5):
            document["nodes"].append({"name": f"HarvestTarget Tomato P{plant:02d} F{fruit:02d}", "mesh": 1})
    return document


def result_of(document, binary=b""):
    return audit_glb.audit_bytes(glb_bytes(document, binary))


class AuditTests(unittest.TestCase):
    def test_shared_mesh_counts_unique_storage_once_and_scene_twice(self):
        result = result_of(basic_document())
        summary = result["summary"]
        self.assertEqual(summary["unique_mesh_triangles"], 2)
        self.assertEqual(summary["instanced_scene_triangles"], 4)
        self.assertEqual(summary["static_scene_triangles"], 2)
        self.assertEqual(summary["target_scene_triangles"], 2)
        self.assertEqual(summary["static_scene_primitives"], 1)
        self.assertEqual([item["mesh"] for item in result["instances"]], [0, 0])

    def test_default_scene_controls_instance_counts(self):
        document = basic_document()
        document["scenes"].append({"nodes": [1]})
        document["nodes"][0]["children"].remove(1)
        document["scene"] = 1
        result = result_of(document)
        self.assertEqual(result["summary"]["unique_mesh_triangles"], 2)
        self.assertEqual(result["summary"]["instanced_scene_triangles"], 2)
        self.assertEqual(result["summary"]["targets"], 0)
        self.assertEqual(result["scene_roots"], ["piece"])
        self.assertEqual(result["unreachable_node_ids"], [0, 2])

    def test_duplicate_node_and_target_names_are_reported(self):
        document = basic_document()
        document["nodes"][1]["name"] = document["nodes"][2]["name"]
        result = result_of(document)
        self.assertEqual(result["summary"]["targets"], 2)
        self.assertEqual(result["summary"]["unique_target_names"], 1)
        self.assertEqual(result["duplicate_node_names"], ["HarvestTarget Tomato P01 F01"])
        self.assertEqual(result["duplicate_target_names"], result["duplicate_node_names"])

    def test_material_texture_color_and_extension_statistics(self):
        document = basic_document()
        document["accessors"][0]["count"] = 3
        document["accessors"].append({"componentType": 5121, "count": 3, "type": "VEC4", "normalized": True, "bufferView": 0})
        document["meshes"][0]["primitives"][0]["attributes"]["COLOR_0"] = 1
        document["buffers"] = [{"byteLength": 12}]
        document["bufferViews"] = [{"buffer": 0, "byteLength": 12}]
        document["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"] = {"index": 0}
        document["textures"] = [{"source": 0}]
        document["images"] = [{"uri": "fixture.png"}]
        document["cameras"] = [{"type": "perspective", "perspective": {"yfov": 1, "znear": .1}}]
        document["extensions"] = {"KHR_lights_punctual": {"lights": [{"type": "point"}]}}
        document["extensionsUsed"] = ["KHR_lights_punctual"]
        colors = bytes([255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255])
        result = result_of(document, colors)
        summary = result["summary"]
        self.assertEqual([summary[key] for key in ("materials", "textures", "images", "cameras", "lights")], [1, 1, 1, 1, 1])
        self.assertEqual(summary["unique_color_0_primitives"], 1)
        self.assertEqual(summary["instanced_color_0_primitives"], 2)
        self.assertEqual(summary["extensions_present"], ["KHR_lights_punctual"])
        color = result["meshes"][0]["primitives"][0]["color_0"]
        self.assertEqual(color["min"], [0, 0, 0, 1])
        self.assertEqual(color["max"], [1, 1, 1, 1])
        self.assertEqual(color["mean"], [.333333, .333333, .333333, 1])
        self.assertEqual(result["materials"][0]["baseColorFactor"], [.2, .3, .4, 1])
        self.assertTrue(result["materials"][0]["baseColorFactor_explicit"])

    def test_float_colors_are_not_normalized_or_gamma_changed(self):
        document = basic_document()
        document["accessors"][0]["count"] = 3
        document["accessors"].append({"componentType": 5126, "count": 3, "type": "VEC3", "bufferView": 0})
        document["meshes"][0]["primitives"][0]["attributes"]["COLOR_0"] = 1
        document["bufferViews"] = [{"buffer": 0, "byteLength": 36}]
        result = result_of(document, struct.pack("<9f", *([.2, .1, .05] * 3)))
        self.assertEqual(result["meshes"][0]["primitives"][0]["color_0"]["mean"], [.2, .1, .05])

    def test_triangle_strip_and_fan_counts(self):
        for mode in (5, 6):
            with self.subTest(mode=mode):
                document = basic_document()
                document["meshes"][0]["primitives"][0]["mode"] = mode
                self.assertEqual(result_of(document)["summary"]["unique_mesh_triangles"], 4)

    def test_complete_kit_passes_and_keeps_target_parent_paths(self):
        result = result_of(whole_plant_document())
        self.assertEqual(audit_glb.check_whole_plant(result), [])
        self.assertEqual(result["summary"]["unique_mesh_triangles"], 3)
        self.assertEqual(result["summary"]["instanced_scene_triangles"], 22)
        self.assertEqual(result["summary"]["static_scene_primitives"], 5)
        self.assertEqual(result["targets"][0]["path"], "Root/Plant01/HarvestTarget Tomato P01 F01")
        self.assertEqual(result["targets"][-1]["parent"], "Plant03")

    def test_kit_rejects_duplicate_targets_and_invalid_name(self):
        for name in ("HarvestTarget Tomato P01 F01", "HarvestTarget missing identifiers"):
            with self.subTest(name=name):
                document = whole_plant_document()
                document["nodes"][7]["name"] = name
                self.assertTrue(audit_glb.check_whole_plant(result_of(document)))

    def test_kit_rejects_target_in_wrong_plant(self):
        document = whole_plant_document()
        document["nodes"][3]["children"].remove(6)
        document["nodes"][4]["children"].append(6)
        errors = audit_glb.check_whole_plant(result_of(document))
        self.assertTrue(any("direct child of Plant01" in error for error in errors))

    def test_kit_rejects_bad_required_hierarchy(self):
        for mutation in ("rename_root", "nested_basket", "extra_plant", "target_without_mesh"):
            with self.subTest(mutation=mutation):
                document = whole_plant_document()
                if mutation == "rename_root":
                    document["nodes"][0]["name"] = "Other"
                elif mutation == "nested_basket":
                    document["nodes"][0]["children"].remove(2)
                    document["nodes"][1]["children"] = [2]
                elif mutation == "extra_plant":
                    document["nodes"].append({"name": "Plant04"})
                    document["nodes"][0]["children"].append(18)
                else:
                    del document["nodes"][6]["mesh"]
                self.assertTrue(audit_glb.check_whole_plant(result_of(document)))

    def test_kit_triangle_limit_uses_instances_not_unique_meshes(self):
        document = whole_plant_document()
        document["accessors"][1]["count"] = 15000
        result = result_of(document)
        self.assertLess(result["summary"]["unique_mesh_triangles"], 60000)
        self.assertGreater(result["summary"]["instanced_scene_triangles"], 60000)
        self.assertTrue(any("instanced_scene_triangles" in error for error in audit_glb.check_whole_plant(result)))

    def test_scene_triangle_limit_inclusive_sixty_thousand(self):
        document = whole_plant_document()
        document["accessors"][0]["count"] = 36
        document["accessors"][1]["count"] = 14985
        result = result_of(document)
        self.assertEqual(result["summary"]["instanced_scene_triangles"], 60000)
        self.assertEqual(audit_glb.check_whole_plant(result), [])
        document["accessors"][1]["count"] += 3
        errors = audit_glb.check_whole_plant(result_of(document))
        self.assertTrue(any("instanced_scene_triangles 60012 exceeds 60000" in error for error in errors))

    def test_kit_material_limit_includes_declared_materials(self):
        for count, passed in ((12, True), (13, False)):
            with self.subTest(count=count):
                document = whole_plant_document()
                document["materials"] *= count
                self.assertEqual(not audit_glb.check_whole_plant(result_of(document)), passed)

    def test_static_primitive_limit_inclusive_twelve(self):
        for expected, passed in ((12, True), (13, False)):
            with self.subTest(expected=expected):
                document = whole_plant_document()
                document["meshes"].append({"name": "bed detail", "primitives": [primitive()] * (expected - 4)})
                document["nodes"][1]["mesh"] = 2
                result = result_of(document)
                self.assertEqual(result["summary"]["static_scene_primitives"], expected)
                self.assertEqual(not audit_glb.check_whole_plant(result), passed)

    def test_kit_rejects_images_textures_cameras_lights(self):
        extras = {"images": [{"uri": "fixture.png"}], "textures": [{"source": 0}],
                  "cameras": [{"type": "orthographic"}],
                  "extensions": {"KHR_lights_punctual": {"lights": [{"type": "point"}]}}}
        for key, value in extras.items():
            with self.subTest(key=key):
                document = whole_plant_document()
                document[key] = value
                errors = audit_glb.check_whole_plant(result_of(document))
                self.assertTrue(any("must be 0" in error for error in errors))

    def test_invalid_scene_child_cycle_and_shared_node_are_errors(self):
        for mutation in ("scene", "negative_child", "cycle", "shared_node", "duplicate_root"):
            with self.subTest(mutation=mutation):
                document = basic_document()
                if mutation == "scene":
                    document["scene"] = 5
                elif mutation == "negative_child":
                    document["nodes"][0]["children"].append(-1)
                elif mutation == "cycle":
                    document["nodes"][1]["children"] = [0]
                elif mutation == "shared_node":
                    document["nodes"][1]["children"] = [2]
                else:
                    document["scenes"][0]["nodes"].append(0)
                with self.assertRaises(ValueError):
                    result_of(document)

    def test_truncated_glb_and_missing_json_are_errors(self):
        for raw in (b"", glb_bytes(basic_document())[:-1], struct.pack("<III", 0x46546C67, 2, 12)):
            with self.subTest(length=len(raw)), self.assertRaises(ValueError):
                audit_glb.audit_bytes(raw)

    def test_cli_gate_is_optional_and_returns_nonzero_when_selected(self):
        standalone = result_of(basic_document())
        good = result_of(whole_plant_document())
        for result, selected, expected in ((standalone, False, 0), (standalone, True, 1), (good, True, 0)):
            with self.subTest(selected=selected, expected=expected):
                argv = [str(Path(audit_glb.__file__)), "candidate.glb", "--json"]
                if selected:
                    argv.append("--check-whole-plant")
                stdout = io.StringIO()
                with mock.patch.object(audit_glb, "audit", return_value=copy.deepcopy(result)), mock.patch("sys.argv", argv), contextlib.redirect_stdout(stdout):
                    self.assertEqual(audit_glb.main(), expected)
                payload = json.loads(stdout.getvalue())[0]
                self.assertEqual("whole_plant_check" in payload, selected)

    def test_cli_bad_input_returns_error_status(self):
        with mock.patch.object(audit_glb, "audit", side_effect=ValueError("bad scene")), mock.patch("sys.argv", ["audit_glb.py", "bad.glb"]), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(audit_glb.main(), 2)


if __name__ == "__main__":
    unittest.main()
