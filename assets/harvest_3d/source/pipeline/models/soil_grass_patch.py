"""A shallow, worked bed of earth with a few grass edges.

The soil surface, not the bottom of a green plinth, is the planting anchor.
Its point is declared in the recipe and projected by the shared studio.
Geometry is deliberately broad enough to survive the farm's overview zoom.
"""
import math
import random


def build(S, P):
    height = float(P.get('surface_height', 0.10))
    earth = S.material('Bed | warm worked loam', (.34, .19, .084), .94)
    side = S.material('Bed | compressed earth edge', (.29, .157, .075), .96)
    bevel = S.material('Bed | rounded earth shoulder', (.32, .176, .08), .94)
    pale = S.material('Bed | quiet loam variation', (.415, .25, .13), .96)
    grass = S.material('Bed | meadow edge', (.225, .405, .125), .91)
    grass_light = S.material('Bed | sunlit grass tips', (.31, .47, .17), .92)
    stone = S.material('Bed | tiny warm pebbles', (.46, .39, .29), .95)
    # Broad clay variation plus restrained bump; no photo texture, no pixels
    # are painted into the asset after Blender renders it.
    nodes, links = earth.node_tree.nodes, earth.node_tree.links
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 34.0
    noise.inputs['Detail'].default_value = 2.0
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .27
    bump.inputs['Distance'].default_value = .022
    links.new(noise.outputs['Fac'], bump.inputs['Height'])
    principled = next(node for node in nodes if node.type == 'BSDF_PRINCIPLED')
    links.new(bump.outputs['Normal'], principled.inputs['Normal'])
    count = 96

    def perimeter(angle, rx, ry):
        # Rounded rectangle with a hand-shaped edge, never a perfect disk.
        c, s = math.cos(angle), math.sin(angle)
        ripple = 1 + .024 * math.sin(5 * angle + .6) + .012 * math.sin(9 * angle)
        x = math.copysign(abs(c) ** .58, c) * rx * ripple
        y = math.copysign(abs(s) ** .58, s) * ry * ripple
        return x, y

    loops = [(0.94, .47, .012), (1.00, .53, .034),
             (.98, .51, height - .022), (.92, .46, height)]
    verts, faces = [], []
    for rx, ry, z in loops:
        for i in range(count):
            a = math.tau * i / count
            x, y = perimeter(a, rx, ry)
            verts.append((x, y, z + .004 * math.sin(7 * a)))
    for ring in range(len(loops) - 1):
        for i in range(count):
            j = (i + 1) % count
            faces.append((ring * count + i, ring * count + j,
                          (ring + 1) * count + j, (ring + 1) * count + i))
    body = S.mesh('Bed | soft earth cross section', verts, faces, side, True)
    body.data.materials.append(bevel)
    for polygon in body.data.polygons:
        polygon.material_index = 1 if polygon.index >= 2 * count else 0

    # A continuous top mesh catches the light on low, raked ridges. Keep the
    # centre exactly at the declared surface height so the crop meets soil.
    verts = [(0, 0, height)]
    faces = []
    rings = 12
    for ring in range(1, rings + 1):
        radius = ring / rings
        for i in range(count):
            a = math.tau * i / count
            x, y = perimeter(a, .92 * radius, .46 * radius)
            envelope = math.sin(math.pi * radius) ** 2
            raked = .034 * math.sin(y * 28) ** 2 * envelope
            verts.append((x, y, height + raked))
    for i in range(count):
        faces.append((0, 1 + i, 1 + (i + 1) % count))
    for ring in range(rings - 1):
        start, next_start = 1 + ring * count, 1 + (ring + 1) * count
        for i in range(count):
            j = (i + 1) % count
            faces.append((start + i, next_start + i, next_start + j, start + j))
    S.mesh('Bed | continuous raked soil', verts, faces, earth, True)

    rng = random.Random(231)
    for i, (x, y) in enumerate([(-.76, -.25), (.68, .28), (-.55, .30),
                                (.78, -.19), (-.30, -.32), (.42, -.31)]):
        radius = rng.uniform(.026, .042)
        S.uv('Bed | soft soil crumb %02d' % i, (x, y, height + .008),
             (radius, radius * .76, radius * .47), pale, 12, 8)
    for i, (x, y) in enumerate([(-.94, .19), (.83, .40), (.94, -.12), (-.48, .48)]):
        for blade in range(3):
            angle = i * 1.7 + blade * 1.4
            S.leaf('Bed | sparse grass %d-%d' % (i, blade), (x, y, .055),
                   (math.cos(angle), math.sin(angle)), .12 + .018 * blade,
                   .025, grass if blade != 1 else grass_light, .53)
    S.uv('Bed | edge pebble', (-.80, -.38, .11), (.039, .032, .025), stone, 10, 8)
