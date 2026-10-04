#!/usr/bin/env python3
"""Look at the rendered sprites the way the game will.

    python3 audit.py <rendered dir | directory of PNGs> [--sheet PATH] [--quiet]

Checks every PNG against contract.json:
  * 512 x 512 RGBA, not empty, not clipped at the canvas edge
  * the lowest solid row sits on the ground line (the pivot the game anchors
    by), within the band the 3/4 camera gives a wide footprint
  * the footprint is centred under the pivot column
  * no black fringe: semi-transparent pixels keep their colour
When the directory has a manifest.json, each entry's pivot must match the
contract and its file must exist. Then it draws a contact sheet with the
ground line marked, so the eye gets the last word.

Exit code 1 on any error. Plain Python plus Pillow; no Blender needed, so
the check also runs on the PNGs already checked into ../../crops.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
CONTRACT = json.loads((HERE / 'contract.json').read_text())


def measure(path):
    """The few numbers the rules are written against."""
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    px = im.load()
    rules = CONTRACT['audit']
    solid = int(rules['solid_alpha'])
    semi_lo, semi_hi = rules['semi_alpha']
    lowest = -1
    semi = black = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a >= solid:
                lowest = y
            elif semi_lo < a < semi_hi:
                semi += 1
                if max(r, g, b) < 10:
                    black += 1
    feet = [x for y in range(max(0, lowest - 3), lowest + 1)
            for x in range(w) if px[x, y][3] >= solid] if lowest >= 0 else []
    return {
        'size': (w, h), 'mode': Image.open(path).mode, 'bbox': im.getbbox(),
        'lowest_solid_row': lowest,
        'foot_centre': (min(feet) + max(feet)) / 2.0 if feet else None,
        'semi': semi, 'black_fringe': black, 'image': im,
    }


def check(path, m, allow_edge=False, deep=False, floats=False):
    rules = dict(CONTRACT['audit'])
    if floats:
        # A butterfly or a windmill's sails never touch the ground; the
        # farm places them by their pivot, so only the canvas rules apply.
        rules['lowest_solid_row_min'] = 0
        rules['lowest_solid_row_max'] = int(CONTRACT['sprite_size']) - 2
        rules['footprint_centre_tolerance_px'] = 10_000
    if deep:
        # A building or an animal stands on an area, not a point: its nearest
        # corner may sit well below and beside the pivot. The canvas-edge
        # rule still holds; a clipped barn is a clipped barn.
        rules['lowest_solid_row_max'] = int(CONTRACT['sprite_size']) - 2
        rules['footprint_centre_tolerance_px'] = 200
    size = int(CONTRACT['sprite_size'])
    px, py = CONTRACT['ground_pivot_pixel']
    errors = []
    if m['size'] != (size, size):
        errors.append('is %dx%d, the contract says %dx%d' % (*m['size'], size, size))
    if m['mode'] != 'RGBA':
        errors.append('is %s, not RGBA -- it has no alpha to sit on the grass with' % m['mode'])
    if m['bbox'] is None:
        errors.append('is empty: nothing rendered')
        return errors
    margin = int(rules['edge_margin_px'])
    x0, y0, x1, y1 = m['bbox']
    if not allow_edge and (x0 < margin or y0 < margin
                           or x1 > size - margin or y1 > size - margin):
        errors.append('touches the canvas edge (bbox %s): the camera clips it, or it is '
                      'too big for the frame' % (m['bbox'],))
    low = m['lowest_solid_row']
    if low < 0:
        errors.append('has no solid pixel at all -- a ghost')
    elif allow_edge:
        pass          # a ground patch's front rim reaches the edge by design
    elif not rules['lowest_solid_row_min'] <= low <= rules['lowest_solid_row_max']:
        errors.append('stands on row %d; the ground line is %d (allowed %d..%d) -- it would '
                      'float or sink when harvest_visual_art.gd anchors it'
                      % (low, py, rules['lowest_solid_row_min'], rules['lowest_solid_row_max']))
    if m['foot_centre'] is not None:
        off = m['foot_centre'] - px
        if abs(off) > float(rules['footprint_centre_tolerance_px']):
            errors.append('footprint centre is %+.0f px from the pivot column %d'
                          % (off, px))
    if m['semi'] and m['black_fringe'] / m['semi'] > float(rules['black_fringe_max_fraction']):
        errors.append('%d of %d semi-transparent pixels are black: a dark fringe, the '
                      'alpha was premultiplied or the background leaked in'
                      % (m['black_fringe'], m['semi']))
    return errors


def contact_sheet(items, path, cell=96):
    """Every asset at about runtime size, ground line drawn through each cell."""
    cols = 6
    rows = (len(items) + cols - 1) // cols
    pad = 8
    sheet = Image.new('RGBA', (cols * (cell + pad) + pad, rows * (cell + 26 + pad) + pad),
                      (214, 226, 196, 255))
    draw = ImageDraw.Draw(sheet)
    size = CONTRACT['sprite_size']
    py = CONTRACT['ground_pivot_pixel'][1]
    for i, (name, im) in enumerate(items):
        cx = pad + (i % cols) * (cell + pad)
        cy = pad + (i // cols) * (cell + 26 + pad)
        ground = cy + int(py * cell / size)
        draw.line([(cx, ground), (cx + cell, ground)], fill=(120, 96, 60, 255), width=1)
        small = im.resize((cell, cell), Image.LANCZOS)
        sheet.alpha_composite(small, (cx, cy))
        draw.text((cx + 2, cy + cell + 4), name[:16], fill=(40, 40, 40, 255))
    sheet.save(path)


def main(argv):
    quiet = '--quiet' in argv
    argv = [a for a in argv if a != '--quiet']
    sheet_path = None
    if '--sheet' in argv:
        i = argv.index('--sheet')
        sheet_path = Path(argv[i + 1])
        del argv[i:i + 2]
    if not argv:
        print(__doc__)
        return 2
    root = Path(argv[0])
    manifest = None
    if (root / 'manifest.json').exists():
        manifest = json.loads((root / 'manifest.json').read_text())
    pngs = sorted(root.rglob('*.png')) if root.is_dir() else [root]
    pngs = [p for p in pngs if 'contact_sheet' not in p.name]
    edge_ok = set()
    deep = set()
    floats = set()
    if manifest:
        for a in manifest.get('assets', []):
            if a.get('footprint_reaches_edge'):
                edge_ok.add(a['id'])
            if a.get('deep_footprint'):
                deep.add(a['id'])
            if a.get('floats'):
                floats.add(a['id'])
            if list(a.get('ground_pivot_pixel', [])) != list(CONTRACT['ground_pivot_pixel']):
                print('ERROR manifest: %s pivot %s, contract %s'
                      % (a['id'], a.get('ground_pivot_pixel'), CONTRACT['ground_pivot_pixel']))
                return 1
            if not (root / a['file']).exists():
                print('ERROR manifest: %s names %s, which is not there' % (a['id'], a['file']))
                return 1
    else:
        # Checked-in game folders carry no manifest; the one prop that reaches
        # the edge by design says so in its recipe.
        for r in (HERE / 'recipes').glob('*.json'):
            recipe = json.loads(r.read_text())
            if recipe.get('footprint_reaches_edge'):
                edge_ok.add(r.stem)
            if recipe.get('deep_footprint'):
                deep.add(r.stem)
            if recipe.get('floats'):
                floats.add(r.stem)
    failures = 0
    items = []
    for png in pngs:
        m = measure(png)
        errors = check(png, m, allow_edge=png.stem in edge_ok, deep=png.stem in deep,
                       floats=png.stem in floats)
        items.append((png.stem, m['image']))
        if errors:
            failures += 1
            for e in errors:
                print('ERROR %s: %s' % (png.name, e))
        elif not quiet:
            print('ok    %-22s ground row %d, footprint centre %+.0f px'
                  % (png.name, m['lowest_solid_row'],
                     (m['foot_centre'] or 0) - CONTRACT['ground_pivot_pixel'][0]))
    if items:
        contact_sheet(items, sheet_path or (root / 'contact_sheet.png'))
    print('audit: %d sprites, %d failed' % (len(items), failures))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
