"""Render every recipe through the one studio.

    blender -b -P build.py -- [--only carrot,tomato] [--out DIR] [--glb]
                               [--install] [--blend]

  --only     render just these ids (default: every recipes/*.json)
  --out      output root (default: ../rendered, next to the old pack)
  --glb      also write <id>.glb beside each PNG
  --install  copy the PNGs into ../../crops and ../../props (what the game
             loads) and write the sidecar <id>.json for a prop whose shadow
             is not baked
  --blend    save the whole studio as rendered/harvest_studio.blend

After rendering it writes rendered/manifest.json and runs audit.py on the
result with the system python (Blender's python has no Pillow), so one
command answers "did it render", "is the pivot right", "is there a fringe"
and "what does the set look like" (rendered/contact_sheet.png).

Adding an asset: recipes/<id>.json naming a model in models/, and the
model's build(S, P). Nothing else changes.
"""
import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from studio import Studio, CONTRACT  # noqa: E402


def parse_args(argv):
    opts = {'only': None, 'out': HERE.parent / 'rendered', 'glb': False,
            'install': False, 'blend': False}
    it = iter(argv)
    for a in it:
        if a == '--only':
            opts['only'] = next(it).split(',')
        elif a == '--out':
            opts['out'] = Path(next(it)).expanduser()
        elif a in ('--glb', '--install', '--blend'):
            opts[a[2:]] = True
        else:
            raise SystemExit('build.py: unknown option %r' % a)
    return opts


def load_recipes(only=None):
    recipes = []
    for path in sorted((HERE / 'recipes').glob('*.json')):
        r = json.loads(path.read_text())
        if r['id'] != path.stem:
            raise SystemExit('%s: id %r does not match the file name' % (path.name, r['id']))
        if only is None or r['id'] in only:
            recipes.append(r)
    if only:
        missing = set(only) - {r['id'] for r in recipes}
        if missing:
            raise SystemExit('build.py: no recipe for %s' % ', '.join(sorted(missing)))
    return recipes


def load_model(name):
    path = HERE / 'models' / (name + '.py')
    if not path.exists():
        raise SystemExit('build.py: recipe asks for model %r, no %s' % (name, path))
    spec = importlib.util.spec_from_file_location('harvest_model_' + name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    if not hasattr(mod, 'build'):
        raise SystemExit('%s: a model must define build(S, P)' % path.name)
    return mod


def main(argv):
    import bpy
    opts = parse_args(argv)
    out = opts['out']
    sprites = out / 'sprites'
    sprites.mkdir(parents=True, exist_ok=True)
    recipes = load_recipes(opts['only'])
    S = Studio()
    colls = {}
    for r in recipes:
        model = load_model(r['model'])
        params = dict(r.get('params', {}))
        colls[r['id']] = S.asset(r['id'], lambda: model.build(S, params), r.get('shadow', {}))
    manifest = []
    for r in recipes:
        coll = colls[r['id']]
        png = sprites / (r['id'] + '.png')
        S.render(coll, png, list(colls.values()))
        entry = {
            'id': r['id'], 'kind': r['kind'], 'model': r['model'],
            'params': r.get('params', {}),
            'file': 'sprites/' + png.name, 'resolution': [S.size, S.size],
            'ground_pivot_pixel': S.pivot_px,
            'pivot_offset_from_texture_center_px': [S.pivot_px[0] - S.size // 2,
                                                    S.pivot_px[1] - S.size // 2],
            'contact_shadow_baked': bool(r.get('shadow', {}).get('baked', True)),
            'install': r.get('install'),
        }
        if r.get('footprint_reaches_edge'):
            entry['footprint_reaches_edge'] = True
        if opts['glb']:
            glb = sprites / (r['id'] + '.glb')
            S.export_glb(coll, glb, list(colls.values()))
            entry['glb'] = 'sprites/' + glb.name
        manifest.append(entry)
        print('RENDERED', r['id'], flush=True)
    for coll in colls.values():
        coll.hide_render = False
    (out / 'manifest.json').write_text(json.dumps({
        'version': 2, 'sprite_size': S.size, 'contract': CONTRACT,
        'assets': manifest}, indent=2) + '\n')
    if opts['blend']:
        bpy.ops.wm.save_as_mainfile(filepath=str(out / 'harvest_studio.blend'))

    if opts['install']:
        game = HERE.parent.parent
        for r, entry in zip(recipes, manifest):
            target = game / r['install']
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(sprites / (r['id'] + '.png'), target)
            side = target.with_suffix('.json')
            if not entry['contact_shadow_baked']:
                side.write_text(json.dumps({'contact_shadow_baked': False,
                                            'source': 'pipeline/recipes/%s.json' % r['id']},
                                           indent=2) + '\n')
            elif side.exists() and r['kind'] == 'prop':
                # A baked shadow is the runtime's default assumption; a stale
                # "not baked" sidecar would make it draw a second one.
                side.unlink()
            print('INSTALLED', target, flush=True)

    # The audit needs Pillow, which Blender's python does not ship.
    code = subprocess.call([shutil.which('python3') or 'python3',
                            str(HERE / 'audit.py'), str(out)])
    if code != 0:
        raise SystemExit('build.py: audit failed (%d); the renders are in %s' % (code, out))


if __name__ == '__main__':
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    main(argv)
