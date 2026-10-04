"""Blender 内执行的挂点校验反例：不打开 Godot、不修改模型或存档。"""
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import unittest

from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('roundtrip_review',ROOT/'review_glb_roundtrip.py')
review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(review)
CONTRACT = ROOT.parent/'whole_plant/rendered/manifest.json'
DATA = json.loads(CONTRACT.read_text())
DIGEST = DATA['files']['whole_plant_scene.glb']['sha256']

def targets():
    result = []
    for plant in range(1,4):
        for item in DATA['png_contract']['projected_fruit_anchors']:
            name = item['name'].replace('P01',f'P{plant:02d}')
            result.append(SimpleNamespace(name=name,parent=SimpleNamespace(name=f'Plant{plant:02d}'),
                location=Vector(item['plant_local_center_m']),
                matrix_world=Matrix.Diagonal(Vector((*item['scale'],1)))))
    return result

class PoseContractFixtures(unittest.TestCase):
    def test_exact_slots(self):
        result = review.pose_review(targets(),CONTRACT,DIGEST)
        self.assertTrue(result['passed'])
        self.assertEqual(result['checked_targets'],12)

    def test_reparent_export_drift_is_rejected(self):
        actual = targets()
        actual[0].location.x += 1.28
        with self.assertRaises(ValueError):
            review.pose_review(actual,CONTRACT,DIGEST)

    def test_wrong_scale_is_rejected(self):
        actual = targets()
        actual[0].matrix_world = Matrix.Identity(4)
        with self.assertRaises(ValueError):
            review.pose_review(actual,CONTRACT,DIGEST)

    def test_basket_cannot_own_fruit(self):
        actual = targets()
        actual[0].parent.name = 'Basket'
        with self.assertRaises(ValueError):
            review.pose_review(actual,CONTRACT,DIGEST)

    def test_contract_hash_must_match(self):
        with self.assertRaises(ValueError):
            review.pose_review(targets(),CONTRACT,'0'*64)

result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(PoseContractFixtures))
if not result.wasSuccessful():
    raise RuntimeError('挂点 fixture 未全部通过')
print('ROUNDTRIP POSE FIXTURES PASSED')
