"""The one studio every harvest sprite is rendered in.

Runs inside Blender (bpy). Everything that used to be copied into fifteen
scripts lives here once: the scene reset, the Cycles settings, the fixed 3/4
orthographic camera, the softbox, the palette, the primitive helpers the
models are built from, the optional baked contact shadow, and the check that
the world origin really lands on the pivot pixel the game expects.

A model file (models/<name>.py) gets a Studio and builds geometry with it.
A recipe (recipes/<id>.json) says which model, which params, which shadow,
and where the PNG is installed. build.py walks the recipes.

Nothing here knows about any particular crop.
"""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
CONTRACT = json.loads((HERE / 'contract.json').read_text())
PALETTE = json.loads((HERE / 'palette.json').read_text())['materials']


class Studio:
    """Scene, rig, palette and primitives. One per build run."""

    def __init__(self, contract=CONTRACT, palette=PALETTE):
        self.contract = contract
        self.size = int(contract['sprite_size'])
        self._reset_scene()
        self._render_settings()
        self.M = {key: self.material(spec['label'], tuple(spec['color']),
                                     float(spec.get('roughness', 0.84)))
                  for key, spec in palette.items()}
        self.shadow_mat = self._soft_shadow_material()
        self.studio_coll = bpy.data.collections.new('STUDIO | shared render rig')
        self.scene.collection.children.link(self.studio_coll)
        self.camera = self._camera()
        self.light = self._light()
        bpy.context.view_layer.update()
        self.pivot_px = self._pivot_pixel()
        wanted = list(contract['ground_pivot_pixel'])
        if self.pivot_px != wanted:
            raise RuntimeError(
                'studio: world origin projects to pixel %s, the contract says %s. '
                'The camera moved; fix contract.json or the camera, not the game.'
                % (self.pivot_px, wanted))

    # --- scene -----------------------------------------------------------------

    def _reset_scene(self):
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        for coll in list(bpy.data.collections):
            if coll.name != 'Collection':
                bpy.data.collections.remove(coll)
        self.scene = bpy.context.scene

    def _render_settings(self):
        c = self.contract
        s = self.scene
        s.render.engine = c['render']['engine']
        s.cycles.samples = int(c['render']['samples'])
        s.cycles.use_denoising = bool(c['render']['denoise'])
        s.cycles.transparent_max_bounces = int(c['render']['transparent_max_bounces'])
        s.render.resolution_x = s.render.resolution_y = self.size
        s.render.resolution_percentage = 100
        s.render.image_settings.file_format = 'PNG'
        s.render.image_settings.color_mode = 'RGBA'
        s.render.image_settings.color_depth = '8'
        s.render.film_transparent = True
        s.view_settings.view_transform = c['render']['view_transform']
        s.world.color = (0.10, 0.10, 0.10)
        s.world.use_nodes = True
        bg = s.world.node_tree.nodes['Background']
        bg.inputs['Color'].default_value = (*c['world']['background'], 1)
        bg.inputs['Strength'].default_value = float(c['world']['strength'])

    def _put(self, obj):
        for coll in list(obj.users_collection):
            coll.objects.unlink(obj)
        self.studio_coll.objects.link(obj)
        return obj

    @staticmethod
    def _aim(obj, target):
        obj.rotation_euler = (Vector(target) - Vector(obj.location)) \
            .to_track_quat('-Z', 'Y').to_euler()

    def _camera(self):
        c = self.contract['camera']
        data = bpy.data.cameras.new('Studio | fixed 3-4 orthographic')
        cam = bpy.data.objects.new('Studio | fixed 3-4 orthographic', data)
        self.studio_coll.objects.link(cam)
        cam.location = tuple(c['location'])
        self._aim(cam, c['target'])
        data.type = c['type']
        data.ortho_scale = float(c['ortho_scale'])
        data.lens = float(c['lens'])
        self.scene.camera = cam
        return cam

    def _light(self):
        c = self.contract['light']
        data = bpy.data.lights.new('Studio | large warm softbox', c['type'])
        lamp = bpy.data.objects.new('Studio | large warm softbox', data)
        self.studio_coll.objects.link(lamp)
        lamp.location = tuple(c['location'])
        data.energy = float(c['energy'])
        data.shape = c['shape']
        data.size = float(c['size'])
        self._aim(lamp, c['target'])
        return lamp

    def _pivot_pixel(self):
        """Where the world origin lands in the sprite. The game's ground line."""
        cam = self.camera
        scale = cam.data.ortho_scale
        p = cam.matrix_world.inverted() @ Vector((0, 0, 0))
        return [round((p.x / scale + .5) * self.size),
                round((.5 - p.y / scale) * self.size)]

    # --- materials -------------------------------------------------------------

    @staticmethod
    def material(name, color, rough=.84):
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*color, 1)
        m.use_nodes = True
        nodes = m.node_tree.nodes
        bs = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bs is None:
            bs = nodes.new('ShaderNodeBsdfPrincipled')
        out = next((n for n in nodes if n.type == 'OUTPUT_MATERIAL'), None)
        if out is None:
            out = nodes.new('ShaderNodeOutputMaterial')
        if not out.inputs['Surface'].is_linked:
            m.node_tree.links.new(bs.outputs['BSDF'], out.inputs['Surface'])
        bs.inputs['Base Color'].default_value = (*color, 1)
        bs.inputs['Roughness'].default_value = rough
        return m

    @staticmethod
    def _soft_shadow_material():
        m = bpy.data.materials.new('Studio | soft contact shadow in alpha')
        m.use_nodes = True
        n = m.node_tree.nodes
        n.clear()
        links = m.node_tree.links
        tex = n.new('ShaderNodeTexCoord')
        sub = n.new('ShaderNodeVectorMath'); sub.operation = 'SUBTRACT'
        sub.inputs[1].default_value = (.5, .5, 0)
        scale = n.new('ShaderNodeVectorMath'); scale.operation = 'MULTIPLY'
        scale.inputs[1].default_value = (2, 2, 0)
        length = n.new('ShaderNodeVectorMath'); length.operation = 'LENGTH'
        ramp = n.new('ShaderNodeValToRGB'); ramp.color_ramp.interpolation = 'EASE'
        ramp.color_ramp.elements[0].position = 0.0
        ramp.color_ramp.elements[0].color = (.20, .20, .20, 1)
        ramp.color_ramp.elements[1].position = 1.0
        ramp.color_ramp.elements[1].color = (0, 0, 0, 1)
        e = ramp.color_ramp.elements.new(.36); e.color = (.15, .15, .15, 1)
        e = ramp.color_ramp.elements.new(.72); e.color = (.055, .055, .055, 1)
        transparent = n.new('ShaderNodeBsdfTransparent')
        ink = n.new('ShaderNodeEmission')
        ink.inputs['Color'].default_value = (.12, .095, .065, 1)
        ink.inputs['Strength'].default_value = .8
        mix = n.new('ShaderNodeMixShader')
        out = n.new('ShaderNodeOutputMaterial')
        links.new(tex.outputs['UV'], sub.inputs[0])
        links.new(sub.outputs['Vector'], scale.inputs[0])
        links.new(scale.outputs['Vector'], length.inputs[0])
        links.new(length.outputs['Value'], ramp.inputs['Fac'])
        links.new(ramp.outputs['Color'], mix.inputs[0])
        links.new(transparent.outputs[0], mix.inputs[1])
        links.new(ink.outputs[0], mix.inputs[2])
        links.new(mix.outputs[0], out.inputs['Surface'])
        return m

    # --- primitives the models are built from ------------------------------------

    @staticmethod
    def finish(obj, mat=None, smooth=True):
        if mat:
            obj.data.materials.append(mat)
        if obj.type == 'MESH' and smooth:
            for p in obj.data.polygons:
                p.use_smooth = True
        return obj

    def uv(self, name, loc, scale, mat, seg=24, rings=16, smooth=True):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings,
                                             radius=1, location=loc)
        o = bpy.context.object
        o.name = name
        o.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        return self.finish(o, mat, smooth)

    def mesh(self, name, verts, faces, mat, smooth=True):
        me = bpy.data.meshes.new(name + ' Mesh')
        me.from_pydata(verts, [], faces)
        me.update()
        o = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(o)
        return self.finish(o, mat, smooth)

    @staticmethod
    def tube(name, points, radius, mat, resolution=3):
        cu = bpy.data.curves.new(name + ' Curve', 'CURVE')
        cu.dimensions = '3D'
        cu.resolution_u = 16
        cu.bevel_depth = radius
        cu.bevel_resolution = resolution
        sp = cu.splines.new('BEZIER')
        sp.bezier_points.add(len(points) - 1)
        for bp, p in zip(sp.bezier_points, points):
            bp.co = p
            bp.handle_left_type = 'AUTO'
            bp.handle_right_type = 'AUTO'
        o = bpy.data.objects.new(name, cu)
        bpy.context.collection.objects.link(o)
        o.data.materials.append(mat)
        return o

    def leaf(self, name, base, direction, length, width, mat=None, lift=.22, wave=0.0):
        base = Vector(base)
        d = Vector((direction[0], direction[1], 0)).normalized()
        side = Vector((-d.y, d.x, 0))
        verts = []; faces = []; rows = 16; across = 8
        for i in range(rows + 1):
            t = i / rows
            env = max(0.0, math.sin(math.pi * t)) ** .76
            env *= 1.0 + wave * math.sin(8 * math.pi * t)
            center = base + d * (length * t)
            center.z += length * (lift * t + .10 * math.sin(math.pi * t))
            for j in range(across + 1):
                u = j / across * 2 - 1
                p = center + side * (width * env * u)
                p.z += width * .22 * env * (1 - u * u)
                verts.append(tuple(p))
        for i in range(rows):
            for j in range(across):
                a = i * (across + 1) + j
                faces.append((a, a + 1, a + across + 2, a + across + 1))
        o = self.mesh(name, verts, faces, mat or self.M['leaf'], True)
        sol = o.modifiers.new('Soft leaf thickness', 'SOLIDIFY')
        sol.thickness = .018
        return o

    def fruit_mesh(self, name, center, scale, mat, lobes=0, indent=.0, apple_shape=False):
        cx, cy, cz = center; sx, sy, sz = scale; nlat = 28; nlon = 48
        verts = []; faces = []
        for i in range(nlat + 1):
            phi = math.pi * i / nlat; s = math.sin(phi); c = math.cos(phi)
            for j in range(nlon):
                th = 2 * math.pi * j / nlon
                ripple = 1.0 + (0.035 * math.cos(lobes * th + 0.2) * s ** 2 if lobes else 0)
                if apple_shape:
                    ripple *= 1.0 + 0.075 * math.cos(2 * phi) * s
                r = s * ripple
                x = cx + sx * r * math.cos(th); y = cy + sy * r * math.sin(th)
                z = cz + sz * c
                if indent:
                    top = max(0.0, c) ** 8; bottom = max(0.0, -c) ** 10
                    z -= indent * top; z += indent * .28 * bottom
                verts.append((x, y, z))
        for i in range(nlat):
            for j in range(nlon):
                a = i * nlon + j; b = i * nlon + (j + 1) % nlon
                faces.append((a, b, b + nlon, a + nlon))
        return self.mesh(name, verts, faces, mat, True)

    def lathe(self, name, center, profile, mat, segments=32, wave=0.018):
        cx, cy, cz = center; verts = []; faces = []
        for k, (z, r) in enumerate(profile):
            for j in range(segments):
                th = 2 * math.pi * j / segments
                rr = r * (1 + wave * math.sin(5 * th + 0.4)
                          * math.sin(math.pi * k / max(1, len(profile) - 1)))
                verts.append((cx + rr * math.cos(th), cy + rr * math.sin(th), cz + z))
        for k in range(len(profile) - 1):
            for j in range(segments):
                a = k * segments + j; b = k * segments + (j + 1) % segments
                faces.append((a, b, b + segments, a + segments))
        faces.extend([tuple(range(segments - 1, -1, -1)),
                      tuple((len(profile) - 1) * segments + j for j in range(segments))])
        return self.mesh(name, verts, faces, mat, True)

    # --- an asset: build, shadow, collect ----------------------------------------

    def asset(self, asset_id, build, shadow):
        """Run a model's build() inside its own collection.

        `shadow` is the recipe's {"baked": bool, "size": [sx, sy]}. Baked means
        the short radial contact shadow is rendered into the PNG alpha (the
        sprite pack look); not baked means the runtime draws its own
        (Shapes.ground_shadow), which the install step records in the
        sidecar JSON so harvest_visual_art.gd knows which it got.
        """
        coll = bpy.data.collections.new('ASSET | ' + asset_id)
        self.scene.collection.children.link(coll)
        before = set(bpy.data.objects)
        build()
        made = set(bpy.data.objects) - before
        if shadow.get('baked', True):
            verts = [(-1, -1, 0), (1, -1, 0), (1, 1, 0), (-1, 1, 0)]
            o = self.mesh('Shadow | ' + asset_id, verts, [(0, 1, 2, 3)],
                          self.shadow_mat, False)
            uvs = o.data.uv_layers.new(name='Shadow radial UV')
            uvmap = {0: (0, 0), 1: (1, 0), 2: (1, 1), 3: (0, 1)}
            for poly in o.data.polygons:
                for li in poly.loop_indices:
                    uvs.data[li].uv = uvmap[o.data.loops[li].vertex_index]
            sx, sy = shadow.get('size', [.4, .28])
            o.scale = (sx, sy, 1)
            o.location = (0, .08, .012)
            made.add(o)
        for o in made:
            for c in list(o.users_collection):
                c.objects.unlink(o)
            coll.objects.link(o)
        return coll

    def render(self, coll, path, all_colls):
        """Render one collection alone to `path`."""
        for other in all_colls:
            other.hide_render = other is not coll
        self.scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)

    def export_glb(self, coll, path, all_colls):
        """The same asset as a GLB, Z-up to Y-up, origin at the ground pivot."""
        bpy.ops.object.select_all(action='DESELECT')
        for o in coll.all_objects:
            o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB',
                                  use_selection=True, export_apply=True,
                                  export_yup=True)
        bpy.ops.object.select_all(action='DESELECT')
