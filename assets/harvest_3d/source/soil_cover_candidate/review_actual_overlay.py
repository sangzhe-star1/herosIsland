"""Exact used-alpha fitting and current-rig potato overlay at actual sizes.

Offline evidence only. Uses existing opacity/scale rule around the Target
origin; neither texture/camera nor game input is modified.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parent
STAGE = Path('/private/tmp/heroes-harvest-unified-art-stage-8djeaceh')
old_path = Path('/private/tmp/heroes-soil-cover-profile-final-m2t5u4pz/soil_cover_environment_standard.png')
new_path = ROOT/'rendered/soil_cover_environment_standard.png'
potato_path = STAGE/'assets/harvest_3d/crops/potato.png'
potato = Image.open(potato_path).convert('RGBA')
covers = {'old':Image.open(old_path).convert('RGBA'),'revision':Image.open(new_path).convert('RGBA')}
tile_size = (230,180)
origin = (115,85)
background = Image.new('RGBA',tile_size,(143,171,100,255))
montage = Image.new('RGB',(1010,520),(229,235,212))
draw = ImageDraw.Draw(montage)
draw.text((16,12),'OFFLINE overlay - frozen 4fac rig + actual stage potato; actual pixels, not a Godot page',fill=(43,51,36))
draw.text((16,31),'Original Target position/radius untouched. Ground +42. Existing opacity=1-f; parent scale=1-.2*f.',fill=(43,51,36))
review = {'profile_sha256':'4facaae15f88401f4f7553f12d4ec1e441e2a9597196b38a0b6a6b6fe2ea5512',
          'potato_sha256':hashlib.sha256(potato_path.read_bytes()).hexdigest(),
          'status':'Offline art evidence; requires real 16:9/4:3 scene integration',
          'source_alpha':{},'sizes':{}}
def affine_source(image,scale,ground_y):
    return image.transform(tile_size,Image.Transform.AFFINE,
        (1/scale,0,256-origin[0]/scale,0,1/scale,467-(origin[1]+ground_y)/scale),
        resample=Image.Resampling.BICUBIC)
for name,image in covers.items():
    box = image.getchannel('A').getbbox()
    assert box and min(box[:2])>0 and max(box[2:])<512
    review['source_alpha'][name] = {'bbox_alpha_gt_0':box,'width':box[2]-box[0],
        'height':box[3]-box[1],
        'sha256':hashlib.sha256((old_path if name=='old' else new_path).read_bytes()).hexdigest()}
for row,crop_size in enumerate((90,72)):
    crop = affine_source(potato,crop_size*2/512,42)
    crop_alpha = crop.getchannel('A')
    review['sizes'][str(crop_size)] = {}
    start_y = 88+row*212
    draw.text((16,start_y-20),f'crop_size={crop_size}; crop canvas={crop_size*2}; apparent cover width={crop_size*1.30:.1f}',fill=(43,51,36))
    for col,(name,fraction) in enumerate((('old',0),('old',1/3),('revision',0),('revision',1/3))):
        image = covers[name]
        width = review['source_alpha'][name]['width']
        source_scale = crop_size*1.30/width
        parent_scale = 1-.2*fraction
        cover = affine_source(image,source_scale*parent_scale,42*parent_scale)
        alpha_unmodulated = cover.getchannel('A')
        cover.putalpha(alpha_unmodulated.point(lambda value:round(value*(1-fraction))))
        tile = background.copy()
        tile.alpha_composite(crop)
        tile.alpha_composite(cover)
        uncovered = total = 0
        for y in range(tile_size[1]):
            for x in range(tile_size[0]):
                if crop_alpha.getpixel((x,y))>127:
                    total+=1
                    if alpha_unmodulated.getpixel((x,y))<127:
                        uncovered+=1
        key = f'{name}_f{fraction:.3f}'
        mask_box = alpha_unmodulated.getbbox()
        review['sizes'][str(crop_size)][key] = {
            'canvas_size_float':512*source_scale,'source_to_pixel_scale':source_scale,
            'container_scale':parent_scale,'soil_opacity':1-fraction,
            'soil_used_rect_relative_target':[mask_box[0]-origin[0],mask_box[1]-origin[1],
                                             mask_box[2]-origin[0],mask_box[3]-origin[1]],
            'potato_geometrically_uncovered_fraction':uncovered/max(1,total)}
        montage.paste(tile.convert('RGB'),(16+col*245,start_y))
        draw.text((22+col*245,start_y+7),f'{name}, dig {fraction:.2f}',fill=(44,48,34))
        draw.text((22+col*245,start_y+161),f'potato exposed {uncovered/max(1,total)*100:.1f}%',fill=(44,48,34))
        tile.save(ROOT/f'overlay_{crop_size}_{key}.png')
draw.text((16,509),'Compare left old soil with right revision: real pale tuber + eye remain visible before digging; 1/3 fade has clearer contrast.',fill=(43,51,36))
montage.save(ROOT/'review_old_vs_revision_90_72.png')
(ROOT/'alpha_and_cover_review.json').write_text(json.dumps(review,indent=2)+'\n')
print(json.dumps(review,indent=2))
