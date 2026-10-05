"""A broad, rounded garden trowel that reads at a 44 px tool-button size."""


def build(S, P):
    steel = S.material('Trowel | soft blue steel', (.45, .64, .69), .38)
    edge = S.material('Trowel | rolled metal edge', (.70, .82, .80), .36)
    wood = S.material('Trowel | warm ash handle', (.76, .47, .22), .78)
    grain = S.material('Trowel | handle grain', (.59, .32, .13), .86)
    ferrule = S.material('Trowel | brass ferrule', (.86, .61, .28), .42)

    # The front of the spoon curves inward. The substantial thickness and
    # rolled lip keep the rim readable without a sharp, threatening point.
    rows = [(.025, .025), (.10, .135), (.28, .255), (.48, .285),
            (.67, .245), (.79, .15)]
    verts = []
    across = 12
    for z, width in rows:
        for j in range(across + 1):
            u = -1 + j * 2 / across
            verts.append((u * width, .09 * (1 - u * u), z))
    faces = []
    for i in range(len(rows) - 1):
        for j in range(across):
            a = i * (across + 1) + j
            faces.append((a, a + 1, a + across + 2, a + across + 1))
    blade = S.mesh('Trowel | curved scoop', verts, faces, steel)
    solid = blade.modifiers.new('Rounded spoon thickness', 'SOLIDIFY')
    solid.thickness = .055
    bevel = blade.modifiers.new('Safe toy edges', 'BEVEL')
    bevel.width = .028
    bevel.segments = 3
    for side in (-1, 1):
        S.tube('Trowel | rolled rim', [(side * width, 0, z) for z, width in rows],
               .023, edge, 3)
    S.tube('Trowel | rounded toe', [(-.025, 0, .025), (0, 0, .018),
                                   (.025, 0, .025)], .023, edge, 3)
    S.tube('Trowel | neck', [(0, .045, .67), (0, .015, .86),
                            (0, 0, 1.0)], .075, steel, 4)
    S.cyl('Trowel | ferrule', (0, 0, .96), .118, .15, ferrule, 32)
    S.cyl('Trowel | wooden grip', (0, 0, 1.25), .126, .45, wood, 32)
    S.uv('Trowel | grip cap', (0, 0, 1.485), (.126, .126, .10), wood, 24, 16)
    S.uv('Trowel | grip base', (0, 0, 1.025), (.123, .123, .075), wood, 24, 16)
    for x in [-.052, .028]:
        S.tube('Trowel | grain', [(x, -.117, 1.08), (x + .011, -.122, 1.23),
                                 (x - .008, -.119, 1.41)], .006, grain, 2)
    # A single hanging-hole inset is large enough to read as a tool detail.
    S.uv('Trowel | hanging hole', (0, -.119, 1.445),
         (.028, .012, .031), S.M['wood_dark'], 16, 10)
