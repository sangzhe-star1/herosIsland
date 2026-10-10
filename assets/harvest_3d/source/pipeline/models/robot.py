"""A friendly, softly bevelled robot head with a restored round antenna."""


def build(S, P):
    M = S.M

    # The head is a rounded toy shell. Soft oval ear drums sit just outside it.
    S.block('Robot | head shell', (0, 0, 1.02), (1.36, 0.88, 1.18),
            M['robot_shell'], bevel=0.15, smooth=True)
    for side in (-1, 1):
        S.uv('Robot | ear pod', (side * 0.73, 0.0, 1.0),
             (0.28, 0.24, 0.34), M['robot_side'], 24, 16)

    # Warm eyes and a small mouth keep the face legible at visitor-icon size.
    for side in (-1, 1):
        S.uv('Robot | eye', (side * 0.34, -0.47, 1.07),
             (0.24, 0.07, 0.25), M['white'], 24, 16)

    S.block('Robot | mouth', (0.0, -0.468, 0.60), (0.48, 0.07, 0.13),
            M['robot_mouth'], bevel=0.025, smooth=False)
    S.cyl('Robot | antenna stem', (0.0, 0.0, 1.74), 0.075, 0.34,
          M['robot_side'], verts=24, smooth=True)
    S.uv('Robot | antenna orb', (0.0, 0.0, 2.04),
         (0.25, 0.25, 0.25), M['robot_antenna'], 32, 20)
