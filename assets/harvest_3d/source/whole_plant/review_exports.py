"""只生成资产小尺寸审图与 alpha 数据，不修改源 PNG。"""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image, ImageDraw

SCRIPT_ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--root',type=Path,default=SCRIPT_ROOT/'rendered')
parser.add_argument('--out',type=Path)
parser.add_argument('--current-assets',type=Path,default=SCRIPT_ROOT.parents[1])
parser.add_argument('--cutouts-only',action='store_true',help='仅检查同源环境的单果、株身和篮子，不要求四果整株图')
options = parser.parse_args()
ROOT = options.root.resolve()
OUT = options.out.resolve() if options.out else ROOT
manifest_path = ROOT/'manifest.json'
manifest = json.loads(manifest_path.read_text())
OUT.mkdir(parents=True,exist_ok=True)
rows = [('Fruit','tomato_fruit_512.png'),('Plant body','plant001_body_512.png'),
        ('Empty basket','basket_512.png'),('Whole plant (reference)','plant001_512.png')]
if options.cutouts_only:
    rows = rows[:3]
sheet = Image.new('RGB',(650,80+130*len(rows)),(248,241,227))
draw = ImageDraw.Draw(sheet)
draw.text((20,15),'48 / 72 / 96 px canvas preview - whole plant is art reference',fill=(65,50,35))
metrics = {}
for row,(label,name) in enumerate(rows):
    y = 65+row*130
    draw.text((20,y+32),label,fill=(65,50,35))
    source = Image.open(ROOT/name).convert('RGBA')
    alpha = source.getchannel('A')
    bounds = alpha.getbbox()
    metrics[name] = {'size':list(source.size),'alpha_bounds':bounds,
        'world0_px':[256,467],'sha256':hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),
        'border_alpha_nonzero': any(alpha.crop(box).getbbox() for box in
            [(0,0,512,1),(0,511,512,512),(0,0,1,512),(511,0,512,512)])}
    for column,size in enumerate((48,72,96)):
        x = 220+column*140
        draw.text((x,y-20),str(size)+' px',fill=(65,50,35))
        reduced = source.resize((size,size),Image.Resampling.LANCZOS)
        sheet.paste(reduced,(x,y+96-size),reduced)
sheet.save(OUT/'small_scale_review.png')
if not options.cutouts_only:
    large = Image.open(ROOT/'plant001_transparent.png').convert('RGBA')
    large_alpha = large.getchannel('A')
    metrics['plant001_transparent.png'] = {'size':list(large.size),'alpha_bounds':large_alpha.getbbox(),
        'world0_px':[512,934],'sha256':hashlib.sha256((ROOT/'plant001_transparent.png').read_bytes()).hexdigest(),
        'border_alpha_nonzero':any(large_alpha.crop(box).getbbox() for box in
            [(0,0,1024,1),(0,1023,1024,1024),(0,0,1,1024),(1023,0,1024,1024)])}
runtime_rows = rows[:3]
runtime_sheet = Image.new('RGB',(680,800),(248,241,227))
runtime_draw = ImageDraw.Draw(runtime_sheet)
runtime_draw.text((20,12),'Runtime art_size 72 / 90 = 144 / 180 px transparent canvas',fill=(65,50,35))
current_paths = list(options.current_assets.rglob('tomato.png'))+list(options.current_assets.rglob('basket_empty.png'))
runtime_rows += [(path.stem+' current',str(path)) for path in current_paths]
for row,(label,name) in enumerate(runtime_rows):
    y = 58+row*145
    runtime_draw.text((15,y+45),label,fill=(65,50,35))
    source = Image.open(Path(name) if Path(name).is_absolute() else ROOT/name).convert('RGBA')
    for column,art_size in enumerate((72,90)):
        canvas = art_size*2
        x = 250+column*205
        runtime_draw.text((x,y-15),str(art_size)+' art / '+str(canvas)+' canvas',fill=(65,50,35))
        sprite = source.resize((canvas,canvas),Image.Resampling.LANCZOS)
        # Contact sheet uses one consistent bottom ground line for each row.
        runtime_sheet.paste(sprite,(x,y+132-int(467/512*canvas)),sprite)
runtime_sheet.save(OUT/'runtime_art_size_review.png')
(OUT/'alpha_review.json').write_text(json.dumps(metrics,indent=2)+'\n')
manifest['transparent_pngs'] = metrics
assert not any(item['border_alpha_nonzero'] for item in metrics.values()), '透明图碰到画布边界'
manifest['qa_contact_sheets'] = {'small_scale_review.png':'48/72/96 refers to full transparent canvas, not runtime art_size',
    'runtime_art_size_review.png':'runtime art_size72/90 with 144/180px canvas; current tomato/basket comparison'}
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(metrics,indent=2))
