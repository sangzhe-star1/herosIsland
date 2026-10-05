"""Render every recipe through the one studio.

    blender -b -P build.py -- [--only carrot,tomato] [--out DIR] [--glb]
                               [--install] [--blend] [--audit-python PATH]

  --only     render just these ids (default: every recipes/*.json)
  --out      output root (default: ../rendered, next to the old pack)
  --glb      also write <id>.glb beside each PNG
  --install  copy the PNGs into ../../crops and ../../props (what the game
             loads) and write the sidecar <id>.json for a prop whose shadow
             is not baked
  --blend    save the whole studio as rendered/harvest_studio.blend
  --rig      "profile" (default: the frozen profile every shipped sprite was
             rendered with) or "legacy" (build_pack.py's softbox + baked shadow)
  --audit-python  Python executable with Pillow (default: python3 on PATH)

After rendering it writes rendered/manifest.json and runs audit.py on the
result with the system python (Blender's python has no Pillow), so one
command answers "did it render", "is the pivot right", "is there a fringe"
and "what does the set look like" (rendered/contact_sheet.png).

Adding an asset: recipes/<id>.json naming a model in models/, and the
model's build(S, P). Nothing else changes.
"""
import importlib.util
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))


def parse_args(argv):
    opts = {'only': None, 'out': HERE.parent / 'rendered', 'glb': False,
            'install': False, 'blend': False, 'rig': None, 'audit_python': None}
    it = iter(argv)
    for a in it:
        if a == '--only':
            opts['only'] = next(it).split(',')
        elif a == '--out':
            opts['out'] = Path(next(it)).expanduser()
        elif a == '--rig':
            opts['rig'] = next(it)
        elif a == '--audit-python':
            opts['audit_python'] = str(Path(next(it)).expanduser())
        elif a in ('--glb', '--install', '--blend'):
            opts[a[2:]] = True
        else:
            raise SystemExit('build.py: unknown option %r' % a)
    return opts


def validate_anchors(recipe):
    """Reject malformed recipe coordinates before starting a render."""
    anchors = recipe.get('anchors', {})
    if not isinstance(anchors, dict):
        raise ValueError('anchors must be a dictionary of named local 3D points')
    for name, point in anchors.items():
        if not isinstance(name, str) or not name or not isinstance(point, (list, tuple)) \
                or len(point) != 3 or not all(isinstance(v, (int, float))
                                             and not isinstance(v, bool)
                                             and math.isfinite(v) for v in point):
            raise ValueError('anchor %r must name a finite local 3D point' % name)
    if anchors:
        offset = recipe.get('origin_offset', [0, 0, 0])
        if not isinstance(offset, (list, tuple)) or len(offset) != 3 \
                or not all(isinstance(v, (int, float)) and not isinstance(v, bool)
                           and math.isfinite(v) for v in offset):
            raise ValueError('origin_offset must be a finite 3D point when anchors are used')


def project_anchors(studio, recipe):
    """Project model-local points through the camera that just rendered it."""
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector

    validate_anchors(recipe)
    offset = recipe.get('origin_offset', [0, 0, 0])
    result = {}
    for name, point in recipe.get('anchors', {}).items():
        world_point = Vector(tuple(v + shift for v, shift in zip(point, offset)))
        projected = world_to_camera_view(studio.scene, studio.camera, world_point)
        pixel = [projected.x * studio.size, (1 - projected.y) * studio.size]
        if not math.isfinite(projected.z) or projected.z <= 0 \
                or not all(math.isfinite(v) and 0 <= v < studio.size for v in pixel):
            raise ValueError('%s anchor %s is outside the rendered canvas: %s'
                             % (recipe['id'], name, pixel))
        result[name] = [round(v, 4) for v in pixel]
    return result


def sidecar_metadata(recipe, entry):
    """Keep explicit anchors even for assets whose contact shadow is baked."""
    if entry['contact_shadow_baked'] and not entry.get('anchors_px'):
        return None
    metadata = {'contact_shadow_baked': entry['contact_shadow_baked'],
                'source': 'pipeline/recipes/%s.json' % recipe['id']}
    if entry.get('anchors_px'):
        metadata['anchors_px'] = entry['anchors_px']
    return metadata


def run_audit(out, audit_python=None):
    """Use an argv list so paths with spaces stay a single executable argument."""
    executable = audit_python or shutil.which('python3') or 'python3'
    try:
        return subprocess.call([executable, str(HERE / 'audit.py'), str(out)])
    except OSError as exc:
        raise SystemExit('build.py: cannot run audit Python %r: %s; use --audit-python '
                         'with an interpreter that has Pillow' % (executable, exc)) from exc


def load_recipes(only=None):
    recipes = []
    for path in sorted((HERE / 'recipes').glob('*.json')):
        r = json.loads(path.read_text())
        if r['id'] != path.stem:
            raise SystemExit('%s: id %r does not match the file name' % (path.name, r['id']))
        if only is None or r['id'] in only:
            try:
                validate_anchors(r)
            except ValueError as exc:
                raise SystemExit('%s: %s' % (path.name, exc)) from exc
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
    from studio import Studio, CONTRACT
    opts = parse_args(argv)
    out = opts['out']
    sprites = out / 'sprites'
    sprites.mkdir(parents=True, exist_ok=True)
    recipes = load_recipes(opts['only'])
    S = Studio(rig=opts['rig'])
    colls = {}
    for r in recipes:
        model = load_model(r['model'])
        params = dict(r.get('params', {}))
        colls[r['id']] = S.asset(r['id'], lambda: model.build(S, params), r.get('shadow', {}),
                                 tuple(r.get('origin_offset', (0.0, 0.0, 0.0))))
    manifest = []
    for r in recipes:
        coll = colls[r['id']]
        png = sprites / (r['id'] + '.png')
        span = S.render(coll, png, list(colls.values()), r.get('ortho_scale'))
        entry = {
            'id': r['id'], 'kind': r['kind'], 'model': r['model'],
            'params': r.get('params', {}),
            'file': 'sprites/' + png.name, 'resolution': [S.size, S.size],
            'ortho_scale': span,
            'ground_pivot_pixel': S.pivot_px,
            'pivot_offset_from_texture_center_px': [S.pivot_px[0] - S.size // 2,
                                                    S.pivot_px[1] - S.size // 2],
            'contact_shadow_baked': bool(r.get('shadow', {}).get('baked', S.shadow_default_baked)),
            'rig': S.rig,
            'install': r.get('install'),
        }
        if r.get('footprint_reaches_edge'):
            entry['footprint_reaches_edge'] = True
        if r.get('deep_footprint'):
            entry['deep_footprint'] = True
        if r.get('floats'):
            entry['floats'] = True
        if r.get('anchors'):
            entry['anchors_px'] = project_anchors(S, r)
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

    # The audit needs Pillow, which Blender's python does not ship. It runs
    # BEFORE install: a sprite that fails the audit never reaches the game.
    code = run_audit(out, opts['audit_python'])
    if code != 0:
        raise SystemExit('build.py: audit failed (%d); nothing installed; the renders are in %s' % (code, out))

    if opts['install']:
        game = HERE.parent.parent
        for r, entry in zip(recipes, manifest):
            if not r.get('install'):
                print('NOT INSTALLED', r['id'], '(recipe has no install path)', flush=True)
                continue
            target = game / r['install']
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(sprites / (r['id'] + '.png'), target)
            side = target.with_suffix('.json')
            metadata = sidecar_metadata(r, entry)
            if metadata is not None:
                side.write_text(json.dumps(metadata, indent=2) + '\n')
            elif side.exists() and r['kind'] == 'prop':
                # A baked shadow is the runtime's default assumption; a stale
                # "not baked" sidecar would make it draw a second one.
                side.unlink()
            print('INSTALLED', target, flush=True)


if __name__ == '__main__':
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    main(argv)
