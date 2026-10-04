"""Existing geometry, not a new model.

For an asset whose shape already exists as a GLB (the whole-plant basket,
the soil cover, anything an artist hands over): import it and render it
through the same studio as everything else. Params:

    file      path to the .glb, relative to this pipeline folder
    scale     optional uniform scale (default 1)
    rotate_z  optional yaw in degrees (default 0)

The GLB's origin is taken as the ground pivot, which is the contract every
exporter in source/ already follows (Y-up in the file, Z-up back in Blender).
"""
import math
from pathlib import Path

import bpy


def build(S, P):
    path = (Path(__file__).resolve().parent.parent / P['file']).resolve()
    if not path.exists():
        raise RuntimeError('from_glb: %s is missing' % path)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    made = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in made if o.parent is None or o.parent not in made]
    for root in roots:
        root.scale = root.scale * float(P.get('scale', 1.0))
        root.rotation_mode = 'XYZ'
        root.rotation_euler.z += math.radians(float(P.get('rotate_z', 0.0)))
    for o in made:
        if o.type == 'MESH':
            for poly in o.data.polygons:
                poly.use_smooth = True
