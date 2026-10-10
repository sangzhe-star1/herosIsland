#!/usr/bin/env python3
"""Focused build/texture contract fault injection; Pillow, no Blender needed."""
import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from PIL import Image

import audit
import build

HERE = Path(__file__).resolve().parent
GAME = HERE.parents[3]


class BuildContractTests(unittest.TestCase):
    def test_audit_python_default_and_explicit(self):
        self.assertIsNone(build.parse_args([])['audit_python'])
        executable = '/tmp/Python with spaces/bin/python3'
        self.assertEqual(build.parse_args(['--audit-python', executable])['audit_python'], executable)
        with patch.object(build.subprocess, 'call', return_value=7) as call:
            self.assertEqual(build.run_audit(Path('/tmp/render output'), executable), 7)
        call.assert_called_once_with([executable, str(HERE / 'audit.py'), '/tmp/render output'])

    def test_audit_python_keeps_path_default(self):
        with patch.object(build.shutil, 'which', return_value='/usr/bin/python3'), \
                patch.object(build.subprocess, 'call', return_value=0) as call:
            self.assertEqual(build.run_audit(Path('/tmp/rendered')), 0)
        self.assertEqual(call.call_args.args[0][0], '/usr/bin/python3')

    def test_audit_python_missing_is_actionable(self):
        with patch.object(build.subprocess, 'call', side_effect=FileNotFoundError('missing')):
            with self.assertRaisesRegex(SystemExit, '--audit-python'):
                build.run_audit(Path('/tmp/rendered'), '/missing/python')

    def test_rejects_bad_model_anchors(self):
        for anchors in ([], {'surface': [0, 1]}, {'surface': [0, 1, float('nan')]},
                        {'surface': [0, 1, True]}, {'': [0, 0, 0]}):
            with self.subTest(anchors=anchors), self.assertRaises(ValueError):
                build.validate_anchors({'anchors': anchors})
        with self.assertRaises(ValueError):
            build.validate_anchors({'anchors': {'surface': [0, 0, 0]}, 'origin_offset': [0, 0]})

    @staticmethod
    def projection_modules(projector):
        return {'bpy_extras.object_utils': SimpleNamespace(world_to_camera_view=projector),
                'mathutils': SimpleNamespace(Vector=tuple)}

    def test_anchor_projection_uses_local_point_plus_origin_offset(self):
        studio = SimpleNamespace(scene=object(), camera=object(), size=512)
        recipe = {'id': 'bed', 'anchors': {'planting_surface': [0.1, 0.2, 0.16]},
                  'origin_offset': [0.2, -0.3, 0.04]}
        calls = []

        def project(scene, camera, point):
            calls.append((scene, camera, point))
            return SimpleNamespace(x=0.4, y=0.25, z=2)

        with patch.dict('sys.modules', self.projection_modules(project)):
            result = build.project_anchors(studio, recipe)
        self.assertEqual(result, {'planting_surface': [204.8, 384.0]})
        self.assertIs(calls[0][0], studio.scene)
        self.assertIs(calls[0][1], studio.camera)
        for actual, expected in zip(calls[0][2], [0.3, -0.1, 0.2]):
            self.assertAlmostEqual(actual, expected)

    def test_anchor_outside_camera_is_refused(self):
        studio = SimpleNamespace(scene=None, camera=None, size=512)
        recipe = {'id': 'bed', 'anchors': {'planting_surface': [0, 0, 0.16]}}
        for point in ((1.1, 0.5, 2), (0.5, 0.5, -1), (0.5, float('nan'), 2),
                      (0.5, 0.5, float('nan'))):
            projector = lambda *args: SimpleNamespace(x=point[0], y=point[1], z=point[2])
            with self.subTest(point=point), \
                    patch.dict('sys.modules', self.projection_modules(projector)), \
                    self.assertRaisesRegex(ValueError, 'outside the rendered canvas'):
                build.project_anchors(studio, recipe)

    def test_sidecar_preserves_anchors_and_existing_shadow_defaults(self):
        recipe = {'id': 'soil_grass_patch'}
        self.assertIsNone(build.sidecar_metadata(recipe, {'contact_shadow_baked': True}))
        self.assertEqual(build.sidecar_metadata(recipe, {'contact_shadow_baked': False}),
                         {'contact_shadow_baked': False,
                          'source': 'pipeline/recipes/soil_grass_patch.json'})
        for baked in (True, False):
            anchors = {'planting_surface': [256.0, 438.7]}
            metadata = build.sidecar_metadata(recipe, {'contact_shadow_baked': baked,
                                                       'anchors_px': anchors})
            self.assertEqual(metadata['contact_shadow_baked'], baked)
            self.assertEqual(metadata['anchors_px'], anchors)

    def test_sidecar_preserves_explicit_audit_policy(self):
        policy = {'black_outline': True}
        metadata = build.sidecar_metadata(
            {'id': 'basket_empty'},
            {'contact_shadow_baked': True, 'audit': policy})
        self.assertEqual(metadata['audit'], policy)
        self.assertEqual(metadata['source'], 'pipeline/recipes/basket_empty.json')

    def test_manifest_anchor_coordinates_must_be_finite_in_canvas(self):
        self.assertEqual(audit.check_anchors({'surface': [256.0, 438.7]}), [])
        for anchors in ([], {'surface': [512, 200]}, {'surface': [float('inf'), 200]},
                        {'surface': [256, True]}, {'surface': [200, 400, 1]}):
            with self.subTest(anchors=anchors):
                self.assertTrue(audit.check_anchors(anchors))


class GroundTextureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.path = self.root / 'props' / 'grass_tile.png'
        self.path.parent.mkdir()
        with Image.open(GAME / 'assets/harvest_3d/props/grass_tile.png') as source:
            self.good = source.copy()
        self.spec = audit.texture_contract(self.path)

    def errors(self, image):
        image.save(self.path)
        return audit.check_texture(self.path, audit.measure(self.path), self.spec)

    def test_shipped_texture_is_a_valid_overlay(self):
        self.assertEqual(self.spec['usage'], 'tileable_ground_overlay')
        self.assertEqual(self.errors(self.good), [])

    def test_exception_is_an_exact_install_path(self):
        for path in ('crops/grass_tile.png', 'props/carrot.png', 'props/grass_tile_copy.png',
                     'sprites/grass_tile.png'):
            with self.subTest(path=path):
                self.assertIsNone(audit.texture_contract(self.root / path))
        self.good.save(self.path)
        self.assertTrue(audit.check(self.path, audit.measure(self.path)))

    def test_empty_tile_is_refused(self):
        self.assertTrue(any('empty' in e for e in self.errors(Image.new('RGBA', self.good.size))))

    def test_wrong_size_and_mode_are_refused(self):
        self.assertTrue(any('contract says 256x256' in e for e in self.errors(self.good.resize((512, 512)))))
        self.assertTrue(any('not RGBA' in e for e in self.errors(self.good.convert('RGB'))))

    def test_opaque_and_almost_invisible_tiles_are_refused(self):
        opaque = self.good.copy()
        opaque.putalpha(255)
        self.assertTrue(any('too opaque' in e for e in self.errors(opaque)))
        faint = self.good.copy()
        faint.putalpha(1)
        self.assertTrue(any('mean alpha' in e for e in self.errors(faint)))

    def test_incomplete_coverage_is_refused(self):
        incomplete = self.good.copy()
        incomplete.paste((0, 0, 0, 0), (0, 0, 128, 256))
        self.assertTrue(any('coverage' in e for e in self.errors(incomplete)))

    def test_horizontal_rgb_seam_is_refused(self):
        seamed = self.good.copy()
        seamed.paste((255, 255, 255, 80), (0, 0, 1, 256))
        seamed.paste((0, 0, 0, 80), (255, 0, 256, 256))
        self.assertTrue(any('horizontal tile seam' in e for e in self.errors(seamed)))

    def test_vertical_alpha_seam_is_refused(self):
        seamed = self.good.copy()
        seamed.paste((100, 150, 100, 80), (0, 0, 256, 1))
        seamed.paste((100, 150, 100, 1), (0, 255, 256, 256))
        self.assertTrue(any('vertical tile seam' in e for e in self.errors(seamed)))

    def test_render_manifest_cannot_opt_sprite_out_with_texture_filename(self):
        self.good.save(self.path)
        (self.root / 'manifest.json').write_text(json.dumps({'assets': [
            {'id': 'grass_tile', 'file': 'props/grass_tile.png',
             'ground_pivot_pixel': audit.CONTRACT['ground_pivot_pixel']}
        ]}))
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = audit.main([str(self.root), '--quiet'])
        self.assertEqual(code, 1)
        self.assertIn('the contract says 512x512', output.getvalue())


if __name__ == '__main__':
    unittest.main(verbosity=2)
