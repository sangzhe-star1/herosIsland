"""Editable, source-built display of the three refined farm assets.

Review only: this scene never replaces the interactive Godot world.
  blender -b --python-exit-code 1 -P build_polish_review.py -- --out DIR
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from studio import Studio
from build import load_model


def main():
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    out = Path(args[args.index('--out') + 1]) if '--out' in args else HERE.parent / 'blender_polish_20261004' / 'review'
    out.mkdir(parents=True, exist_ok=True)
    studio = Studio()
    rotation = studio.camera.matrix_world.to_quaternion()
    right = rotation @ Vector((1, 0, 0))
    right.z = 0
    right.normalize()

    def asset(asset_id, at, scale=1.0):
        recipe = json.loads((HERE / 'recipes' / (asset_id + '.json')).read_text())
        model = load_model(recipe['model'])
        coll = studio.asset(asset_id, lambda: model.build(studio, recipe.get('params', {})), {'baked': False})
        members = set(coll.objects)
        for obj in members:
            if obj.parent is None or obj.parent not in members:
                obj.location = obj.location * scale + Vector(at)
                obj.scale *= scale
        return coll

    asset('building_warehouse', right * -2.8)
    asset('soil_grass_patch', (0, 0, 0))
    asset('carrot', (0, 0, .10), .65)
    asset('building_bear_door', right * 2.7)
    asset('basket_empty', right * -.85 + Vector((.25, -.80, .0)), .60)

    turf = studio.material('Review | muted meadow clay', (.38, .51, .235), .95)
    floor = studio.block('Review plinth | not a runtime background', (0, .12, -.19), (9.2, 3.4, .34), turf, .14)
    floor.rotation_euler.z = math.atan2(right.y, right.x)
    # A simple shared display floor makes all contacts inspectable. It is not
    # exported or used as a background in the game.
    studio.scene.render.resolution_x = 1600
    studio.scene.render.resolution_y = 900
    studio.scene.render.film_transparent = False
    studio.scene.cycles.samples = 64
    studio.scene.cycles.use_denoising = True
    studio.camera.data.ortho_scale = 10.4
    forward = rotation @ Vector((0, 0, -1))
    studio.camera.location = Vector((0, 0, .6)) - forward * 14
    bpy.context.view_layer.update()
    point = world_to_camera_view(studio.scene, studio.camera, Vector((0, 0, .6)))
    up = rotation @ Vector((0, 1, 0))
    studio.camera.location += up * ((point.y - .52) * 10.4 / (1600 / 900))
    studio.scene.render.filepath = str(out / 'farm_polish_review.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(out / 'farm_polish_review.blend'))
    bpy.ops.render.render(write_still=True)
    print('POLISH_REVIEW_COMPLETE', out)


if __name__ == '__main__':
    main()
