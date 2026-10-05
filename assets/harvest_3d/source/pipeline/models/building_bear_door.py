"""A grassy burrow with a stone arch and a recessed, planked wooden door.

The hill is built around an actual opening instead of burying a door in a
sphere. All geometry stays in the original recipe's small ground footprint.
"""
import math


def build(S, P):
    M, block, uv, mesh = S.M, S.block, S.uv, S.mesh
    limestone = S.material('Bear door | warm limestone', (.66, .63, .51), .93)
    limestone_light = S.material('Bear door | light limestone', (.76, .72, .59), .93)
    door_wood = S.material('Bear door | honey oak', (.62, .385, .17), .90)
    door_wood_light = S.material('Bear door | light oak', (.72, .47, .23), .90)
    earth = S.material('Bear door | earth edge', (.35, .245, .13), .97)
    moss = S.material('Bear door | soft moss', (.32, .50, .20), .96)

    # An arched front cut-out exposes the reveal all around the wooden door.
    segments = 32
    sections = [(-.42, 1.20, .82), (-.05, 1.30, .865), (.37, 1.18, .75),
                (.76, .90, .48), (1.09, .48, .20), (1.25, .04, .035)]
    verts, faces = [], []
    for row, (y, width, height) in enumerate(sections):
        for k in range(segments + 1):
            angle = math.pi * k / segments
            front_curve = .16 * abs(math.cos(angle)) if row == 0 else 0
            verts.append((width * math.cos(angle), y + front_curve,
                          .025 + height * math.sin(angle) ** .88))
    for row in range(len(sections) - 1):
        for k in range(segments):
            a = row * (segments + 1) + k
            b = a + segments + 1
            faces.append((a, b, b + 1, a + 1))
    opening_start = len(verts)
    for k in range(segments + 1):
        angle = math.pi * k / segments
        verts.append((.46 * math.cos(angle), -.57, .28 + .47 * math.sin(angle)))
    for k in range(segments):
        faces.append((k, k + 1, opening_start + k + 1, opening_start + k))
    for outer, inner, side in ((0, opening_start, 1),
                               (segments, opening_start + segments, -1)):
        base = len(verts)
        verts.append((side * .46, -.57, .025))
        faces.append((outer, inner, base) if side == 1 else (outer, base, inner))
    faces.append(tuple(range((len(sections) - 1) * (segments + 1),
                             len(sections) * (segments + 1))))
    mesh('Bear door | sculpted grass hill', verts, faces, M['mound_green'], True)
    # Trace the actual hill boundary for its narrow earth edge. A separate
    # elliptical base would stick out behind the tapered hill like a platter.
    boundary = [(width, y + (.16 if row == 0 else 0))
                for row, (y, width, height) in enumerate(sections)]
    boundary += [(-width, y + (.16 if row == 0 else 0))
                 for row, (y, width, height) in reversed(list(enumerate(sections)))]
    boundary += [(-.46, -.57), (.46, -.57)]
    edge_count = len(boundary)
    edge_verts = [(x, y, z) for z in (.029, .002) for x, y in boundary]
    edge_faces = [(k, k + edge_count,
                   (k + 1) % edge_count + edge_count, (k + 1) % edge_count)
                  for k in range(edge_count)]
    edge_faces.append(tuple(range(edge_count * 2 - 1, edge_count - 1, -1)))
    mesh('Bear door | fitted earth edge', edge_verts, edge_faces, earth, False)
    for side in (-1, 1):
        S.tube('Bear door | rounded grass foot',
               [(side * x, y, .032) for x, y in
                ((1.16, -.27), (.98, -.34), (.77, -.43), (.56, -.525))],
               .025, M['mound_green'], 3)

    def arch_slab(name, radius, spring, bottom, y, thickness, mat):
        outline = [(-radius, bottom), (radius, bottom), (radius, spring)]
        outline += [(radius * math.cos(math.pi * k / 24),
                     spring + radius * math.sin(math.pi * k / 24))
                    for k in range(1, 25)]
        count = len(outline)
        points = [(x, depth, z) for depth in (y - thickness * .5, y + thickness * .5)
                  for x, z in outline]
        polygons = [tuple(range(count)), tuple(range(count * 2 - 1, count - 1, -1))]
        polygons += [(k, k + count, (k + 1) % count + count, (k + 1) % count)
                     for k in range(count)]
        obj = mesh(name, points, polygons, mat, False)
        bevel = obj.modifiers.new('Soft carved edge', 'BEVEL')
        bevel.width, bevel.segments = .012, 3
        return obj

    arch_slab('Bear door | deep entrance shadow', .435, .30, .095,
              -.486, .07, M['door_dark'])
    arch_slab('Bear door | inset arched oak door', .36, .31, .135,
              -.540, .055, door_wood)
    for k in range(5):
        x = (k - 2) * .138
        top = .31 + math.sqrt(.36 ** 2 - (abs(x) + .061) ** 2)
        block('Bear door | individual oak plank', (x, -.565, (.14 + top) * .5),
              (.124, .032, top - .14), door_wood_light if k % 2 == 0 else door_wood, .011)
    for z in (.225, .43):
        block('Bear door | door cross rail', (0, -.593, z),
              (.67, .044, .052), M['wood_dark'], .012)
    uv('Bear door | warm round knob', (.205, -.63, .35),
       (.037, .030, .037), M['seed'], 16, 10)

    # Large individual arch stones stay readable after sprite downscaling.
    for k in range(9):
        angle = math.pi * k / 8
        stone = block('Bear door | arch voussoir',
                      (.48 * math.cos(angle), -.596, .30 + .48 * math.sin(angle)),
                      (.185, .185, .19), limestone_light if k % 3 == 1 else limestone, .035)
        stone.rotation_euler[1] = math.pi * .5 - angle
    for side in (-1, 1):
        block('Bear door | lower stone jamb', (side * .48, -.59, .16),
              (.19, .18, .21), limestone_light, .035)
        block('Bear door | wooden inner jamb', (side * .396, -.595, .22),
              (.056, .067, .255), M['wood_dark'], .018)
    S.tube('Bear door | carved inner arch',
           [(.397 * math.cos(math.pi * k / 18), -.596,
             .30 + .397 * math.sin(math.pi * k / 18)) for k in range(19)],
           .029, M['wood_dark'], 3)
    block('Bear door | lower welcoming step', (0, -.635, .044),
          (1.02, .30, .088), limestone, .030)
    block('Bear door | upper threshold', (0, -.54, .112),
          (.84, .255, .080), limestone_light, .026)

    # Sparse, broad moss cushions tie the portal into the grass silhouette.
    for x, y, z, sx, sy in ((-.73, -.21, .71, .22, .18),
                           (.79, -.09, .71, .23, .17),
                           (-.28, .05, .80, .26, .22)):
        uv('Bear door | moss cushion', (x, y, z), (sx, sy, .075), moss, 20, 10)
    for side in (-1, 1):
        for k in range(3):
            S.leaf('Bear door | entrance grass',
                   (side * (.78 + k * .045), -.49 + k * .017, .025),
                   (side * (.4 + k * .15), -.2), .18 + k * .025, .033,
                   M['grass_tuft2'], 1.0)
