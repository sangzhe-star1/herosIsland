"""Hedge

A low rounded bush, three lobes wide, the kind that sits between beds and
along a route. Rooted at the ground so it can stand on the meadow.
"""


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    for i, (centre, scale, key) in enumerate([
            ((-.50, .16, .34), (.46, .40, .36), 'canopy'),
            ((.02, -.14, .42), (.56, .46, .44), 'canopy2'),
            ((.52, .18, .30), (.40, .36, .32), 'canopy3'),
            ((-.14, .30, .52), (.34, .30, .28), 'canopy2')]):
        fruit_mesh('Hedge | lobe %d' % i, centre, scale, M[key], 5, .02)
    tube('Hedge | stem', [(0, .05, .0), (.02, .03, .25)], .035, M['bark'], 2)
