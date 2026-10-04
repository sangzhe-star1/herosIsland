#!/usr/bin/env python3
"""The pipeline's own checks, runnable without Blender.

    python3 test_pipeline.py

  1. every recipe names a model that exists and a kind the game knows
  2. every crop in data/harvest_crops.json has a recipe, and vice versa; the
     runtime's CROP_IDS / PROP_IDS in harvest_visual_art.gd agree
  3. palette keys the models ask for exist
  4. the contract's pivot is the pivot the game anchors by
  5. the audit passes on the PNGs the game ships
  6. and it fails when a sprite is wrong (break it once): a render shifted
     off the ground line, and one with a black fringe, must both be refused
"""
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
GAME = HERE.parents[3]          # assets/harvest_3d/source/pipeline -> repo root
sys.path.insert(0, str(HERE))
import audit  # noqa: E402

failures = []


def ok(cond, what):
    if not cond:
        failures.append(what)
        print('FAIL', what)


recipes = {p.stem: json.loads(p.read_text()) for p in (HERE / 'recipes').glob('*.json')}
models = {p.stem for p in (HERE / 'models').glob('*.py')}
palette = json.loads((HERE / 'palette.json').read_text())['materials']
contract = json.loads((HERE / 'contract.json').read_text())

# 1. recipes are whole
for rid, r in recipes.items():
    ok(r.get('id') == rid, '%s.json: id %r is not the file name' % (rid, r.get('id')))
    ok(r.get('model') in models, '%s.json: model %r has no models/%s.py' % (rid, r.get('model'), r.get('model')))
    ok(r.get('kind') in ('crop', 'prop'), '%s.json: kind %r is not crop or prop' % (rid, r.get('kind')))
    ok(str(r.get('install', '')).startswith(('crops/', 'props/')),
       '%s.json: install %r must land in crops/ or props/' % (rid, r.get('install')))
    sh = r.get('shadow', {})
    ok(isinstance(sh.get('baked'), bool) and len(sh.get('size', [])) == 2,
       '%s.json: shadow needs {"baked": bool, "size": [sx, sy]}' % rid)

# 2. the data and the runtime agree with the recipes
crop_ids = [c['id'] for c in json.load(open(GAME / 'data/harvest_crops.json'))]
recipe_crops = sorted(k for k, r in recipes.items() if r['kind'] == 'crop')
ok(sorted(crop_ids) == recipe_crops,
   'harvest_crops.json has %s, recipes have %s' % (sorted(set(crop_ids) - set(recipe_crops)),
                                                  sorted(set(recipe_crops) - set(crop_ids))))
art = (GAME / 'scripts/harvest/harvest_visual_art.gd').read_text()
runtime_crops = re.findall(r'"(\w+)"', re.search(r'const CROP_IDS := \[(.*?)\]', art, re.S).group(1))
runtime_props = re.findall(r'"(\w+)"', re.search(r'const PROP_IDS := \[(.*?)\]', art, re.S).group(1))
ok(sorted(runtime_crops) == recipe_crops, 'harvest_visual_art.gd CROP_IDS differ from the crop recipes')
recipe_props = {k for k, r in recipes.items() if r['kind'] == 'prop'}
# soil_cover is a frozen-profile GLB render (soil_cover_candidate), not a recipe yet.
ok(recipe_props <= set(runtime_props),
   'props with a recipe but unknown to the runtime: %s' % sorted(recipe_props - set(runtime_props)))
for rid, r in recipes.items():
    ok((GAME / 'assets/harvest_3d' / r['install']).exists(),
       '%s: installed sprite %s is missing from the game' % (rid, r['install']))

# 3. palette keys
for m in models:
    src = (HERE / 'models' / (m + '.py')).read_text()
    for key in set(re.findall(r"M\['(\w+)'\]", src)):
        ok(key in palette, 'models/%s.py asks for M[%r], not in palette.json' % (m, key))

# 4. the pivot the game anchors by
gd_y = float(re.search(r'GROUND_ORIGIN_PIXEL_Y := ([\d.]+)', art).group(1))
gd_size = float(re.search(r'SOURCE_CANVAS_SIZE := ([\d.]+)', art).group(1))
ok(contract['ground_pivot_pixel'][1] == gd_y and contract['sprite_size'] == gd_size,
   'contract pivot/size %s/%s, harvest_visual_art.gd says %s/%s'
   % (contract['ground_pivot_pixel'], contract['sprite_size'], gd_y, gd_size))

# 5. the shipped sprites pass the audit
with tempfile.TemporaryDirectory() as tmp:
    for folder in ('crops', 'props'):
        code = subprocess.call([sys.executable, str(HERE / 'audit.py'),
                                str(GAME / 'assets/harvest_3d' / folder), '--quiet',
                                '--sheet', str(Path(tmp) / (folder + '.png'))])
        ok(code == 0, 'audit fails on the shipped %s/' % folder)

    # 6. break it once: the audit must refuse a wrong sprite
    from PIL import Image
    good = Image.open(GAME / 'assets/harvest_3d/crops/carrot.png').convert('RGBA')
    sunk = Image.new('RGBA', good.size)
    sunk.paste(good.crop((0, 0, 512, 452)), (0, 60))
    sunk_path = Path(tmp) / 'sunk.png'
    sunk.save(sunk_path)
    m = audit.measure(sunk_path)
    errs = audit.check(sunk_path, m)
    ok(any('ground line' in e for e in errs), 'a carrot 60 px below the ground line was accepted')

    fringe = good.copy()
    px = fringe.load()
    for y in range(512):
        for x in range(512):
            r, g, b, a = px[x, y]
            if 12 < a < 160:
                px[x, y] = (0, 0, 0, a)
    fringe_path = Path(tmp) / 'fringe.png'
    fringe.save(fringe_path)
    errs = audit.check(fringe_path, audit.measure(fringe_path))
    ok(any('fringe' in e for e in errs), 'a black-fringed carrot was accepted')

    blank = Image.new('RGBA', (512, 512))
    blank_path = Path(tmp) / 'blank.png'
    blank.save(blank_path)
    errs = audit.check(blank_path, audit.measure(blank_path))
    ok(any('empty' in e for e in errs), 'an empty sprite was accepted')

if failures:
    print('%d failure(s)' % len(failures))
    sys.exit(1)
print('pipeline: %d recipes, %d models, %d palette entries, audit and break-it-once all good'
      % (len(recipes), len(models), len(palette)))
