"""Warehouse

The barn: a wide tan body under a brown roof, a big double door and two
crates waiting outside. The one building a child looks at every visit.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    block('Barn | walls', (0, 0, .70), (2.3, 1.4, 1.40), M['wall_tan'])
    roof('Barn | roof', (0, 0, 1.38), (2.3, 1.4, .72), M['roof_brown'])
    block('Barn | door left', (-.22, -.71, .45), (.40, .04, .90), M['roof_brown'], .02)
    block('Barn | door right', (.22, -.71, .45), (.40, .04, .90), M['roof_brown'], .02)
    block('Barn | door brace', (0, -.73, .45), (.06, .04, .90), M['wood_dark'], .01)
    block('Barn | hay window', (0, -.71, 1.30), (.36, .04, .30), M['door_dark'], .02)
    block('Barn | crate', (-1.05, -.95, .18), (.40, .36, .36), M['wood'], .02)
    block('Barn | crate two', (-.62, -1.00, .16), (.34, .30, .32), M['wood_dark'], .02)
    block('Barn | crate lid', (-1.05, -.95, .37), (.44, .40, .04), M['wood_dark'], .01)
