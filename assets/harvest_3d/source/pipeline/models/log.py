"""Log

A fallen log with its rings showing, somewhere to sit a bug on.
"""
import math


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    block, cyl, cone, roof = S.block, S.cyl, S.cone, S.roof
    log_ = cyl('Log | trunk', (0, 0, .22), .22, 1.3, M['bark'], 24)
    log_.rotation_euler = (0, math.pi / 2, .35)
    end = cyl('Log | ring', (.61, .22, .22), .20, .03, M['wood'], 24)
    end.rotation_euler = (0, math.pi / 2, .35)
    uv('Log | moss', (-.20, .10, .40), (.18, .12, .06), M['canopy2'], 12, 8)
    uv('Log | knot', (.15, -.22, .30), (.06, .04, .06), M['wood_dark'], 10, 6)
