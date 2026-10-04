"""复用QASession和既有场景，检查草莓候选；只改独立QA副本中的二进制素材。"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

from PIL import Image, ImageStat

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0,str(PROJECT/'tests'))
from qa_run import QASession, find_godot

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--candidate',type=Path)
parser.add_argument('--name',default='strawberry-readable')
parser.add_argument('--touch',action='store_true')
parser.add_argument('--orchard',action='store_true')
parser.add_argument('--completion',action='store_true')
args = parser.parse_args()
runtime_path = 'assets/harvest_3d/crops/strawberry.png'
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

formal_before = digest(PROJECT/runtime_path)
paths = list(json.loads((PROJECT/'assets/harvest_3d/source/RUNTIME_INTEGRATION_20261003.json').read_text())['runtime_hashes'])
paths += ['scripts/minigames/harvest_action.gd','scripts/harvest/harvest_target.gd',
          'scripts/harvest/harvest_basket.gd','scripts/harvest/harvest_visual_art.gd',
          'scripts/shared/tutorial_director.gd','tests/harvest_touch_probe.gd',
          'tests/harvest_probe.gd','tests/HarvestCatalogShot.gd',
          'tests/HarvestHeldShot.gd','tests/screenshot_tool.gd',
          'tests/probe_lifecycle.gd','tests/qa_run.py']
if args.completion:
    paths += ['tests/HarvestCompletionProbe.tscn','tests/HarvestCompletionProbe.gd']
records = []
shots = []
with QASession(PROJECT,find_godot(),name=args.name,timeout=30) as qa:
    if args.candidate:
        candidate = args.candidate.resolve()
        manifest = json.loads((candidate.parent/'manifest.json').read_text())
        assert digest(candidate)==manifest['files']['strawberry.png']['sha256']
        shutil.copyfile(candidate,qa.qa_root/runtime_path)
    hashes = {name:digest(qa.qa_root/name) for name in paths}
    qa.import_project(timeout=45)
    def run(scene,label,marker=None,env=None,headless=False,timeout=30):
        flags = ['--headless'] if headless else ['--rendering-driver','opengl3']
        result = qa.run_godot(flags+[scene],label=label,expect=marker,env=env,timeout=timeout)
        output = result.log_path.read_text()
        assert not re.search(r'ERROR:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Resources still in use',output),str(result.log_path)
        records.append({'label':label,'exit':result.returncode,'elapsed':result.elapsed,
                        'checks':re.findall(r'asked (\d+) questions',output)})
    run('res://tests/HarvestProbe.tscn','rules','HARVEST PROBE PASSED',headless=True)
    if args.touch:
        run('res://tests/HarvestTouchProbe.tscn','touch','HARVEST TOUCH PROBE PASSED',timeout=60)
    if args.completion:
        run('res://tests/HarvestCompletionProbe.tscn','completion','HARVEST COMPLETION PROBE PASSED',timeout=90)
    for size in (24,32,48,72,96):
        shot = qa.qa_root/'qa_shots'/f'catalog-{size}.png'
        run('res://tests/HarvestCatalogShot.tscn',f'catalog-{size}','HARVEST CATALOG SHOT PASSED',
            {'SHOT_BADGE_SIZE':str(size),'SHOT_PATH':str(shot)})
        shots.append(shot)
    for shape,window in (('16x9','1280x720'),('4x3','1024x768')):
        for level in ('harvest_02','harvest_08'):
            common = {'SHOT_WINDOW':window,'SHOT_LEVEL':level,'SHOT_SKIP_TUTORIAL':'1'}
            for held in (False,True):
                label = level+'-'+('held' if held else 'normal')+'-'+shape
                shot = qa.qa_root/'qa_shots'/(label+'.png')
                env = dict(common,SHOT_PATH=str(shot),SHOT_CROP_ID='strawberry')
                if held:
                    run('res://tests/HarvestHeldShot.tscn',label,'in_hand=true',env)
                else:
                    env['SHOT_SCENE'] = 'res://scenes/minigames/harvest_action/HarvestAction.tscn'
                    run('res://tests/Screenshot.tscn',label,
                        'screenshot_tool: CONTENT PASSED',env=env)
                shots.append(shot)
        shot = qa.qa_root/'qa_shots'/('harvest_02-held-low-motion-'+shape+'.png')
        run('res://tests/HarvestHeldShot.tscn','held-low-motion-'+shape,'in_hand=true',
            {'SHOT_WINDOW':window,'SHOT_LEVEL':'harvest_02','SHOT_CROP_ID':'strawberry',
             'SHOT_REDUCE_MOTION':'1','SHOT_PATH':str(shot)})
        shots.append(shot)
        if args.orchard:
            for held in (False,True):
                label = 'orchard-'+('held' if held else 'normal')+'-'+shape
                shot = qa.qa_root/'qa_shots'/(label+'.png')
                env = {'SHOT_WINDOW':window,'SHOT_LEVEL':'harvest_05','SHOT_PATH':str(shot),
                       'SHOT_CROP_ID':'orange','SHOT_SKIP_TUTORIAL':'1'}
                if held:
                    run('res://tests/HarvestHeldShot.tscn',label,'in_hand=true',env)
                else:
                    env['SHOT_SCENE'] = 'res://scenes/minigames/harvest_action/HarvestAction.tscn'
                    run('res://tests/Screenshot.tscn',label,
                        'screenshot_tool: CONTENT PASSED',env=env)
                shots.append(shot)
    image_checks = []
    for path in shots:
        with Image.open(path) as source:
            rgb = source.convert('RGB')
            variation = sum(ImageStat.Stat(rgb).var)
            assert variation>100,str(path)
            image_checks.append({'file':str(path.relative_to(qa.qa_root)),
                                 'size':list(source.size),'rgb_variance_sum':variation,
                                 'sha256':digest(path)})
    assert all(digest(qa.qa_root/name)==value for name,value in hashes.items())
    assert digest(PROJECT/runtime_path)==formal_before,'QA不允许改动正式素材'
    report = {'status':'自动检查通过；仍需人工读图，不等于儿童识别验收',
              'qa_root':str(qa.qa_root),'candidate_only':bool(args.candidate),
              'input_sha256':hashes,'runs':records,'images':image_checks,
              'formal_strawberry_unchanged':True}
    path = qa.qa_root/'qa_logs/strawberry_readability_summary.json'
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('STRAWBERRY RUNTIME REPORT',path,flush=True)
