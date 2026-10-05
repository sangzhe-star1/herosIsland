"""A mint enamel watering can, broad handle and round rose for tiny UI slots."""
import math
from mathutils import Vector


def build(S, P):
    enamel = S.material('Watering can | mint teal enamel', (.13, .53, .48), .44)
    rim = S.material('Watering can | soft mint edges', (.37, .72, .62), .42)
    inside = S.material('Watering can | opening shade', (.055, .22, .20), .75)
    rose = S.material('Watering can | brass rose', (.85, .68, .37), .46)
    pale = S.material('Watering can | waterdrop badge', (.85, .92, .73), .66)
    S.uv('Watering can | round tank', (0, 0, .40), (.405, .315, .385), enamel, 40, 24)
    S.cyl('Watering can | stable base', (0, 0, .075), .285, .10, enamel, 40)
    S.cyl('Watering can | filling collar', (0, 0, .745), .205, .09, rim, 40)
    S.cyl('Watering can | dark opening', (0, 0, .793), .163, .012, inside, 40)
    # Side handle has a large open centre and a rounded comfortable grip.
    S.tube('Watering can | loop handle', [(-.29, .03, .67), (-.51, .035, .83),
           (-.72, .035, .75), (-.78, .025, .48), (-.68, .015, .23),
           (-.32, 0, .20)], .063, enamel, 5)
    S.tube('Watering can | handle highlight', [(-.52, -.004, .815),
           (-.685, -.007, .733), (-.735, -.016, .51)], .017, rim, 3)

    S.tube('Watering can | rising spout', [(.29, 0, .30), (.55, -.015, .39),
           (.80, -.04, .67), (1.02, -.07, .88)], .082, enamel, 5)
    normal = Vector((.74, -.12, .66)).normalized()
    centre = Vector((1.055, -.075, .91))
    head = S.cyl('Watering can | sprinkler rose', centre, .19, .082, rose, 40)
    head.rotation_mode = 'QUATERNION'
    head.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(normal)
    front = centre + normal * .044
    disk = S.cyl('Watering can | rose face', front, .165, .012, pale, 40)
    disk.rotation_mode = 'QUATERNION'
    disk.rotation_quaternion = head.rotation_quaternion
    right = normal.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(normal).normalized()
    for i in range(7):
        angle = (i - 1) * math.tau / 6
        radius = 0 if i == 0 else .10
        point = front + normal * .01 + radius * (right * math.cos(angle) + up * math.sin(angle))
        S.uv('Watering can | rose hole', point, (.016, .016, .016), inside, 10, 6)

    # A sculpted droplet communicates watering without a written label.
    S.uv('Watering can | drop round', (0, -.309, .40), (.08, .025, .095), pale, 20, 12)
    S.uv('Watering can | drop tip', (0, -.308, .49), (.043, .023, .08), pale, 16, 10)
