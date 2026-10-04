"""Strawberry (readable)

The strawberry the game ships: strawberry_readability/build_strawberry.py
took the sprite-pack berry and, without a new asset, widened the shoulder and
lengthened the tip (so it stops reading as a small tomato), lifted the seven
crown leaves, and laid fourteen seeds on the camera-facing skin where the
frozen camera can see them. That script edited the old mesh in place; this
builds the same result directly, so the numbers below are its numbers.
"""
import math

from mathutils import Matrix, Vector

# The eight rings of the berry after the readability pass (z, radius).
PROFILE = [(.035,.026),(.17,.095),(.33,.235),(.56,.405),
           (.73,.445),(.85,.400),(.94,.255),(1.02,.075)]
# Seeds sit in four rows on the side the frozen camera looks at.
VIEW_ANGLE = math.atan2(-9.8, 6.7)
SEED_ROWS = [(.26,[-.58,0,.58]),(.44,[-.77,-.24,.29,.79]),
             (.65,[-.70,-.18,.33,.82]),(.82,[-.45,.13,.64])]


def _radius_and_slope(z):
    for (za,ra),(zb,rb) in zip(PROFILE, PROFILE[1:]):
        if za <= z <= zb:
            slope = (rb-ra)/(zb-za)
            return ra+(z-za)*slope, slope
    raise ValueError('seed off the berry: z=%r' % z)


def build(S, P):
    M, uv, mesh, tube, leaf, fruit_mesh, lathe, material = (
        S.M, S.uv, S.mesh, S.tube, S.leaf, S.fruit_mesh, S.lathe, S.material)
    berry_mat = material('Strawberry | ripe berry (readable)', (.88,.055,.075), .80)
    parts = [lathe('Strawberry | heart-shaped berry', (0,0,0), PROFILE, berry_mat, 40, .025)]
    for i in range(7):
        a = 2*math.pi*i/7
        crown = leaf('Strawberry | green crown', (0,0,1.00), (math.cos(a),math.sin(a)),
                     .34, .135, M['leaf'] if i%2 else M['leaf2'], .42)
        S.prepare_leaf_surface(crown)
        S.apply_modifier(crown, 'Soft leaf thickness', thickness=.028, offset=0)
        parts.append(crown)
    for z, offsets in SEED_ROWS:
        radius, slope = _radius_and_slope(z)
        for offset in offsets:
            angle = VIEW_ANGLE + offset
            outward = Vector((math.cos(angle), math.sin(angle), -slope)).normalized()
            tangent = Vector((math.sin(angle), -math.cos(angle), 0))
            upward = tangent.cross(outward).normalized()
            seed = uv('Strawberry | seed', (0,0,0), (.027*1.25,.016*1.30,.043*1.18), M['seed'], 10, 6)
            seed.location = Vector((radius*math.cos(angle), radius*math.sin(angle), z)) + outward*.009
            seed.rotation_euler = Matrix((tangent, outward, upward)).transposed().to_euler()
            parts.append(seed)
    for part in parts:
        S.readable_cleanup(part)
