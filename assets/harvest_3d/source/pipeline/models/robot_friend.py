"""Robot Friend

A full-body companion that carries the existing square robot head design into
the shared farm scene. Geometry stays toy-like and readable under Godot's
runtime lighting; no external textures or generated meshes are used.
"""


def build(S, P):
    material = S.material

    # Runtime farm lighting is much brighter than the frozen sprite studio;
    # keep the base colours restrained so the friend stays blue-gray in game.
    shell = material('Robot Friend | soft blue shell', (.20, .31, .33), .82)
    shell_light = material('Robot Friend | pale shell panels', (.38, .48, .46), .84)
    joint = material('Robot Friend | deep teal joints', (.12, .20, .22), .86)
    screen = material('Robot Friend | dark face screen', (.04, .08, .09), .48)
    eye = material('Robot Friend | warm glowing eyes', (.85, .72, .45), .38)
    coral = material('Robot Friend | coral smile', (.55, .20, .14), .72)
    brass = material('Robot Friend | honey details', (.58, .38, .10), .72)

    # Feet and short legs keep the body planted, with a little walking stance.
    for side in (-1, 1):
        S.block('Robot Friend | shin', (side * .22, 0.015, .22),
                (.20, .27, .38), joint, bevel=.08, smooth=True)
        S.uv('Robot Friend | foot', (side * .22, -.08, .085),
             (.19, .32, .12), shell_light, 20, 12)

    # Rounded chest with a bright little status light that reads at game scale.
    S.block('Robot Friend | torso', (0, .015, .80), (.76, .46, .82),
            shell, bevel=.17, smooth=True)
    S.block('Robot Friend | chest panel', (0, -.225, .88),
            (.42, .045, .33), shell_light, bevel=.06, smooth=True)
    S.uv('Robot Friend | chest light', (0, -.264, .90),
         (.105, .035, .105), brass, 18, 12)
    S.block('Robot Friend | chest slot', (0, -.264, .72),
            (.22, .035, .045), joint, bevel=.02, smooth=False)

    # Soft arm pods and mitts mirror the round side-pods on the familiar head.
    for side in (-1, 1):
        S.uv('Robot Friend | shoulder', (side * .46, .01, 1.04),
             (.18, .22, .20), shell_light, 20, 12)
        S.uv('Robot Friend | arm', (side * .55, -.015, .77),
             (.14, .16, .29), shell, 20, 12)
        S.uv('Robot Friend | hand', (side * .56, -.06, .53),
             (.16, .16, .15), brass, 18, 10)

    # The head preserves the existing robot prop's square, padded silhouette.
    S.block('Robot Friend | head shell', (0, -.015, 1.58),
            (1.06, .76, .78), shell, bevel=.16, smooth=True)
    S.block('Robot Friend | face screen', (0, -.409, 1.56),
            (.78, .055, .48), screen, bevel=.10, smooth=True)
    for side in (-1, 1):
        S.uv('Robot Friend | eye bezel', (side * .19, -.452, 1.62),
             (.115, .055, .13), joint, 20, 12)
        S.uv('Robot Friend | eye', (side * .19, -.499, 1.63),
             (.065, .035, .075), eye, 18, 10)
        S.uv('Robot Friend | ear pod', (side * .61, -.01, 1.55),
             (.17, .22, .22), shell_light, 20, 12)
    S.block('Robot Friend | smile', (0, -.463, 1.40),
            (.25, .035, .055), coral, bevel=.025, smooth=False)

    # One antenna orb recalls the original prop and gives a clear silhouette.
    S.cyl('Robot Friend | antenna stem', (0, -.015, 2.03), .055, .22,
          joint, verts=20, smooth=True)
    S.uv('Robot Friend | antenna orb', (0, -.015, 2.19),
         (.15, .15, .15), brass, 24, 16)
